// Package todo is the orm-backed implementation of tododomain.Repository: one checklist
// row per execution scope (workspace, conversation, subagent?). Workspace isolation is
// automatic (orm fills/filters workspace_id from ctx). scope_id (= subagent id ?? conv
// id) is the natural PK — globally unique either way, so there is no surrogate id and no
// COALESCE-uniqueness trick. The list is the row; items live as a JSON column, replaced
// wholesale on each write.
//
// Package todo 是 tododomain.Repository 的 orm 实现：每执行作用域一张清单行（workspace,
// conversation, subagent?）。workspace 隔离自动（orm 据 ctx 填/过滤 workspace_id）。scope_id
// （= subagent id ?? conv id）是天然 PK——两种情况都全局唯一，故无代理 id、无 COALESCE 唯一
// 技巧。清单即行；items 作 JSON 列存，每次写整体替换。
package todo

import (
	"context"
	"errors"
	"fmt"

	tododomain "github.com/sunweilin/foryx/backend/internal/domain/todo"
	ormpkg "github.com/sunweilin/foryx/backend/internal/pkg/orm"
)

// Schema is the todos DDL, exported as ordered idempotent statements for bootstrap to
// collect and apply via db.Migrate. deleted_at honors D1 (soft-delete) even though no
// deletion path exists yet (a conversation-delete cascade would be the only one). The
// index supports an "all lists of a conversation" cleanup query.
//
// Schema 是 todos 表 DDL，按序幂等语句导出，由 bootstrap 汇总经 db.Migrate 应用。deleted_at
// 守 D1（软删），尽管目前尚无删除路径（唯一可能的删除路径是对话删除时的级联）。索引支撑"某对话所有清单"清理查询。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS todos (
		scope_id        TEXT PRIMARY KEY,
		workspace_id    TEXT NOT NULL,
		conversation_id TEXT NOT NULL,
		subagent_id     TEXT,
		items           TEXT NOT NULL DEFAULT '[]',
		created_at      DATETIME NOT NULL,
		updated_at      DATETIME NOT NULL,
		deleted_at      DATETIME
	)`,
	`CREATE INDEX IF NOT EXISTS idx_todos_ws_conversation ON todos(workspace_id, conversation_id) WHERE deleted_at IS NULL`,
}

// Store implements tododomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 tododomain.Repository。
type Store struct {
	repo *ormpkg.Repo[tododomain.List]
}

// New constructs a Store bound to the todos table.
//
// New 构造绑定 todos 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[tododomain.List](db, "todos")}
}

var _ tododomain.Repository = (*Store)(nil)

// GetByScope returns the checklist for scopeID, or (nil, nil) when the scope has none —
// an absent list is an empty checklist, not an error.
//
// GetByScope 返回 scopeID 的清单，无则 (nil, nil)——无清单即空清单、非错误。
func (s *Store) GetByScope(ctx context.Context, scopeID string) (*tododomain.List, error) {
	l, err := s.repo.Get(ctx, scopeID)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("todostore.GetByScope: %w", err)
	}
	return l, nil
}

// Upsert writes the whole checklist: insert when the scope's row is new, else replace its
// items in place (preserving created_at; orm refreshes updated_at). Whole-list-replace
// semantics — the row is the list, not a set of item rows.
//
// Upsert 写整张清单：作用域行不存在则 insert、否则就地替换其 items（保 created_at；orm 刷新
// updated_at）。整列替换语义——行即清单、非项行集合。
func (s *Store) Upsert(ctx context.Context, l *tododomain.List) error {
	existing, err := s.repo.Get(ctx, l.ScopeID)
	switch {
	case errors.Is(err, ormpkg.ErrNotFound):
		if err := s.repo.Create(ctx, l); err != nil {
			return fmt.Errorf("todostore.Upsert insert: %w", err)
		}
		return nil
	case err != nil:
		return fmt.Errorf("todostore.Upsert lookup: %w", err)
	}
	existing.Items = l.Items
	if err := s.repo.Save(ctx, existing); err != nil {
		return fmt.Errorf("todostore.Upsert save: %w", err)
	}
	return nil
}
