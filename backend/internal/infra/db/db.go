// Package db is the SQLite gateway: it opens a database/sql pool with the right
// pragmas and wraps it as an *orm.DB. It knows nothing about business tables —
// each module owns its schema DDL, applied here via Migrate.
//
// Package db 是 SQLite 网关：以正确 pragma 打开 database/sql 池并包成 *orm.DB。
// 它不认识任何业务表——schema DDL 由各模块持有，经 Migrate 在此应用。
package db

import (
	"database/sql"
	"fmt"
	"os"

	// glebarez/go-sqlite registers the pure-Go "sqlite" database/sql driver (modernc, no CGO).
	// glebarez/go-sqlite 注册纯 Go 的 "sqlite" database/sql driver（modernc 底层，无 CGO）。
	_ "github.com/glebarez/go-sqlite"

	ormpkg "github.com/sunweilin/foryx/backend/internal/pkg/orm"
)

// Config opens the DB; the zero value is an in-memory DB (test default).
//
// Config 打开 DB 的配置；零值为内存 DB（测试默认）。
type Config struct {
	DataDir string
}

// Open returns a SQLite *orm.DB with WAL, foreign_keys, busy_timeout and a
// single connection. SQLite/WAL is single-writer; pinning to one connection
// serializes writes at the Go level (no SQLITE_BUSY lock-upgrade races) and
// gives an in-memory DB a stable shared database across goroutines.
//
// Open 返回启用 WAL、FK、busy_timeout 且锁单连接的 SQLite *orm.DB。SQLite/WAL
// 单写者，锁单连接在 Go 层串行化写（无 SQLITE_BUSY 竞升锁），并让内存库在多
// goroutine 间共享同一数据库。
func Open(cfg Config) (*ormpkg.DB, error) {
	dsn, err := buildDSN(cfg.DataDir)
	if err != nil {
		return nil, err
	}
	sqlDB, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("db: open: %w", err)
	}
	sqlDB.SetMaxOpenConns(1)
	if err := verifyPragmas(sqlDB, cfg.DataDir != ""); err != nil {
		_ = sqlDB.Close()
		return nil, err
	}
	return ormpkg.Open(sqlDB), nil
}

func buildDSN(dataDir string) (string, error) {
	params := "_pragma=journal_mode(WAL)" +
		"&_pragma=busy_timeout(5000)" +
		"&_pragma=foreign_keys(on)" +
		"&_pragma=synchronous(NORMAL)"
	if dataDir == "" {
		return ":memory:?" + params, nil
	}
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return "", fmt.Errorf("db: mkdir %s: %w", dataDir, err)
	}
	return fmt.Sprintf("file:%s/foryx.db?%s", dataDir, params), nil
}

// verifyPragmas confirms foreign_keys is on (always) and, for a file DB, that
// journal_mode is WAL — so a misconfigured DSN fails loudly at startup rather
// than silently dropping isolation/durability guarantees. (:memory: ignores WAL.)
//
// verifyPragmas 确认 foreign_keys 开启（总是），且文件库的 journal_mode 为 WAL
// ——DSN 配错则启动期响亮失败，而非静默丢隔离/持久化保证。（:memory: 不支持 WAL。）
func verifyPragmas(sqlDB *sql.DB, wantWAL bool) error {
	var fk int
	if err := sqlDB.QueryRow("PRAGMA foreign_keys").Scan(&fk); err != nil {
		return fmt.Errorf("db: query foreign_keys: %w", err)
	}
	if fk != 1 {
		return fmt.Errorf("db: foreign_keys = %d, want 1", fk)
	}
	if wantWAL {
		var mode string
		if err := sqlDB.QueryRow("PRAGMA journal_mode").Scan(&mode); err != nil {
			return fmt.Errorf("db: query journal_mode: %w", err)
		}
		if mode != "wal" {
			return fmt.Errorf("db: journal_mode = %q, want wal", mode)
		}
	}
	return nil
}
