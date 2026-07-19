package trigger

// rebuild_test.go pins the REAL trigger_firings rebuild (scheduler 工单⑨) — the one DROP TABLE this
// codebase will ever run against a real user's data, on the first boot after they upgrade.
//
// db/rebuild_test.go pins MigrateRebuild the MECHANISM, over a synthetic `widgets` table. That
// leaves the thing that actually ships — these DDL statements, on this table — with no test at all,
// and the statements are a hand-copy of the CREATE in trigger.go: two sources of truth for one
// table's shape, with nothing to notice when they drift. A column added to Schema and forgotten here
// would not fail a build or a review; it would drop it, from an installed database, once, silently.
//
// So the gate is EQUIVALENCE, not example: whatever a fresh install gets from Schema, an upgrading
// install must get from the rebuild — same columns, same types, same nullability, same defaults,
// same indexes. And the "old install" fixture is DERIVED from the live DDL rather than hand-copied,
// so it cannot drift into agreeing with a rebuild that has already gone wrong.
//
// rebuild_test.go 钉住**真实**的 trigger_firings 重建（scheduler 工单⑨）——本代码库唯一一条会打在真实用户
// 数据上的 DROP TABLE，就在他们升级后的首次启动。
//
// db/rebuild_test.go 钉的是 MigrateRebuild 这个**机制**，跑在合成的 `widgets` 表上。那让**真正要发布的东西**
// ——这些 DDL 语句、这张表——完全没有测试，而这些语句是 trigger.go 里那条 CREATE 的手抄本：一张表的形状有
// 两个事实源，且没有任何东西会在它们漂移时出声。往 Schema 加一列却忘了这边，不会挂编译也不会挂 review；
// 它会把那一列从一个已安装的数据库里删掉，一次，悄无声息。
//
// 故门禁是**等价性**、不是举例：全新安装从 Schema 拿到什么形状，升级中的安装就必须从重建拿到什么形状——
// 同样的列、类型、可空性、默认值、索引。而「老安装」的夹具是从**现行** DDL 派生的、不是手抄的，故它无法
// 漂移到与一个已经错了的重建互相同意。

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

// openRaw opens an empty in-memory database.
func openRaw(t *testing.T) *ormpkg.DB {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	return ormpkg.Open(sqlDB)
}

// preMissedSchema derives the pre-工单⑨ DDL from the LIVE Schema by removing the one word the
// rebuild exists to add. Deriving, not hand-copying: a second historical DDL pasted in here is
// exactly the drift this file is written to forbid, and it would happily keep passing after the real
// table grew a column neither copy knew about.
//
// preMissedSchema 从**现行** Schema 派生出工单⑨之前的 DDL——只把重建为之存在的那一个词拿掉。是**派生**、
// 不是手抄：往这里粘第二份历史 DDL 正是本文件要禁的那种漂移，而且在真实表长出两份拷贝都不知道的列之后，
// 它还会一路欢快地通过。
func preMissedSchema(t *testing.T) []string {
	t.Helper()
	out := make([]string, 0, len(Schema))
	found := false
	for _, stmt := range Schema {
		if strings.Contains(stmt, "CREATE TABLE IF NOT EXISTS trigger_firings") {
			old := strings.Replace(stmt, ",'missed'", "", 1)
			if old == stmt {
				t.Fatalf("the firings CHECK no longer contains %s — this fixture derives the old shape by removing it", FiringsMissedMarker)
			}
			stmt, found = old, true
		}
		out = append(out, stmt)
	}
	if !found {
		t.Fatal("no trigger_firings CREATE in Schema")
	}
	return out
}

// tableShape reads the live physical shape of a table: its columns (name/type/notnull/default/pk)
// and its index names. PRAGMA rather than the stored DDL text — the rebuild renames a table into
// place, so the two shapes are never textually identical even when they are physically the same.
//
// tableShape 读一张表的**现行物理形状**：列（名/类型/非空/默认值/主键）与索引名。用 PRAGMA 而非落库的 DDL
// 文本——重建是把表改名就位的，故两者即便物理相同、文本也永不相同。
func tableShape(t *testing.T, db *ormpkg.DB, table string) (string, []string) {
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
		// Normalise the table name away: the rebuild's index DDL names the same table, but whitespace
		// and the CREATE ... IF NOT EXISTS spelling differ between Schema and the rebuild statements.
		ddl = strings.ReplaceAll(ddl, "IF NOT EXISTS ", "")
		idx = append(idx, name+": "+strings.Join(strings.Fields(ddl), " "))
	}
	if err := idxRows.Err(); err != nil {
		t.Fatalf("index rows: %v", err)
	}
	return strings.Join(cols, "\n"), idx
}

