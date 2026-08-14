package attachment

import (
	"context"
	"errors"
	"fmt"
	"time"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// SpeechCacheSchema is the read-aloud cache DDL (WRK-082 批C). NO `deleted_at`: this is a derived
// cache whose rows are physically evicted — legislated in database.md alongside the flowrun
// exceptions, because D1's default is that business tables soft-delete.
//
// SpeechCacheSchema 是朗读缓存 DDL(批C)。**无** `deleted_at`:这是行会被物理淘汰的派生缓存——
// 与 flowrun 那两个例外一并立法在 database.md,因为 D1 的默认是业务表软删。
var SpeechCacheSchema = []string{
	`CREATE TABLE IF NOT EXISTS speech_cache (
		id            TEXT PRIMARY KEY,
		workspace_id  TEXT NOT NULL,
		cache_key     TEXT NOT NULL,
		attachment_id TEXT NOT NULL,
		size_bytes    INTEGER NOT NULL DEFAULT 0,
		created_at    DATETIME NOT NULL,
		last_used_at  DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_speech_cache_key ON speech_cache(workspace_id, cache_key)`,
	`CREATE INDEX IF NOT EXISTS idx_speech_cache_lru ON speech_cache(workspace_id, last_used_at)`,
}

// SpeechCacheStore implements attachmentdomain.SpeechCacheRepository over pkg/orm.
//
// SpeechCacheStore 基于 pkg/orm 实现 attachmentdomain.SpeechCacheRepository。
type SpeechCacheStore struct {
	repo *ormpkg.Repo[attachmentdomain.SpeechCacheEntry]
}

// NewSpeechCache constructs a store bound to the speech_cache table.
func NewSpeechCache(db *ormpkg.DB) *SpeechCacheStore {
	return &SpeechCacheStore{repo: ormpkg.For[attachmentdomain.SpeechCacheEntry](db, "speech_cache")}
}

var _ attachmentdomain.SpeechCacheRepository = (*SpeechCacheStore)(nil)

// RepairLegacyRecency backfills rows written before Put stamped LastUsedAt explicitly. The old
// ORM path persisted Go's zero time, which made those entries look older than every real cache row
// and could evict a recently synthesized artifact after a restart. The predicate is deliberately
// date-shaped rather than driver-shaped: SQLite stores time values as text, while the exact suffix
// has changed between supported driver versions.
//
// RepairLegacyRecency 修复 Put 显式写 LastUsedAt 之前留下的旧行。旧 ORM 路径会把 Go 零时间落盘，
// 使这些行比所有真实缓存都旧，重启后可能淘汰刚合成的产物。条件刻意按日期而非 driver 的完整
// 格式匹配：SQLite 把时间存成文本，而受支持的 driver 版本可能使用不同的时间后缀。
func RepairLegacyRecency(ctx context.Context, db *ormpkg.DB) (int64, error) {
	if db == nil {
		return 0, errors.New("speech cache repair: nil db")
	}
	result, err := db.Exec(ctx, `
		UPDATE speech_cache
		SET last_used_at = created_at
		WHERE last_used_at LIKE '0001-01-01%'
	`)
	if err != nil {
		return 0, fmt.Errorf("speech cache repair: %w", err)
	}
	count, err := result.RowsAffected()
	if err != nil {
		return 0, fmt.Errorf("speech cache repair rows: %w", err)
	}
	return count, nil
}

// Lookup returns the entry for a key and refreshes its recency stamp.
//
// Lookup 按键取行并刷新其近期性戳。
func (s *SpeechCacheStore) Lookup(ctx context.Context, key string) (*attachmentdomain.SpeechCacheEntry, error) {
	e, err := s.repo.WhereEq("cache_key", key).First(ctx)
	if err != nil {
		if errors.Is(err, ormpkg.ErrNotFound) {
			return nil, attachmentdomain.ErrNotFound
		}
		return nil, fmt.Errorf("speech cache lookup: %w", err)
	}
	// A hit that does not touch recency would let a track the user replays daily be evicted as
	// "old" — the one row LRU exists to protect.
	// 命中却不动近期性,会让用户天天重播的那一条以「旧」被淘汰——而那恰是 LRU 要保护的行。
	if _, err := s.repo.WhereEq("id", e.ID).Update(ctx, "last_used_at", time.Now().UTC()); err != nil {
		return nil, fmt.Errorf("speech cache touch: %w", err)
	}
	return e, nil
}

// Delete removes one cache mapping by key. The cache row is derived data, so a missing row is
// already the desired state and is deliberately not an error.
//
// Delete 按 key 清除一条缓存映射。缓存行是派生数据,故行本已不存在就是目标状态,刻意不报错。
func (s *SpeechCacheStore) Delete(ctx context.Context, key string) error {
	if _, err := s.repo.WhereEq("cache_key", key).Delete(ctx); err != nil {
		return fmt.Errorf("speech cache delete: %w", err)
	}
	return nil
}

// Put records an entry and evicts least-recently-used rows until the workspace is under budget,
// returning the evicted attachment ids. The NEW row is never itself a candidate: evicting what we
// just synthesized would make an over-budget workspace pay upstream on every single read.
//
// Put 记一行并按 LRU 淘汰至该 workspace 回到预算内,返回被淘汰行的附件 id。**新行永不入淘汰候选**:
// 把刚合成的那件淘汰掉,会让一个超预算的 workspace 每次朗读都向上游付钱。
func (s *SpeechCacheStore) Put(ctx context.Context, e *attachmentdomain.SpeechCacheEntry, budgetBytes int64) ([]string, error) {
	// A newly synthesized artifact is also the most recently used artifact. The generic ORM only
	// stamps fields marked `created`; LastUsedAt is an ordinary column, so set it explicitly before
	// the row enters the LRU scan.
	// 新合成的产物就是当前最近使用的产物。通用 ORM 只会自动填写标记为 `created` 的字段；
	// LastUsedAt 是普通列，必须在写入并进入 LRU 扫描前显式设置。
	e.LastUsedAt = time.Now().UTC()
	if err := s.repo.Create(ctx, e); err != nil {
		return nil, fmt.Errorf("speech cache put: %w", err)
	}
	rows, err := s.repo.Order("last_used_at DESC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("speech cache scan: %w", err)
	}
	var (
		total   int64
		evicted []string
		dropIDs []any
	)
	for _, r := range rows {
		total += r.SizeBytes
		if total > budgetBytes && r.ID != e.ID {
			evicted = append(evicted, r.AttachmentID)
			dropIDs = append(dropIDs, r.ID)
		}
	}
	if len(dropIDs) > 0 {
		if _, err := s.repo.WhereIn("id", dropIDs...).Delete(ctx); err != nil {
			return nil, fmt.Errorf("speech cache evict: %w", err)
		}
	}
	return evicted, nil
}
