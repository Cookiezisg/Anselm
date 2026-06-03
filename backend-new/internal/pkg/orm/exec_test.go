package orm

import "testing"

func TestExec_RawStatement(t *testing.T) {
	db, ctx := newTestDB(t)

	// Create a side table via the escape hatch, then write to it.
	if _, err := db.Exec(ctx, `CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)`); err != nil {
		t.Fatalf("exec create: %v", err)
	}
	res, err := db.Exec(ctx, `INSERT INTO kv (k, v) VALUES (?, ?)`, "a", "1")
	if err != nil {
		t.Fatalf("exec insert: %v", err)
	}
	if n, _ := res.RowsAffected(); n != 1 {
		t.Errorf("rows affected = %d, want 1", n)
	}
}

func TestClose(t *testing.T) {
	db, _ := newTestDB(t)
	if err := db.Close(); err != nil {
		t.Errorf("close: %v", err)
	}
	// nil/double close is safe.
	var nilDB *DB
	if err := nilDB.Close(); err != nil {
		t.Errorf("nil close: %v", err)
	}
}
