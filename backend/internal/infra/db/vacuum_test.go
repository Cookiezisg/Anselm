package db

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"testing"

	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// fillAndDeleteRatchet inserts n one-row-per-page rows, then deletes deleteMod-of-every-deleteMod so
// whole pages go free, returning the row count that survives. A 3 KiB payload guarantees ~one row
// per 4 KiB page, so a deleted row frees a whole page (not a half-empty one).
//
// fillAndDeleteRatchet 插 n 行（每行占一页），再删掉每 deleteMod 行里的 deleteMod-1 行使整页腾空，返回存活行数。
// 3 KiB payload 保证约一行一页（4 KiB），故删一行腾一整页（而非半空页）。
func fillAndDeleteRatchet(t *testing.T, db *ormpkg.DB, n, deleteMod int) int {
	t.Helper()
	ctx := context.Background()
	if _, err := db.Exec(ctx, `CREATE TABLE t (id INTEGER PRIMARY KEY, payload BLOB)`); err != nil {
		t.Fatal(err)
	}
	blob := make([]byte, 3000)
	err := db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i := 0; i < n; i++ {
			if _, err := tx.Exec(ctx, `INSERT INTO t (id, payload) VALUES (?, ?)`, i, blob); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `DELETE FROM t WHERE id % ? != 0`, deleteMod); err != nil {
		t.Fatal(err)
	}
	survive := 0
	for i := 0; i < n; i++ {
		if i%deleteMod == 0 {
			survive++
		}
	}
	return survive
}

func fileSizeT(t *testing.T, path string) int64 {
	t.Helper()
	fi, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	return fi.Size()
}

func countRows(t *testing.T, db *ormpkg.DB) int {
	t.Helper()
	var n int
	if err := db.QueryRow(context.Background(), `SELECT COUNT(*) FROM t`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

// TestReclaimFreePages_ShrinksFileAndKeepsRows pins the whole T4 fix on a real on-disk DB: a fresh
// install is born auto_vacuum=INCREMENTAL, DELETE alone frees ZERO bytes on disk (SQLite's ratchet —
// the bug), and ReclaimFreePages then truly shrinks the .db file while every surviving row stays.
//
// TestReclaimFreePages_ShrinksFileAndKeepsRows 在真实落盘库上钉住整个 T4 修复：全新安装天生
// auto_vacuum=INCREMENTAL，光 DELETE 在磁盘上腾零字节（SQLite 的棘轮——即 bug），ReclaimFreePages 随后真的
// 缩小 .db 文件、且每一存活行都在。
func TestReclaimFreePages_ShrinksFileAndKeepsRows(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "anselm.db")
	db, err := Open(Config{DataDir: dir})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	ctx := context.Background()

	// Fresh install must be born INCREMENTAL (buildDSN ordering). 全新安装必须天生 INCREMENTAL。
	if mode, _ := pragmaInt(ctx, db, "auto_vacuum"); mode != autoVacuumIncremental {
		t.Fatalf("fresh file DB auto_vacuum = %d, want %d (INCREMENTAL)", mode, autoVacuumIncremental)
	}

	// 15000 rows ≈ 45 MB; delete 80% → ~36 MB dead (> 25% fraction gate). 删 80% 越过 25% 闸。
	want := fillAndDeleteRatchet(t, db, 15000, 5)
	if err := checkpointTruncate(ctx, db); err != nil {
		t.Fatal(err)
	}
	full := fileSizeT(t, dbPath) // captured after the inserts checkpointed to the main file
	if got := countRows(t, db); got != want {
		t.Fatalf("row count after delete = %d, want %d", got, want)
	}

	// The ratchet: DELETE + checkpoint frees NOTHING on disk. This is the bug T4 fixes.
	// 棘轮：DELETE + checkpoint 在磁盘上什么都不腾。这正是 T4 修的 bug。
	afterDelete := fileSizeT(t, dbPath)
	if afterDelete < full {
		t.Fatalf("expected the ratchet (delete frees no disk): full=%d afterDelete=%d", full, afterDelete)
	}

	// The fix: reclaim actually returns the freed pages to the filesystem.
	// 修复：回收真把腾出的页还给文件系统。
	reclaimed, err := ReclaimFreePages(ctx, db)
	if err != nil {
		t.Fatalf("reclaim: %v", err)
	}
	afterReclaim := fileSizeT(t, dbPath)
	if afterReclaim >= afterDelete {
		t.Fatalf("file did not shrink: afterDelete=%d afterReclaim=%d (reclaimed reported %d)", afterDelete, afterReclaim, reclaimed)
	}
	if reclaimed <= 0 {
		t.Fatalf("reclaimed reported %d bytes, want > 0", reclaimed)
	}
	// Reclamation is not deletion: every surviving row is intact and readable.
	// 回收不是删除：每一存活行都完好可读。
	if got := countRows(t, db); got != want {
		t.Fatalf("row count after reclaim = %d, want %d (reclamation must not lose rows)", got, want)
	}
	t.Logf("file %d -> %d (delete no-op) -> %d after reclaim (%.1fMB returned, %d rows kept)",
		full, afterDelete, afterReclaim, float64(afterDelete-afterReclaim)/1e6, want)
}

// TestReclaimFreePages_GateHoldsBackRoutineChurn: a small amount of dead space (below both the
// fraction and the absolute-bytes gate) is NOT reclaimed — steady-state churn reuses those pages, so
// reclaiming would only thrash the file. Reported bytes = 0 and the file is untouched.
//
// TestReclaimFreePages_GateHoldsBackRoutineChurn：少量死空间（两道闸——比例与绝对字节——都不过）不回收——
// 稳态 churn 复用这些页，回收只会空折腾文件。返回字节数=0、文件不动。
func TestReclaimFreePages_GateHoldsBackRoutineChurn(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "anselm.db")
	db, err := Open(Config{DataDir: dir})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	ctx := context.Background()

	// 4000 rows, delete only ~5% (id % 20 == 0) → tiny freelist, far below both gates.
	// 只删 ~5%（id % 20 == 0）→ freelist 极小、远在两闸之下。
	if _, err := db.Exec(ctx, `CREATE TABLE t (id INTEGER PRIMARY KEY, payload BLOB)`); err != nil {
		t.Fatal(err)
	}
	blob := make([]byte, 3000)
	if err := db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i := 0; i < 4000; i++ {
			if _, err := tx.Exec(ctx, `INSERT INTO t (id, payload) VALUES (?, ?)`, i, blob); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `DELETE FROM t WHERE id % 20 = 0`); err != nil {
		t.Fatal(err)
	}
	if err := checkpointTruncate(ctx, db); err != nil {
		t.Fatal(err)
	}
	before := fileSizeT(t, dbPath)
	reclaimed, err := ReclaimFreePages(ctx, db)
	if err != nil {
		t.Fatal(err)
	}
	if reclaimed != 0 {
		t.Fatalf("gate should have held: reclaimed %d bytes for routine churn", reclaimed)
	}
	if after := fileSizeT(t, dbPath); after != before {
		t.Fatalf("file changed under the gate: before=%d after=%d", before, after)
	}
}

