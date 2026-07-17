// Package storage owns the database-file space operations the settings storage panel drives:
// reporting the DB's size and dead (reclaimable) space, and compacting the file on the user's
// request. It is the app-level seam the storage handler calls — transport never reaches into
// infra/db directly. The whole-file VACUUM and the freelist arithmetic are infra concerns
// (infra/db.vacuum.go); this layer just translates them into wire-shaped results and errors.
//
// Package storage 拥有设置存储面板驱动的数据库文件空间操作：报告库大小与死（可回收）空间、并在用户请求时
// 压缩文件。它是存储 handler 调用的 app 层缝——transport 绝不直接伸进 infra/db。全文件 VACUUM 与 freelist
// 算术是 infra 的事（infra/db.vacuum.go）；本层只把它们翻译成线缆形状的结果与错误。
package storage

import (
	"context"

	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// ErrCompactFailed reports a user-triggered VACUUM that could not complete — the dominant real cause
// is a disk too full to hold VACUUM's scratch copy (roughly the DB's own size). The DB is untouched
// on failure, so this is a safe-to-retry operational error, not corruption. The underlying cause is
// attached (WithCause) for logs but never put on the wire.
//
// ErrCompactFailed 报告一次跑不完的用户触发 VACUUM——主因是磁盘太满、放不下 VACUUM 的临时副本（约等于库自身
// 大小）。失败时库不动，故这是可安全重试的运行错误、非损坏。底层 cause 附在（WithCause）供日志、绝不上线缆。
var ErrCompactFailed = errorspkg.New(errorspkg.KindInternal, "STORAGE_COMPACT_FAILED", "database compaction failed (VACUUM needs free scratch space roughly the size of the database)")

// Service exposes storage-file operations over the single shared DB. Machine-level like the DB it
// wraps: there is one .db file for the whole install, so these numbers and this action are global —
// the workspace header on the guarded route is identity, not an isolation axis (F162, same as limits).
//
// Service 在唯一共享 DB 上暴露存储文件操作。与它包装的 DB 一样机器级：整个安装只有一个 .db 文件，故这些数字与
// 这个动作是全局的——受守路由上的 workspace header 是身份、非隔离轴（F162，同 limits）。
type Service struct {
	db *ormpkg.DB
}

func New(db *ormpkg.DB) *Service { return &Service{db: db} }

// Stat is the DB's on-disk footprint the storage panel shows: total logical size and the dead bytes
// DELETE freed but never returned to the OS (what Compact reclaims). Wire shape (N3 camelCase).
//
// Stat 是存储面板显示的 DB 落盘足迹：逻辑总大小 + DELETE 腾出却从未还给 OS 的死字节（正是 Compact 回收的）。
type Stat struct {
	DBBytes   int64 `json:"dbBytes"`
	DeadBytes int64 `json:"deadBytes"`
}

// Stat reads the current size + dead space. Read-only apart from the WAL checkpoint Stat needs to
// count WAL-resident frees honestly (see infra/db.Stat).
//
// Stat 读当前大小 + 死空间。除 Stat 为诚实计入 WAL 中删除所需的 checkpoint 外，是只读的。
func (s *Service) Stat(ctx context.Context) (Stat, error) {
	size, dead, err := dbinfra.Stat(ctx, s.db)
	if err != nil {
		return Stat{}, err
	}
	return Stat{DBBytes: size, DeadBytes: dead}, nil
}

// CompactResult reports the outcome of a user-triggered VACUUM: bytes handed back to the OS and
// whether the DB's auto_vacuum mode was upgraded (a mode=0 install becoming INCREMENTAL) in the pass.
//
// CompactResult 报告用户触发 VACUUM 的结果：还给 OS 的字节数 + 本趟是否升级了 auto_vacuum 模式（mode=0 安装
// 变成 INCREMENTAL）。
type CompactResult struct {
	ReclaimedBytes int64 `json:"reclaimedBytes"`
	Migrated       bool  `json:"migrated"`
}

// Compact runs the full VACUUM. A failure (typically a full disk with no VACUUM scratch space) is
// mapped to ErrCompactFailed so the panel shows an honest, retryable message; the DB is untouched.
//
// Compact 跑全量 VACUUM。失败（通常是磁盘满、无 VACUUM 临时空间）映射为 ErrCompactFailed，使面板显示诚实、
// 可重试的信息；库不动。
func (s *Service) Compact(ctx context.Context) (CompactResult, error) {
	reclaimed, migrated, err := dbinfra.Compact(ctx, s.db)
	if err != nil {
		return CompactResult{}, ErrCompactFailed.WithCause(err)
	}
	return CompactResult{ReclaimedBytes: reclaimed, Migrated: migrated}, nil
}
