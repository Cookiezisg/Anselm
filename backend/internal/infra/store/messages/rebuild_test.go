package messages

// rebuild_test.go pins the REAL message_blocks rebuild (WRK-077 WD1, block `type` six → seven) — a
// DROP TABLE that will run against a real user's whole conversation history, once, on the first boot
// after they upgrade. Modelled 1:1 on trigger/rebuild_test.go, and for the same reason: the rebuild's
// CREATE is a hand-copy of the one in messages.go, so a column added to Schema and forgotten there
// would not fail a build or a review — it would silently delete that column's data from an installed
// database.
//
// The gate is therefore EQUIVALENCE, not example: whatever shape a fresh install gets from Schema, an
// upgrading install must get from the rebuild — same columns, types, nullability, defaults, indexes.
// The "old install" fixture is DERIVED from the live DDL rather than hand-copied, so it cannot drift
// into agreeing with a rebuild that has already gone wrong.
//
// One thing this table has that trigger_firings did not: `messages` carries an ALTER-added column
// (superseded_by, CH-c) while message_blocks does not, so the rebuild's inline CREATE is the whole
// current shape. The equivalence check is what proves that claim rather than trusting it.
//
// rebuild_test.go 钉住**真实**的 message_blocks 重建（WRK-077 WD1，块 `type` 六 → 七）——一条会打在真实
// 用户**整份对话历史**上的 DROP TABLE，就在他们升级后的首次启动、只此一次。1:1 照 trigger/rebuild_test.go
// 写，理由相同：重建里的 CREATE 是 messages.go 那条的手抄本，故往 Schema 加一列却忘了那边，不会挂编译也
// 不会挂 review——它会从一个已安装的数据库里静默删掉那一列的数据。
//
// 故门禁是**等价性**、不是举例：全新安装从 Schema 拿到什么形状，升级中的安装就必须从重建拿到什么形状——
// 同样的列、类型、可空性、默认值、索引。「老安装」夹具是从**现行** DDL 派生的、不是手抄的，故它无法漂移到
// 与一个已经错了的重建互相同意。
//
// 本表比 trigger_firings 多一处需留意：`messages` 有一列是 ALTER 加的（superseded_by，CH-c）而
// message_blocks 没有，故重建的内联 CREATE 就是整个现行形状。等价性检查正是用来**证明**这个说法、而不是
// 相信它。

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

func openRawDB(t *testing.T) *ormpkg.DB {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	return ormpkg.Open(sqlDB)
}

// preMarkerSchema derives the pre-WD1 DDL from the LIVE Schema by removing the one word the rebuild
// exists to add. Deriving, not hand-copying — a second historical DDL pasted here is exactly the drift
// this file forbids.
//
// preMarkerSchema 从**现行** Schema 派生出 WD1 之前的 DDL——只把重建为之存在的那一个词拿掉。是**派生**、
// 不是手抄——往这里粘第二份历史 DDL 正是本文件要禁的那种漂移。
func preMarkerSchema(t *testing.T) []string {
	t.Helper()
	out := make([]string, 0, len(Schema))
	found := false
	for _, stmt := range Schema {
		if strings.Contains(stmt, "CREATE TABLE IF NOT EXISTS message_blocks") {
			old := strings.Replace(stmt, ",'marker'", "", 1)
			if old == stmt {
				t.Fatalf("the block type CHECK no longer contains %s — this fixture derives the old shape by removing it", BlocksMarkerMarker)
			}
			stmt, found = old, true
		}
		out = append(out, stmt)
	}
	if !found {
		t.Fatal("no message_blocks CREATE in Schema")
	}
	return out
}

// blockTableShape reads a table's live physical shape (columns + index DDL). PRAGMA rather than the
// stored DDL text: the rebuild renames a table into place, so the two texts are never identical even
// when the tables are physically the same.
//
// blockTableShape 读一张表的现行物理形状（列 + 索引 DDL）。用 PRAGMA 而非落库 DDL 文本：重建是把表改名
// 就位的，故两段文本即便表物理相同也永不相同。
func blockTableShape(t *testing.T, db *ormpkg.DB, table string) (string, []string) {
	t.Helper()
	ctx := context.Background()
	rows, err := db.Query(ctx, fmt.Sprintf("PRAGMA table_info(%s)", table))
	if err != nil {
		t.Fatalf("table_info(%s): %v", table, err)
	}
	defer func() { _ = rows.Close() }()
	var cols []string
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dflt sql.NullString
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			t.Fatalf("scan table_info: %v", err)
		}
		cols = append(cols, fmt.Sprintf("%s %s notnull=%d default=%q pk=%d", name, ctype, notnull, dflt.String, pk))
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("table_info rows: %v", err)
	}

	idxRows, err := db.Query(ctx,
		`SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = ? AND sql IS NOT NULL ORDER BY name`, table)
	if err != nil {
		t.Fatalf("index list(%s): %v", table, err)
	}
	defer func() { _ = idxRows.Close() }()
	var idx []string
	for idxRows.Next() {
		var name, ddl string
		if err := idxRows.Scan(&name, &ddl); err != nil {
			t.Fatalf("scan index: %v", err)
		}
		ddl = strings.ReplaceAll(ddl, "IF NOT EXISTS ", "")
		idx = append(idx, name+": "+strings.Join(strings.Fields(ddl), " "))
	}
	if err := idxRows.Err(); err != nil {
		t.Fatalf("index rows: %v", err)
	}
	return strings.Join(cols, "\n"), idx
}