// TestEnsureIncrementalAutoVacuum_MigratesLegacyNoneDB pins the existing-install path: a DB whose
// header carries auto_vacuum=NONE (every install predating this fix) is flipped to INCREMENTAL by one
// VACUUM, which ALSO reclaims the dead space it had accumulated, the mode PERSISTS across reopen, the
// gate is idempotent (a second call no-ops), and no row is lost.
//
// TestEnsureIncrementalAutoVacuum_MigratesLegacyNoneDB 钉住存量安装路径：文件头带 auto_vacuum=NONE 的库
// （本修复之前的每个安装）被一次 VACUUM 翻成 INCREMENTAL，且**同时**回收它攒的死空间，模式跨重开**持久**，
// 闸幂等（第二次调用 no-op），且不丢任何行。
func TestEnsureIncrementalAutoVacuum_MigratesLegacyNoneDB(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "legacy.db")
	ctx := context.Background()

	// Simulate a pre-fix install: open with a DSN that has NO auto_vacuum, so the header is born NONE.
	// 模拟修复前安装：用不含 auto_vacuum 的 DSN 打开，文件头天生 NONE。
	legacyDSN := fmt.Sprintf("file:%s?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)&_pragma=foreign_keys(on)&_pragma=synchronous(NORMAL)", dbPath)
	raw, err := sql.Open("sqlite", legacyDSN)
	if err != nil {
		t.Fatal(err)
	}
	raw.SetMaxOpenConns(1)
	legacy := ormpkg.Open(raw)
	if mode, _ := pragmaInt(ctx, legacy, "auto_vacuum"); mode != 0 {
		t.Fatalf("legacy DB auto_vacuum = %d, want 0 (NONE)", mode)
	}
	want := fillAndDeleteRatchet(t, legacy, 15000, 5)
	if err := checkpointTruncate(ctx, legacy); err != nil {
		t.Fatal(err)
	}
	before := fileSizeT(t, dbPath)

	migrated, reclaimed, err := EnsureIncrementalAutoVacuum(ctx, legacy)
	if err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if !migrated {
		t.Fatal("legacy NONE DB should have been migrated")
	}
	after := fileSizeT(t, dbPath)
	if after >= before {
		t.Fatalf("migration VACUUM did not reclaim: before=%d after=%d", before, after)
	}
	if reclaimed <= 0 {
		t.Fatalf("migration reclaimed %d bytes, want > 0", reclaimed)
	}
	if mode, _ := pragmaInt(ctx, legacy, "auto_vacuum"); mode != autoVacuumIncremental {
		t.Fatalf("after migration auto_vacuum = %d, want %d", mode, autoVacuumIncremental)
	}
	if got := countRows(t, legacy); got != want {
		t.Fatalf("rows after migration = %d, want %d", got, want)
	}
	// Idempotent: a second call is a no-op (mode already INCREMENTAL). 幂等：第二次 no-op。
	if m2, _, err := EnsureIncrementalAutoVacuum(ctx, legacy); err != nil || m2 {
		t.Fatalf("second EnsureIncrementalAutoVacuum: migrated=%v err=%v (want false, nil)", m2, err)
	}
	_ = legacy.Close()

	// Mode persists in the file header: reopen with the SAME legacy DSN (no auto_vacuum) and it reads
	// INCREMENTAL — so subsequent boots skip the migration.
	// 模式持久在文件头：用**同一** legacy DSN（无 auto_vacuum）重开，读作 INCREMENTAL——故后续 boot 跳过迁移。
	raw2, err := sql.Open("sqlite", legacyDSN)
	if err != nil {
		t.Fatal(err)
	}
	raw2.SetMaxOpenConns(1)
	reopened := ormpkg.Open(raw2)
	t.Cleanup(func() { _ = reopened.Close() })
	if mode, _ := pragmaInt(ctx, reopened, "auto_vacuum"); mode != autoVacuumIncremental {
		t.Fatalf("reopened DB auto_vacuum = %d, want %d (must persist in header)", mode, autoVacuumIncremental)
	}
}
