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
