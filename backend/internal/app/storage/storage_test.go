package storage

import (
	"context"
	"testing"

	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// fillAndDelete inserts n one-page rows then deletes most of them, so the freelist has real dead
// space for Stat to see and Compact to reclaim. 3 KiB payload ≈ one row per 4 KiB page.
//
// fillAndDelete 插 n 行（每行一页）再删掉大半，使 freelist 有真死空间供 Stat 看见、Compact 回收。
func fillAndDelete(t *testing.T, db *ormpkg.DB, n int) {
	t.Helper()
	ctx := context.Background()
	if _, err := db.Exec(ctx, `CREATE TABLE t (id INTEGER PRIMARY KEY, payload BLOB)`); err != nil {
		t.Fatal(err)
	}
	blob := make([]byte, 3000)
	if err := db.Transaction(ctx, func(tx *ormpkg.DB) error {
		for i := 0; i < n; i++ {
			if _, err := tx.Exec(ctx, `INSERT INTO t (id, payload) VALUES (?, ?)`, i, blob); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `DELETE FROM t WHERE id % 5 != 0`); err != nil {
		t.Fatal(err)
	}
}

// TestService_StatThenCompact verifies the app seam maps infra/db's numbers into the wire structs:
// Stat exposes non-zero size + dead space, Compact reclaims it (migrated=false on a born-INCREMENTAL
// DB), and a follow-up Stat shows the dead space gone — the exact size/reclaimable/reclaimed figures
// the storage panel reads.
//
// TestService_StatThenCompact 验证 app 缝把 infra/db 的数字映射进线缆结构：Stat 暴露非零大小 + 死空间，
// Compact 回收它（天生 INCREMENTAL 库上 migrated=false），随后 Stat 显示死空间消失——正是存储面板读的那组
// 大小/可回收/已回收数字。
func TestService_StatThenCompact(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{DataDir: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	svc := New(db)
	ctx := context.Background()

	fillAndDelete(t, db, 8000)

	stat, err := svc.Stat(ctx)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if stat.DBBytes <= 0 || stat.DeadBytes <= 0 {
		t.Fatalf("stat = %+v, want both fields > 0", stat)
	}
	if stat.DeadBytes > stat.DBBytes {
		t.Fatalf("dead %d > size %d — impossible", stat.DeadBytes, stat.DBBytes)
	}

	res, err := svc.Compact(ctx)
	if err != nil {
		t.Fatalf("compact: %v", err)
	}
	if res.ReclaimedBytes <= 0 {
		t.Fatalf("compact reclaimed %d, want > 0", res.ReclaimedBytes)
	}
	if res.Migrated {
		t.Fatal("a born-INCREMENTAL DB must report migrated=false")
	}

	after, err := svc.Stat(ctx)
	if err != nil {
		t.Fatalf("stat after compact: %v", err)
	}
	if after.DeadBytes >= stat.DeadBytes {
		t.Fatalf("dead space did not drop: before=%d after=%d", stat.DeadBytes, after.DeadBytes)
	}
}
