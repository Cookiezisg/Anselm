// Package conversation is the orm-backed conversationdomain.Repository: a workspace-scoped,
// soft-deleted thread table. Workspace isolation + soft-delete are automatic (orm fills/filters
// from ctx), so no method hand-writes a predicate. List is always pinned-first; its secondary key
// follows ListFilter.Sort — activity (last_message_at) / created (created_at) via Page, or name
// (title COLLATE NOCASE) via PageAsc — each keyset-paginated on its own column.
//
// Package conversation 是 conversationdomain.Repository 的 orm 实现：按 workspace、软删的线程表。
// workspace 隔离 + 软删自动（orm 据 ctx 填/过滤），故无方法手写谓词。List 恒置顶优先；次键随 ListFilter.Sort——
// activity（last_message_at）/ created（created_at）经 Page，或 name（title COLLATE NOCASE）经 PageAsc——各按自身列 keyset 分页。
package conversation

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the conversations DDL, exported as ordered idempotent statements for bootstrap to
// apply via db.Migrate. A business/Log table with soft-delete (deleted_at) per D1; the partial
// list index keys the pinned-first, newest-next ordering the frontend renders.
//
// Schema 是 conversations 表 DDL，按序幂等语句导出、由 bootstrap 经 db.Migrate 应用。业务表带
// 软删（deleted_at，D1）；partial 列表索引键住「置顶优先、再最新」的前端渲染顺序。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS conversations (
		id                       TEXT PRIMARY KEY,
		workspace_id             TEXT NOT NULL,
		title                    TEXT NOT NULL DEFAULT '',
		auto_titled              INTEGER NOT NULL DEFAULT 0,
		system_prompt            TEXT NOT NULL DEFAULT '',
		summary                  TEXT NOT NULL DEFAULT '',
		summary_covers_up_to_seq INTEGER NOT NULL DEFAULT 0,
		attached_documents       TEXT NOT NULL DEFAULT '[]',
		archived                 INTEGER NOT NULL DEFAULT 0,
		pinned                   INTEGER NOT NULL DEFAULT 0,
		model_override           TEXT,
		created_at               DATETIME NOT NULL,
		updated_at               DATETIME NOT NULL,
		last_message_at          DATETIME NOT NULL,
		last_message_preview     TEXT NOT NULL DEFAULT '',
		deleted_at               DATETIME
	)`,
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_list ON conversations(workspace_id, pinned DESC, last_message_at DESC, id DESC) WHERE deleted_at IS NULL`,
	// sort=name covering index: pinned-first, then title A–Z (COLLATE NOCASE, matching the ORDER BY +
	// keyset comparison), id ASC tiebreaker. Mirrors the activity index for the title-keyed page.
	// sort=name 覆盖索引:置顶优先、再 title A–Z（COLLATE NOCASE，与 ORDER BY + keyset 比较一致）、id 升序 tiebreaker。
	`CREATE INDEX IF NOT EXISTS idx_conversations_ws_title ON conversations(workspace_id, pinned DESC, title COLLATE NOCASE ASC, id ASC) WHERE deleted_at IS NULL`,
}

// Store implements conversationdomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 conversationdomain.Repository。
type Store struct {
	db   *ormpkg.DB
	repo *ormpkg.Repo[conversationdomain.Conversation]
}

// New constructs a Store bound to the conversations table.
//
// New 构造绑定 conversations 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{db: db, repo: ormpkg.For[conversationdomain.Conversation](db, "conversations")}
}

var _ conversationdomain.Repository = (*Store)(nil)

func (s *Store) Insert(ctx context.Context, c *conversationdomain.Conversation) error {
	if err := s.repo.Create(ctx, c); err != nil {
		return fmt.Errorf("conversationstore.Insert: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*conversationdomain.Conversation, error) {
	c, err := s.repo.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, conversationdomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("conversationstore.Get: %w", err)
	}
	return c, nil
}

func (s *Store) GetBatch(ctx context.Context, ids []string) ([]*conversationdomain.Conversation, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := s.repo.WhereIn("id", toAny(ids)...).Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("conversationstore.GetBatch: %w", err)
	}
	return rows, nil
}