// TestFiringsRebuild_UpgradesAnOldInstallToTheFreshShape: the real thing, end to end. An install
// predating 工单⑨ (CHECK without 'missed') holding real firing rows is migrated exactly the way
// bootstrap migrates it — Migrate, then MigrateRebuild — and must come out with the shape a fresh
// install gets, its data intact, and `missed` insertable.
func TestFiringsRebuild_UpgradesAnOldInstallToTheFreshShape(t *testing.T) {
	ctx := context.Background()

	// A fresh install: the reference shape, straight from Schema. 全新安装：参照形状，直接来自 Schema。
	fresh := openRaw(t)
	if err := dbinfra.Migrate(fresh, Schema...); err != nil {
		t.Fatalf("migrate fresh: %v", err)
	}
	if err := dbinfra.MigrateRebuild(fresh, "trigger_firings", FiringsMissedMarker, FiringsCheckRebuild...); err != nil {
		t.Fatalf("a fresh install must never rebuild: %v", err)
	}
	wantCols, wantIdx := tableShape(t, fresh, "trigger_firings")

	// An install predating the change, holding real rows. 早于该变更的安装，且有真行。
	old := openRaw(t)
	if err := dbinfra.Migrate(old, preMissedSchema(t)...); err != nil {
		t.Fatalf("migrate old shape: %v", err)
	}
	seed := `INSERT INTO trigger_firings
		(id, workspace_id, trigger_id, workflow_id, activation_id, payload, dedup_key, status, flowrun_id, created_at, updated_at)
		VALUES (?,?,?,?,?,?,?,?,?,?,?)`
	if _, err := old.Exec(ctx, seed, "trf_1", "ws_1", "trg_1", "wf_1", "tra_1", `{"firedAt":"x"}`, "trg_1|cron|60", "started", "fr_1", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err != nil {
		t.Fatalf("seed: %v", err)
	}
	// The old CHECK really rejects the new word — the condition the rebuild exists to fix.
	// 旧 CHECK 真的拒新词——这正是重建要修的条件。
	if _, err := old.Exec(ctx, seed, "trf_2", "ws_1", "trg_1", "wf_1", "", "{}", "k2", "missed", "", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("precondition: the pre-工单⑨ CHECK must reject 'missed'")
	}

	// Migrate the way bootstrap's openDB does: Migrate first (the table must exist), then the rebuild.
	// 照 bootstrap 的 openDB 那样迁移：先 Migrate（表须存在）、再重建。
	if err := dbinfra.Migrate(old, Schema...); err != nil {
		t.Fatalf("migrate current shape over the old install: %v", err)
	}
	if err := dbinfra.MigrateRebuild(old, "trigger_firings", FiringsMissedMarker, FiringsCheckRebuild...); err != nil {
		t.Fatalf("rebuild: %v", err)
	}

	// THE GATE: an upgraded install and a fresh install are physically the same table. A column added
	// to Schema's CREATE (or an ALTER) without the rebuild learning about it fails right here — rather
	// than silently dropping that column from a real database.
	// **门禁**：升级后的安装与全新安装是物理上同一张表。往 Schema 的 CREATE 加一列（或加个 ALTER）而重建
	// 不知情，就会在这里挂掉——而不是从一个真实数据库里静默删掉那一列。
	gotCols, gotIdx := tableShape(t, old, "trigger_firings")
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

	// The data survived the copy verbatim, column for column.
	// 数据逐列原样幸存于拷贝。
	var wsID, trgID, wfID, actID, payload, dedup, status, frID string
	if err := old.QueryRow(ctx,
		`SELECT workspace_id, trigger_id, workflow_id, activation_id, payload, dedup_key, status, flowrun_id
		   FROM trigger_firings WHERE id = 'trf_1'`).
		Scan(&wsID, &trgID, &wfID, &actID, &payload, &dedup, &status, &frID); err != nil {
		t.Fatalf("the rebuilt table lost the seeded row: %v", err)
	}
	if wsID != "ws_1" || trgID != "trg_1" || wfID != "wf_1" || actID != "tra_1" ||
		payload != `{"firedAt":"x"}` || dedup != "trg_1|cron|60" || status != "started" || frID != "fr_1" {
		t.Fatalf("the copy scrambled a row: ws=%q trg=%q wf=%q act=%q payload=%q dedup=%q status=%q flowrun=%q",
			wsID, trgID, wfID, actID, payload, dedup, status, frID)
	}

	// The widened CHECK accepts the new word — the whole point (工单⑨).
	// 加宽后的 CHECK 接受新词——这就是全部目的（工单⑨）。
	if _, err := old.Exec(ctx, seed, "trf_2", "ws_1", "trg_1", "wf_2", "", "{}", "k2", "missed", "", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err != nil {
		t.Fatalf("after the rebuild 'missed' must insert: %v", err)
	}
	// ...and still rejects a status outside the enum. ……且仍拒枚举外的 status。
	if _, err := old.Exec(ctx, seed, "trf_3", "ws_1", "trg_1", "wf_3", "", "{}", "k3", "bogus", "", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("the rebuilt CHECK must still reject a status outside the enum")
	}
	// The dedup UNIQUE (D3) came back with the table — it dies with the DROP, and idempotence of the
	// whole missed-accounting story rests on it. dedup UNIQUE（D3）随表回来了——它随 DROP 而死，而整个
	// missed 记账的幂等性都压在它身上。
	if _, err := old.Exec(ctx, seed, "trf_4", "ws_1", "trg_1", "wf_2", "", "{}", "k2", "pending", "", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00Z"); err == nil {
		t.Fatal("idx_trf_dedup must be recreated by the rebuild — without it a tick can be booked twice")
	}

	// Idempotent by outcome: the next boot reads the marker and does nothing.
	// 结果幂等：下次启动读到标记词、什么都不做。
	if err := dbinfra.MigrateRebuild(old, "trigger_firings", FiringsMissedMarker, FiringsCheckRebuild...); err != nil {
		t.Fatalf("a second rebuild must be a no-op, got: %v", err)
	}
	var n int
	if err := old.QueryRow(ctx, `SELECT COUNT(*) FROM trigger_firings`).Scan(&n); err != nil || n != 2 {
		t.Fatalf("a no-op rebuild must not touch data: n=%d err=%v", n, err)
	}
}