const seedBlock = `INSERT INTO message_blocks
	(id, workspace_id, conversation_id, message_id, parent_block_id, seq, type, attrs, content, status, error, context_role, created_at, updated_at)
	VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`

// TestBlocksRebuild_UpgradesAnOldInstallToTheFreshShape: the real thing, end to end. An install
// predating WD1 (CHECK without 'marker') holding real block rows is migrated exactly the way bootstrap
// migrates it — Migrate, then MigrateRebuild — and must come out with the shape a fresh install gets,
// every row intact, `marker` insertable, and the seq UNIQUE back in place.
//
// TestBlocksRebuild_UpgradesAnOldInstallToTheFreshShape：真东西、端到端。一个早于 WD1（CHECK 无 'marker'）
// 且有真 block 行的安装，照 bootstrap 的方式迁移——先 Migrate、再 MigrateRebuild——必须得到与全新安装相同的
// 形状、每一行都在、`marker` 可插入、且 seq UNIQUE 回到位。
func TestBlocksRebuild_UpgradesAnOldInstallToTheFreshShape(t *testing.T) {
	ctx := context.Background()

	// A fresh install: the reference shape, straight from Schema. 全新安装：参照形状，直接来自 Schema。
	fresh := openRawDB(t)
	if err := dbinfra.Migrate(fresh, Schema...); err != nil {
		t.Fatalf("migrate fresh: %v", err)
	}
	if err := dbinfra.MigrateRebuild(fresh, "message_blocks", BlocksMarkerMarker, BlocksCheckRebuild...); err != nil {
		t.Fatalf("a fresh install must never rebuild: %v", err)
	}
	wantCols, wantIdx := blockTableShape(t, fresh, "message_blocks")

	// An install predating the change, holding real rows. 早于该变更的安装，且有真行。
	old := openRawDB(t)
	if err := dbinfra.Migrate(old, preMarkerSchema(t)...); err != nil {
		t.Fatalf("migrate old shape: %v", err)
	}
	if _, err := old.Exec(ctx, seedBlock,
		"blk_1", "ws_1", "cv_1", "msg_1", "", 1, "text", `{"pinned":true}`, "hello world", "completed", "", "warm",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	// The old CHECK really rejects the new word — the condition the rebuild exists to fix.
	// 旧 CHECK 真的拒新词——这正是重建要修的条件。
	if _, err := old.Exec(ctx, seedBlock,
		"blk_2", "ws_1", "cv_1", "msg_2", "", 2, "marker", `{"kind":"workdir"}`, "", "completed", "", "hot",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("precondition: the pre-WD1 CHECK must reject 'marker'")
	}

	// Migrate the way bootstrap's openDB does: Migrate first (the table must exist), then the rebuild.
	// 照 bootstrap 的 openDB 那样迁移：先 Migrate（表须存在）、再重建。
	if err := dbinfra.Migrate(old, Schema...); err != nil {
		t.Fatalf("migrate current shape over the old install: %v", err)
	}
	if err := dbinfra.MigrateRebuild(old, "message_blocks", BlocksMarkerMarker, BlocksCheckRebuild...); err != nil {
		t.Fatalf("rebuild: %v", err)
	}

	// THE GATE: an upgraded install and a fresh install are physically the same table. A column added to
	// Schema's CREATE without the rebuild learning about it fails right here — rather than silently
	// dropping that column from a real user's message history.
	// **门禁**：升级后的安装与全新安装是物理上同一张表。往 Schema 的 CREATE 加一列而重建不知情，就会在这里
	// 挂掉——而不是从真实用户的消息历史里静默删掉那一列。
	gotCols, gotIdx := blockTableShape(t, old, "message_blocks")
	if gotCols != wantCols {
		t.Fatalf("the rebuilt table must be shaped exactly like a fresh install's.\nrebuilt:\n%s\n\nfresh:\n%s", gotCols, wantCols)
	}
	if len(gotIdx) != len(wantIdx) {
		t.Fatalf("index sets differ: rebuilt %v, fresh %v", gotIdx, wantIdx)
	}
	for i := range gotIdx {
		if gotIdx[i] != wantIdx[i] {
			t.Fatalf("index %d differs:\nrebuilt: %s\nfresh:   %s", i, gotIdx[i], wantIdx[i])
		}
	}

	// The data survived the copy verbatim, column for column. This table holds the user's words — a
	// scrambled copy here is not a bug, it is data loss.
	// 数据逐列原样幸存于拷贝。这张表装的是用户说过的话——此处拷错不是 bug，是数据丢失。
	var wsID, convID, msgID, parent, typ, attrs, content, status, errCol, role string
	var seq int64
	if err := old.QueryRow(ctx,
		`SELECT workspace_id, conversation_id, message_id, parent_block_id, seq, type, attrs, content, status, error, context_role
		   FROM message_blocks WHERE id = 'blk_1'`).
		Scan(&wsID, &convID, &msgID, &parent, &seq, &typ, &attrs, &content, &status, &errCol, &role); err != nil {
		t.Fatalf("the rebuilt table lost the seeded row: %v", err)
	}
	if wsID != "ws_1" || convID != "cv_1" || msgID != "msg_1" || parent != "" || seq != 1 ||
		typ != "text" || attrs != `{"pinned":true}` || content != "hello world" || status != "completed" ||
		errCol != "" || role != "warm" {
		t.Fatalf("the copy scrambled a row: ws=%q conv=%q msg=%q parent=%q seq=%d type=%q attrs=%q content=%q status=%q err=%q role=%q",
			wsID, convID, msgID, parent, seq, typ, attrs, content, status, errCol, role)
	}

	// The widened CHECK accepts the seventh word — the whole point (WD1).
	// 加宽后的 CHECK 接受第七个词——这就是全部目的（WD1）。
	if _, err := old.Exec(ctx, seedBlock,
		"blk_2", "ws_1", "cv_1", "msg_2", "", 2, "marker", `{"kind":"workdir","from":"","to":"/proj"}`, "", "completed", "", "hot",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err != nil {
		t.Fatalf("after the rebuild 'marker' must insert: %v", err)
	}
	// ...and still rejects a type outside the set. The CHECK is a closed vocabulary; widening it by one
	// word must not have turned it into a free-text column.
	// ……且仍拒集合外的 type。CHECK 是封闭词汇；加宽一个词绝不能把它变成自由文本列。
	if _, err := old.Exec(ctx, seedBlock,
		"blk_3", "ws_1", "cv_1", "msg_3", "", 3, "bogus", "null", "", "completed", "", "hot",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("the rebuilt CHECK must still reject a type outside the seven")
	}
	// The context_role CHECK came back too (the compaction projection depends on it).
	// context_role 的 CHECK 也回来了（压缩投影依赖它）。
	if _, err := old.Exec(ctx, seedBlock,
		"blk_4", "ws_1", "cv_1", "msg_4", "", 4, "text", "null", "", "completed", "", "lukewarm",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("the rebuilt CHECK must still reject a context_role outside hot/warm/cold/archived")
	}
	// idx_blocks_conv_seq (the seq monotonicity UNIQUE) came back with the table — it dies with the DROP,
	// and the whole ordering contract of a thread rests on it.
	// idx_blocks_conv_seq（seq 单调的 UNIQUE）随表回来了——它随 DROP 而死，而一条线程的全部排序契约压在它身上。
	if _, err := old.Exec(ctx, seedBlock,
		"blk_5", "ws_1", "cv_1", "msg_5", "", 2, "text", "null", "dup seq", "completed", "", "hot",
		"2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("idx_blocks_conv_seq must be recreated by the rebuild — without it a thread's order is not unique")
	}

	// Idempotent by outcome: the next boot reads the marker word and does nothing.
	// 结果幂等：下次启动读到标记词、什么都不做。
	if err := dbinfra.MigrateRebuild(old, "message_blocks", BlocksMarkerMarker, BlocksCheckRebuild...); err != nil {
		t.Fatalf("a second rebuild must be a no-op, got: %v", err)
	}
	var n int
	if err := old.QueryRow(ctx, `SELECT COUNT(*) FROM message_blocks`).Scan(&n); err != nil || n != 2 {
		t.Fatalf("a no-op rebuild must not touch data: n=%d err=%v", n, err)
	}
}