// List returns one page, pinned-first, with the secondary key chosen by filter.Sort (default
// activity). The cursor keys only (sortColumn, id) — the leading pinned partition relies on all pins
// landing on page one (few, single-user), so it never drifts across pages. PageKeyset aligns the
// cursor column with the ORDER BY's sort column (the keyset invariant); the name path additionally
// keeps that alignment collation-sensitive (COLLATE NOCASE on column, ORDER BY, and index alike).
//
// List 返一页，置顶优先，次键由 filter.Sort 选（默认 activity）。游标只键 (sortColumn, id)——置顶分区靠
// 「所有置顶都落首页」（少、单用户）故不跨页漂移。PageKeyset 让游标列与 ORDER BY 排序列对齐（keyset 不变量）；
// name 路径另把这个对齐做成对 collation 敏感（列 / ORDER BY / 索引同 COLLATE NOCASE）。
func (s *Store) List(ctx context.Context, filter conversationdomain.ListFilter) ([]*conversationdomain.Conversation, string, error) {
	q := s.repo.Query()
	if filter.Archived == nil {
		q = q.WhereEq("archived", false)
	} else {
		q = q.WhereEq("archived", *filter.Archived)
	}
	if term := strings.TrimSpace(filter.Search); term != "" {
		q = q.Where("title LIKE ?", "%"+term+"%")
	}
	// Sort is always pinned-first; the secondary key is recency (default) or creation order. The
	// keyset cursor MUST key the same column the ORDER BY sorts by — PageKeyset aligns them, so the
	// cursor's WHERE/encode track the chosen column (else pages skip/duplicate). Unknown/empty sort
	// → activity (no 400 on a sort typo).
	//
	// 排序恒置顶优先；次键为最近活跃（默认）或创建序。keyset 游标必须键 ORDER BY 所按的同一列——PageKeyset
	// 对齐之，使游标 WHERE/encode 跟选定列（否则跨页漏/重）。未知/空 sort → activity（不为 sort 笔误报 400）。
	var (
		rows []*conversationdomain.Conversation
		next string
		err  error
	)
	if filter.Sort == conversationdomain.ListSortName {
		// Title A–Z (case-insensitive), pinned-first, id ASC tiebreaker — a STRING keyset via PageAsc
		// (ascending). Order, keyset column, and the idx_conversations_ws_title index all agree on
		// COLLATE NOCASE + direction (the keyset invariant, collation-sensitive here).
		// title A–Z（大小写不敏感）、置顶优先、id 升序 tiebreaker——经 PageAsc 的字符串升序 keyset。Order / keyset 列 /
		// idx_conversations_ws_title 索引三处在 COLLATE NOCASE + 方向上一致（keyset 不变量，此处对 collation 敏感）。
		rows, next, err = q.Order("pinned DESC, title COLLATE NOCASE ASC, id ASC").PageKeyset("title").PageAsc(ctx, filter.Cursor, filter.Limit)
	} else {
		// activity (default) / created: time-keyed, pinned-first, descending via Page.
		// activity（默认）/ created：时间键、置顶优先、降序，经 Page。
		keyset := "last_message_at"
		if filter.Sort == conversationdomain.ListSortCreated {
			keyset = "created_at"
		}
		rows, next, err = q.Order("pinned DESC, "+keyset+" DESC, id DESC").PageKeyset(keyset).Page(ctx, filter.Cursor, filter.Limit)
	}
	if err != nil {
		return nil, "", fmt.Errorf("conversationstore.List: %w", err)
	}
	return rows, next, nil
}

// TouchLastMessage sets last_message_at (and, when non-empty, last_message_preview) on one
// conversation (chat calls it when a message lands). An empty preview keeps the existing one — an
// attachment-only / tool-only turn leaves the last meaningful snippet in place. last_message_preview
// is NOT a sort/cursor key, so the partial list index is untouched.
//
// TouchLastMessage 设某对话的 last_message_at（preview 非空时一并设 last_message_preview）（chat 在消息落地时调）。
// 空 preview 保留原有——附件-only / 纯工具回合不动上一条有意义的摘要。last_message_preview 非排序/游标键，partial 列表索引不动。
func (s *Store) TouchLastMessage(ctx context.Context, id string, t time.Time, preview string) error {
	updates := map[string]any{"last_message_at": t}
	if preview != "" {
		updates["last_message_preview"] = preview
	}
	if _, err := s.repo.Query().WhereEq("id", id).Updates(ctx, updates); err != nil {
		return fmt.Errorf("conversationstore.TouchLastMessage: %w", err)
	}
	return nil
}

func (s *Store) Update(ctx context.Context, c *conversationdomain.Conversation) error {
	if err := s.repo.Save(ctx, c); err != nil {
		return fmt.Errorf("conversationstore.Update: %w", err)
	}
	return nil
}

func (s *Store) SoftDelete(ctx context.Context, id string) error {
	found, err := s.repo.Delete(ctx, id)
	if err != nil {
		return fmt.Errorf("conversationstore.SoftDelete: %w", err)
	}
	if !found {
		return conversationdomain.ErrNotFound
	}
	return nil
}

// toAny widens a []string to []any for orm WhereIn variadic args.
//
// toAny 把 []string 拓宽为 []any 以喂 orm WhereIn 变长参数。
func toAny(ss []string) []any {
	out := make([]any, len(ss))
	for i, v := range ss {
		out[i] = v
	}
	return out
}
