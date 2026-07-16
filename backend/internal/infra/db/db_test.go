package db

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

const dummyDDL = `CREATE TABLE IF NOT EXISTS dummies (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '')`

func TestOpen_InMemory(t *testing.T) {
	db, err := Open(Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
}

func TestOpen_FileDB_CreatesFile(t *testing.T) {
	dir := t.TempDir()
	db, err := Open(Config{DataDir: dir})
	if err != nil {
		t.Fatalf("open: %v", err) // also asserts WAL (verifyPragmas fails otherwise)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := os.Stat(filepath.Join(dir, "anselm.db")); err != nil {
		t.Errorf("anselm.db not created: %v", err)
	}
}

func TestOpen_InvalidDataDir(t *testing.T) {
	f, err := os.CreateTemp("", "notadir-*")
	if err != nil {
		t.Fatalf("temp file: %v", err)
	}
	defer os.Remove(f.Name())
	_ = f.Close()

	if _, err := Open(Config{DataDir: f.Name()}); err == nil {
		t.Error("opening DB where the path is a file should fail")
	}
}

func TestMigrate_CreatesTableIdempotent(t *testing.T) {
	db, err := Open(Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if err := Migrate(db, dummyDDL); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := Migrate(db, dummyDDL); err != nil {
		t.Fatalf("migrate second run (must be idempotent): %v", err)
	}

	// The migrated table is usable.
	if _, err := db.Exec(context.Background(), `INSERT INTO dummies (id, name) VALUES ('x', 'hi')`); err != nil {
		t.Errorf("insert into migrated table: %v", err)
	}
}

func TestMigrate_NilDB(t *testing.T) {
	if err := Migrate(nil, dummyDDL); err == nil {
		t.Error("Migrate(nil, ...) should fail")
	}
}

// TestMigrate_AddColumnIdempotentByOutcome pins the column-evolution rule: an ALTER TABLE … ADD
// COLUMN is idempotent BY OUTCOME (SQLite has no IF NOT EXISTS for columns) — its "duplicate
// column name" error means already-applied and must be skipped, on every startup re-run, while an
// old table really gains the column. Any other failing statement still fails the migration.
//
// TestMigrate_AddColumnIdempotentByOutcome 钉列演化规则：ALTER TABLE … ADD COLUMN 靠**结果幂等**
// （SQLite 列无 IF NOT EXISTS）——其 "duplicate column name" 错误即已应用、每次启动重跑都须跳过，
// 而真旧表则真补上列。其他失败语句仍令迁移失败。
func TestMigrate_AddColumnIdempotentByOutcome(t *testing.T) {
	db, err := Open(Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	ddl := []string{
		dummyDDL,
		`ALTER TABLE dummies ADD COLUMN origin TEXT CHECK (origin IN ('a','b'))`,
	}
	if err := Migrate(db, ddl...); err != nil {
		t.Fatalf("migrate (fresh — CREATE then ADD COLUMN): %v", err)
	}
	if err := Migrate(db, ddl...); err != nil {
		t.Fatalf("migrate re-run (duplicate column must read as applied): %v", err)
	}

	ctx := context.Background()
	// The evolved column is real: a legal value inserts, an out-of-CHECK value is rejected.
	// 演化列是真的：合法值可插，越 CHECK 值被拒。
	if _, err := db.Exec(ctx, `INSERT INTO dummies (id, name, origin) VALUES ('x', 'hi', 'a')`); err != nil {
		t.Errorf("insert into evolved column: %v", err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO dummies (id, name, origin) VALUES ('y', 'yo', 'nope')`); err == nil {
		t.Error("CHECK on the added column must reject an out-of-enum value")
	}

	// A non-ADD-COLUMN failure is never swallowed. 非加列失败绝不吞。
	if err := Migrate(db, `CREATE INDEX idx_dummy_dup ON dummies(name)`, `CREATE INDEX idx_dummy_dup ON dummies(name)`); err == nil {
		t.Error("a genuine duplicate-DDL error must still fail the migration")
	}
}
