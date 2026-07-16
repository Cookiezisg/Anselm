package db

// rebuild_test.go pins MigrateRebuild's contract: SQLite cannot ALTER a CHECK, so a CHECK that
// gains a word (first case: trigger_firings.status += 'missed', scheduler 工单⑨) must REBUILD the
// table on an install that predates the change — while a fresh install and every later boot no-op.
// Idempotence is BY OUTCOME (the live DDL carries the marker), the same family as Migrate's
// duplicate-column rule.
//
// rebuild_test.go 钉 MigrateRebuild 的契约：SQLite 无法 ALTER CHECK，故 CHECK 加词（首例：
// trigger_firings.status += 'missed'，scheduler 工单⑨）在早于该变更的安装上必须**重建**表——而全新安装
// 与其后每次启动都是 no-op。幂等靠**结果**（现行 DDL 带标记词），与 Migrate 的重复列规则同族。

import (
	"context"
	"testing"
)

const oldShape = `CREATE TABLE IF NOT EXISTS widgets (
	id     TEXT PRIMARY KEY,
	status TEXT NOT NULL CHECK (status IN ('live','dead'))
)`

func widgetRebuild() []string {
	return []string{
		`CREATE TABLE widgets_rebuild (
			id     TEXT PRIMARY KEY,
			status TEXT NOT NULL CHECK (status IN ('live','dead','missed'))
		)`,
		`INSERT INTO widgets_rebuild SELECT id, status FROM widgets`,
		`DROP TABLE widgets`,
		`ALTER TABLE widgets_rebuild RENAME TO widgets`,
		`CREATE INDEX idx_widgets_status ON widgets(status)`,
	}
}

// TestMigrateRebuild_WidensCheckAndPreservesData: an OLD install (CHECK without the new word) is
// rebuilt — the new value becomes insertable, existing rows survive verbatim, and the rebuild is
// not repeated on the next boot.
func TestMigrateRebuild_WidensCheckAndPreservesData(t *testing.T) {
	db, err := Open(Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })
	ctx := context.Background()

	// An install predating the change, holding real data.
	// 早于该变更的安装，且有真数据。
	if err := Migrate(db, oldShape); err != nil {
		t.Fatalf("migrate old shape: %v", err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO widgets (id, status) VALUES ('w1','live'), ('w2','dead')`); err != nil {
		t.Fatalf("seed: %v", err)
	}
	// The old CHECK really rejects the new word — this is the condition the rebuild exists to fix.
	// 旧 CHECK 真的拒新词——这正是重建要修的条件。
	if _, err := db.Exec(ctx, `INSERT INTO widgets (id, status) VALUES ('w3','missed')`); err == nil {
		t.Fatal("precondition: the old CHECK must reject 'missed'")
	}

	if err := MigrateRebuild(db, "widgets", "'missed'", widgetRebuild()...); err != nil {
		t.Fatalf("rebuild: %v", err)
	}
	// The widened CHECK accepts the new word.
	// 加宽后的 CHECK 接受新词。
	if _, err := db.Exec(ctx, `INSERT INTO widgets (id, status) VALUES ('w3','missed')`); err != nil {
		t.Fatalf("after rebuild 'missed' must insert: %v", err)
	}
	// Data survived the copy verbatim.
	// 数据逐字幸存于拷贝。
	var n int
	if err := db.QueryRow(ctx, `SELECT COUNT(*) FROM widgets`).Scan(&n); err != nil || n != 3 {
		t.Fatalf("rows after rebuild = %d (err=%v), want 3 (2 copied + 1 new)", n, err)
	}
	var status string
	if err := db.QueryRow(ctx, `SELECT status FROM widgets WHERE id = 'w1'`).Scan(&status); err != nil || status != "live" {
		t.Fatalf("copied row w1 = %q (err=%v), want live", status, err)
	}
	// The rebuild's indexes exist again (they die with the dropped table).
	// 重建的索引重新存在（它们随被删的旧表而死）。
	if err := db.QueryRow(ctx, `SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_widgets_status'`).Scan(&n); err != nil || n != 1 {
		t.Fatalf("the rebuild must recreate its indexes: n=%d err=%v", n, err)
	}

	// Idempotent by outcome: a second call sees the marker and does nothing. Proven by the data
	// surviving — a blind re-run would hit "table widgets_rebuild already exists" / drop rows.
	// 结果幂等：第二次调用看到标记词、什么都不做。以数据幸存为证——盲目重跑会撞
	// 「widgets_rebuild 已存在」/ 丢行。
	if err := MigrateRebuild(db, "widgets", "'missed'", widgetRebuild()...); err != nil {
		t.Fatalf("second rebuild must be a no-op, got: %v", err)
	}
	if err := db.QueryRow(ctx, `SELECT COUNT(*) FROM widgets`).Scan(&n); err != nil || n != 3 {
		t.Fatalf("a no-op rebuild must not touch data: n=%d err=%v", n, err)
	}
}

// TestMigrateRebuild_FreshInstallAndMissingTableNoOp: a fresh install already created the current
// shape (marker present) → never rebuilt; an absent table → no-op, not an error (a test schema that
// simply does not include the table).
func TestMigrateRebuild_FreshInstallAndMissingTableNoOp(t *testing.T) {
	db, err := Open(Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	// Absent table: nothing to rebuild, and the caller must not have to guard.
	// 表不存在：无可重建，调用方也不该被迫加守卫。
	if err := MigrateRebuild(db, "widgets", "'missed'", `SELECT 1/0`); err != nil {
		t.Fatalf("a missing table must be a no-op, got: %v", err)
	}

	// Fresh install: created at the CURRENT shape, so the marker is already there → no rebuild.
	// The rebuild statements are deliberately poisonous: running them would fail the test.
	// 全新安装：按**当前**形状建表，标记词已在 → 不重建。重建语句刻意有毒：跑到它们就会失败。
	current := `CREATE TABLE IF NOT EXISTS widgets (
		id     TEXT PRIMARY KEY,
		status TEXT NOT NULL CHECK (status IN ('live','dead','missed'))
	)`
	if err := Migrate(db, current); err != nil {
		t.Fatalf("migrate current shape: %v", err)
	}
	if err := MigrateRebuild(db, "widgets", "'missed'", `SELECT 1/0`); err != nil {
		t.Fatalf("a fresh install must not rebuild, got: %v", err)
	}
}

func TestMigrateRebuild_NilDB(t *testing.T) {
	if err := MigrateRebuild(nil, "widgets", "'missed'"); err == nil {
		t.Error("MigrateRebuild(nil, ...) should fail")
	}
}
