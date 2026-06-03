package orm

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// widget is the test model exercising every db-tag role.
//
// widget 是覆盖每种 db-tag 角色的测试模型。
type widget struct {
	ID          string     `db:"id,pk"`
	WorkspaceID string     `db:"workspace_id,ws"`
	Name        string     `db:"name"`
	Tags        []string   `db:"tags,json"`
	Score       int        `db:"score"`
	CreatedAt   time.Time  `db:"created_at,created"`
	UpdatedAt   time.Time  `db:"updated_at,updated"`
	DeletedAt   *time.Time `db:"deleted_at,deleted"`
}

const widgetSchema = `
CREATE TABLE widgets (
	id           TEXT PRIMARY KEY,
	workspace_id TEXT NOT NULL,
	name         TEXT NOT NULL DEFAULT '',
	tags         TEXT NOT NULL DEFAULT '[]',
	score        INTEGER NOT NULL DEFAULT 0,
	created_at   DATETIME,
	updated_at   DATETIME,
	deleted_at   DATETIME
)`

// newTestDB opens an in-memory SQLite db (pinned to one connection for :memory:
// isolation), creates the widgets table, and returns an ORM DB plus a ctx
// carrying workspace "ws_1".
//
// newTestDB 开内存 SQLite（锁 1 连接以隔离 :memory:）、建 widgets 表，返回 ORM DB
// 及携带 workspace "ws_1" 的 ctx。
func newTestDB(t *testing.T) (*DB, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	if _, err := sqlDB.Exec(widgetSchema); err != nil {
		t.Fatalf("schema: %v", err)
	}
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	return Open(sqlDB), ctx
}

func widgets(db *DB) *Repo[widget] { return For[widget](db, "widgets") }

// mustCreate seeds one widget or fails the test.
//
// mustCreate 播种一个 widget，失败即终止测试。
func mustCreate(t *testing.T, r *Repo[widget], ctx context.Context, id, name string, score int) {
	t.Helper()
	if err := r.Create(ctx, &widget{ID: id, Name: name, Score: score}); err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
}
