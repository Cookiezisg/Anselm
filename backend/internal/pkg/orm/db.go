package orm

import (
	"context"
	"database/sql"
	"fmt"
)

// DBTX is the subset of *sql.DB and *sql.Tx the ORM executes through, so a Repo
// behaves identically inside or outside a transaction.
//
// DBTX 是 ORM 执行所依赖的 *sql.DB / *sql.Tx 公共子集，使 Repo 在事务内外行为一致。
type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

// DB wraps a database/sql handle (a connection pool, or a transaction) as the
// ORM root. The pool field is non-nil only on the root — inside a transaction
// it is nil, which is how Transaction detects flat nesting.
//
// DB 把 database/sql 句柄（连接池或事务）包成 ORM 根。pool 仅在根上非 nil；
// 事务内为 nil——Transaction 据此识别扁平嵌套。
type DB struct {
	h    DBTX
	pool *sql.DB
}

// Open wraps a *sql.DB pool as the ORM root. Close it with DB.Close.
//
// Open 把 *sql.DB 连接池包成 ORM 根。用 DB.Close 关闭。
func Open(pool *sql.DB) *DB {
	return &DB{h: pool, pool: pool}
}

// handle returns the execer this DB runs through (pool or tx).
//
// handle 返回该 DB 执行所用的 execer（池或事务）。
func (db *DB) handle() DBTX { return db.h }

// Transaction runs fn inside one SQL transaction: commit on nil error, rollback
// otherwise. A call already inside a transaction reuses the outer tx (flat
// nesting — no savepoints), so composing transactional store methods is safe.
//
// Transaction 在单个 SQL 事务内执行 fn：nil 错误提交，否则回滚。已在事务内的调用
// 复用外层 tx（扁平嵌套、无 savepoint），故组合多个事务型 store 方法是安全的。
func (db *DB) Transaction(ctx context.Context, fn func(tx *DB) error) error {
	if db.pool == nil {
		return fn(db) // already inside a tx — reuse it. 已在事务内——复用。
	}
	sqlTx, err := db.pool.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("orm: begin tx: %w", err)
	}
	if err := fn(&DB{h: sqlTx}); err != nil {
		_ = sqlTx.Rollback()
		return err
	}
	if err := sqlTx.Commit(); err != nil {
		return fmt.Errorf("orm: commit tx: %w", err)
	}
	return nil
}

// Exec runs a raw statement and returns its result — the escape hatch for SQL
// that isn't row-mapped CRUD: migrations (DDL), PRAGMA, one-off maintenance.
//
// Exec 执行原始语句并返回结果——非行映射 CRUD 的逃生口：迁移（DDL）、PRAGMA、一次性维护。
func (db *DB) Exec(ctx context.Context, query string, args ...any) (sql.Result, error) {
	return db.handle().ExecContext(ctx, query, args...)
}

// Close closes the underlying connection pool; safe on a transaction wrapper
// (which owns no pool) and on a nil receiver.
//
// Close 关闭底层连接池；对事务包装（不持池）与 nil receiver 都安全。
func (db *DB) Close() error {
	if db == nil || db.pool == nil {
		return nil
	}
	return db.pool.Close()
}
