package storage

import (
	"context"
	"testing"

	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	attachmentstore "github.com/sunweilin/anselm/backend/internal/infra/store/attachment"
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

	// The panel reports TWO stores side by side (WRK-082 H5.9): the .db file and the attachment
	// blobs, which live outside it. Stat refuses to guess when the attachments table is missing
	// rather than reporting a comforting 0 — a silent 0 would hide the exact breakage this number
	// exists to make visible — so the table has to be here.
	// 面板并排报**两个**存储(H5.9):.db 文件,以及活在它**之外**的附件 blob。表缺席时 Stat 宁可报错也
	// 不返回一个让人安心的 0——静默的 0 恰好会藏住这个数字存在的理由所指的那种故障——故这里必须建表。
	for _, stmt := range attachmentstore.Schema {
		if _, err := db.Exec(ctx, stmt); err != nil {
			t.Fatal(err)
		}
	}

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

// TestStat_CountsAttachmentBytesOutsideTheDatabase pins the number the storage panel was missing.
//
// Blobs are content-addressed FILES under workspaces/<ws>/blobs — they are not in the .db at all.
// Reporting only dbBytes was already understating disk by more than half on a lightly-used dev
// install (6.8MB of blobs against a 4.9MB database), and generated video makes the gap unbounded:
// a 3MB clip moves dbBytes by a few hundred bytes of metadata.
//
// The sum is deliberately ACROSS workspaces, because dbBytes already is — one panel, one scope.
//
// TestStat_CountsAttachmentBytesOutsideTheDatabase 钉住存储面板此前缺的那个数字。
//
// blob 是 workspaces/<ws>/blobs 下按内容寻址的**文件**——它们**根本不在** .db 里。只报 dbBytes 在一台轻度
// 使用的开发机上就已经把磁盘少报了一半以上(blobs 6.8MB vs 数据库 4.9MB),而生成视频让这个差距无界:
// 一段 3MB 的片子只让 dbBytes 动几百字节的元数据。
//
// 求和**刻意跨 workspace**,因为 dbBytes 本来就是——一个面板,一种口径。
func TestStat_CountsAttachmentBytesOutsideTheDatabase(t *testing.T) {
	db, err := dbinfra.Open(dbinfra.Config{DataDir: t.TempDir()})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = db.Close() })
	ctx := context.Background()
	for _, stmt := range attachmentstore.Schema {
		if _, err := db.Exec(ctx, stmt); err != nil {
			t.Fatal(err)
		}
	}
	ins := `INSERT INTO attachments (id, workspace_id, sha256, filename, mime_type, size_bytes, kind, created_at, deleted_at)
	        VALUES (?, ?, 'sha', 'f', 'video/mp4', ?, 'video', datetime('now'), ?)`
	// Two live rows in DIFFERENT workspaces + one soft-deleted: the panel is machine-level, so both
	// live rows count, and the deleted one is reported as reclaimable rather than as gone.
	// 两条活行分属**不同** workspace + 一条软删:面板是机器级的,故两条活行都算,而软删那条报成**可回收**、
	// 不是报成不存在。
	if _, err := db.Exec(ctx, ins, "att_1", "ws_a", 1000, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, ins, "att_2", "ws_b", 2000, nil); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, ins, "att_3", "ws_a", 500, "2026-01-01 00:00:00"); err != nil {
		t.Fatal(err)
	}

	stat, err := New(db).Stat(ctx)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if stat.AttachmentBytes != 3000 {
		t.Fatalf("attachmentBytes = %d, want 3000 (both workspaces' live rows)", stat.AttachmentBytes)
	}
	if stat.AttachmentDeadBytes != 500 {
		t.Fatalf("attachmentDeadBytes = %d, want 500 (the soft-deleted row the GC can reclaim)", stat.AttachmentDeadBytes)
	}
}
