// Package workspace is the orm-backed implementation of workspacedomain.Repository.
//
// Package workspace 是 workspacedomain.Repository 的 orm 实现。
package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	workspacedomain "github.com/sunweilin/anselm/backend/internal/domain/workspace"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// Schema is the workspaces DDL, exported as ordered idempotent statements that
// bootstrap collects and applies via db.Migrate. The workspace IS the isolation
// root, so this is the one business table with no workspace_id column. The name
// index is partial (excludes soft-deleted rows) so a deleted name can be reused.
//
// Schema 是 workspaces 表 DDL，按序幂等语句导出，由 bootstrap 汇总经 db.Migrate 应用。
// workspace 就是隔离根，故这是唯一不带 workspace_id 列的业务表。name 索引是 partial
// （排除软删行），使软删掉的名字可被重用。
var Schema = []string{
	`CREATE TABLE IF NOT EXISTS workspaces (
		id           TEXT PRIMARY KEY,
		name         TEXT NOT NULL,
		avatar_color TEXT NOT NULL DEFAULT '',
		language     TEXT NOT NULL DEFAULT 'zh-CN' CHECK (language IN ('zh-CN','en')),
		default_dialogue TEXT,
		default_utility  TEXT,
		default_agent    TEXT,
		default_search_key_id TEXT NOT NULL DEFAULT '',
		web_fetch_mode TEXT NOT NULL DEFAULT '' CHECK (web_fetch_mode IN ('','local','jina')),
		last_used_at DATETIME,
		created_at   DATETIME NOT NULL,
		updated_at   DATETIME NOT NULL,
		deleted_at   DATETIME
	)`,
	`CREATE UNIQUE INDEX IF NOT EXISTS idx_workspaces_name ON workspaces(name) WHERE deleted_at IS NULL`,
}

// Store implements workspacedomain.Repository over pkg/orm.
//
// Store 基于 pkg/orm 实现 workspacedomain.Repository。
type Store struct {
	repo *ormpkg.Repo[workspacedomain.Workspace]
	db   *ormpkg.DB // raw handle for Stats' cross-table counts Stats 跨表计数的裸把手
}

// New builds a Store bound to the workspaces table.
//
// New 构造绑定 workspaces 表的 Store。
func New(db *ormpkg.DB) *Store {
	return &Store{repo: ormpkg.For[workspacedomain.Workspace](db, "workspaces"), db: db}
}

var _ workspacedomain.Repository = (*Store)(nil)

// Save upserts; a duplicate name (UNIQUE index) surfaces as ErrNameConflict —
// the orm gateway already translated the SQLite violation to ErrConflict.
//
// Save upsert；重名（UNIQUE 索引）冒泡为 ErrNameConflict——orm 网关已把 SQLite 违例译为 ErrConflict。
func (s *Store) Save(ctx context.Context, w *workspacedomain.Workspace) error {
	if err := s.repo.Save(ctx, w); err != nil {
		if errors.Is(err, ormpkg.ErrConflict) {
			return workspacedomain.ErrNameConflict
		}
		return fmt.Errorf("workspacestore.Save: %w", err)
	}
	return nil
}

func (s *Store) Get(ctx context.Context, id string) (*workspacedomain.Workspace, error) {
	w, err := s.repo.Get(ctx, id)
	if errors.Is(err, ormpkg.ErrNotFound) {
		return nil, workspacedomain.ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("workspacestore.Get: %w", err)
	}
	return w, nil
}

// List returns all workspaces oldest-first. No workspace filter applies (the
// table has no workspace_id), so it works before any workspace is selected.
//
// List 按最早优先返回所有 workspace。无 workspace 过滤（表无 workspace_id），故在未选
// workspace 前也可用。
func (s *Store) List(ctx context.Context) ([]*workspacedomain.Workspace, error) {
	rows, err := s.repo.Order("created_at ASC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("workspacestore.List: %w", err)
	}
	return rows, nil
}

func (s *Store) Delete(ctx context.Context, id string) error {
	found, err := s.repo.Delete(ctx, id)
	if err != nil {
		return fmt.Errorf("workspacestore.Delete: %w", err)
	}
	if !found {
		return workspacedomain.ErrNotFound
	}
	return nil
}

func (s *Store) Count(ctx context.Context) (int, error) {
	n, err := s.repo.Query().Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("workspacestore.Count: %w", err)
	}
	return int(n), nil
}

func (s *Store) TouchLastUsed(ctx context.Context, id string) error {
	n, err := s.repo.WhereEq("id", id).Update(ctx, "last_used_at", time.Now().UTC())
	if err != nil {
		return fmt.Errorf("workspacestore.TouchLastUsed: %w", err)
	}
	if n == 0 {
		return workspacedomain.ErrNotFound
	}
	return nil
}

// Stats counts the workspace's contents in one query batch (correlated scalar subqueries — one
// round trip). Soft-deletable tables filter deleted_at; flowruns is a Log table (no deleted_at,
// D1) and counts status='running' via its partial index. The generating intersection is computed
// against the caller-supplied in-flight ids (chat memory state, not a column).
//
// Stats 一批查询数完(相关标量子查询,一次往返)。软删表滤 deleted_at;flowruns 是 Log 表(无
// deleted_at,D1)、经 partial 索引数 status='running'。generating 交集按调用方给的在飞 id 集算。
func (s *Store) Stats(ctx context.Context, id string, generatingIDs []string) (*workspacedomain.Stats, error) {
	st := &workspacedomain.Stats{}
	row := s.db.QueryRow(ctx, `SELECT
		(SELECT COUNT(*) FROM conversations WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM functions     WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM handlers      WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM agents        WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM workflows     WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM documents     WHERE workspace_id=?1 AND deleted_at IS NULL),
		(SELECT COUNT(*) FROM flowruns      WHERE workspace_id=?1 AND status='running')`, id)
	if err := row.Scan(&st.Conversations, &st.Functions, &st.Handlers, &st.Agents,
		&st.Workflows, &st.Documents, &st.RunningFlowruns); err != nil {
		return nil, fmt.Errorf("workspacestore.Stats: %w", err)
	}
	if len(generatingIDs) > 0 {
		args := make([]any, 0, len(generatingIDs)+1)
		args = append(args, id)
		ph := make([]byte, 0, len(generatingIDs)*2)
		for i, cv := range generatingIDs {
			if i > 0 {
				ph = append(ph, ',')
			}
			ph = append(ph, '?')
			args = append(args, cv)
		}
		row := s.db.QueryRow(ctx, `SELECT COUNT(*) FROM conversations
			WHERE workspace_id=?1 AND deleted_at IS NULL AND id IN (`+string(ph)+`)`, args...)
		if err := row.Scan(&st.GeneratingConversations); err != nil {
			return nil, fmt.Errorf("workspacestore.Stats: generating: %w", err)
		}
	}
	return st, nil
}
