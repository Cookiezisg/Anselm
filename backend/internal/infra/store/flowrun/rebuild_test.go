package flowrun

import (
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	dbinfra "github.com/sunweilin/anselm/backend/internal/infra/db"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
)

// legacyNodesSchema is flowrun_nodes EXACTLY as an install predating the 'cancelled' word carries it:
// the three-value CHECK, the three indexes, and the two 工单⑫ stamps arriving via ALTER rather than
// the CREATE. Reproducing the ALTER shape is the point — the rebuild has to copy columns the original
// CREATE never mentioned, which is the one way this table's rebuild differs from trigger_firings'.
//
// legacyNodesSchema 是 flowrun_nodes 在「'cancelled' 这个词之前」的安装上**逐字**的样子：三值 CHECK、
// 三个索引，以及经 ALTER（而非 CREATE）补上的两个工单⑫ 戳。复现 ALTER 那个形状正是重点——重建必须拷贝
// 原 CREATE 从未提过的列，而这正是本表的重建与 trigger_firings 的唯一不同之处。
var legacyNodesSchema = []string{
	`CREATE TABLE flowrun_nodes (
		id            TEXT PRIMARY KEY,
		workspace_id  TEXT NOT NULL,
		flowrun_id    TEXT NOT NULL,
		node_id       TEXT NOT NULL,
		iteration     INTEGER NOT NULL DEFAULT 0,
		kind          TEXT NOT NULL,
		ref           TEXT NOT NULL DEFAULT '',
		status        TEXT NOT NULL CHECK (status IN ('completed','failed','parked')),
		result        TEXT NOT NULL DEFAULT '{}',
		error         TEXT NOT NULL DEFAULT '',
		created_at    DATETIME NOT NULL,
		completed_at  DATETIME,
		updated_at    DATETIME NOT NULL
	)`,
	`CREATE UNIQUE INDEX idx_frn_once ON flowrun_nodes(flowrun_id, node_id, iteration)`,
	`CREATE INDEX idx_frn_run ON flowrun_nodes(flowrun_id)`,
	`CREATE INDEX idx_frn_parked ON flowrun_nodes(workspace_id, status) WHERE status = 'parked'`,
	`ALTER TABLE flowrun_nodes ADD COLUMN ready_at DATETIME`,
	`ALTER TABLE flowrun_nodes ADD COLUMN started_at DATETIME`,
}

// TestNodesCheckRebuild_ExistingInstall — an install created before the word cannot accept a
// cancelled row (SQLite has no ALTER for a CHECK, and CREATE TABLE IF NOT EXISTS never touches an
// existing table, so without the rebuild the old CHECK would live forever). The sweep would then fail
// its write, get swallowed as a logged warning, and leave the dead approval in the inbox — silently,
// on exactly the machines that have history worth keeping.
//
// TestNodesCheckRebuild_ExistingInstall——在这个词之前建的安装收不下 cancelled 行（SQLite 没有对应
// CHECK 的 ALTER，而 CREATE TABLE IF NOT EXISTS 永不碰已存在的表，故没有重建的话旧 CHECK 会永远留着）。
// 于是收割会写失败、被咽成一条 warning 日志、把死掉的审批留在收件箱——静默地，且恰恰发生在那些**有历史
// 值得留**的机器上。
func TestNodesCheckRebuild_ExistingInstall(t *testing.T) {
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range legacyNodesSchema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("legacy schema: %v", err)
		}
	}
	db := ormpkg.Open(sqlDB)

	// History worth preserving, including a ⑫ stamp on the ALTER-added columns.
	at := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)
	if _, err := sqlDB.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, iteration, kind, ref, status,
			result, error, created_at, completed_at, updated_at, ready_at, started_at)
		 VALUES ('frn_old', 'ws_1', 'fr_1', 'step', 3, 'action', 'fn_1', 'completed',
			'{"k":"v"}', '', ?, ?, ?, ?, ?)`,
		at, at, at, at.Add(-time.Second), at,
	); err != nil {
		t.Fatalf("seed legacy row: %v", err)
	}

	// Precondition: the old CHECK genuinely rejects the word (otherwise this test proves nothing).
	// 前置：旧 CHECK 确实拒绝这个词（否则本测试什么都没证明）。
	if _, err := sqlDB.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, kind, status, created_at, updated_at)
		 VALUES ('frn_pre', 'ws_1', 'fr_1', 'gate', 'approval', 'cancelled', ?, ?)`, at, at,
	); err == nil {
		t.Fatal("precondition broken: the legacy CHECK already accepts 'cancelled'")
	}

	if err := dbinfra.MigrateRebuild(db, "flowrun_nodes", NodesCancelledMarker, NodesCheckRebuild...); err != nil {
		t.Fatalf("MigrateRebuild: %v", err)
	}

	// ① The word is now writable.
	s := New(db)
	wsCtx := ctxWS("ws_1")
	if _, err := s.InsertNodeResult(wsCtx, &flowrundomain.FlowRunNode{
		FlowRunID: "fr_1", NodeID: "gate", Iteration: 0, Kind: "approval",
		Status: flowrundomain.NodeCancelled, Result: map[string]any{},
	}); err != nil {
		t.Fatalf("after rebuild a cancelled row must be writable: %v", err)
	}

	// ② The history survived column-for-column — including the ALTER-added ⑫ stamps, which the
	// rebuild's CREATE must declare inline and its SELECT must name.
	// ② 历史逐列存活——含经 ALTER 补的⑫ 戳，重建的 CREATE 必须内联声明它们、SELECT 必须点名它们。
	rows, err := s.GetNodes(wsCtx, "fr_1")
	if err != nil {
		t.Fatalf("GetNodes: %v", err)
	}
	var old *flowrundomain.FlowRunNode
	for _, r := range rows {
		if r.ID == "frn_old" {
			old = r
		}
	}
	if old == nil {
		t.Fatal("the rebuild dropped the pre-existing row")
	}
	if old.Iteration != 3 || old.Kind != "action" || old.Ref != "fn_1" || old.Status != flowrundomain.NodeCompleted {
		t.Fatalf("the rebuild mangled the row: %+v", old)
	}
	if old.Result["k"] != "v" {
		t.Fatalf("the rebuild lost the memoized result: %+v", old.Result)
	}
	if old.ReadyAt == nil || old.StartedAt == nil {
		t.Fatalf("the rebuild dropped the ⑫ queue stamps: readyAt=%v startedAt=%v", old.ReadyAt, old.StartedAt)
	}

	// ③ idx_frn_once survived — it is the D3 record-once key, and it drops WITH the old table.
	// A rebuild that forgets to recreate it silently disarms record-once itself.
	// ③ idx_frn_once 存活——它是 D3 record-once 键，且随旧表一起落。重建若忘了重建它，就**静默地**把
	// record-once 本身给卸了。
	if _, err := sqlDB.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, iteration, kind, status, created_at, updated_at)
		 VALUES ('frn_dup', 'ws_1', 'fr_1', 'step', 3, 'action', 'completed', ?, ?)`, at, at,
	); err == nil {
		t.Fatal("idx_frn_once (D3 record-once) did not survive the rebuild — a duplicate (run,node,iteration) was accepted")
	}

	// ④ Idempotent BY OUTCOME: a second boot reads the marker and no-ops (it must not re-copy).
	// ④ **结果幂等**：第二次启动读到标记词即 no-op（绝不能再拷一遍）。
	if err := dbinfra.MigrateRebuild(db, "flowrun_nodes", NodesCancelledMarker, NodesCheckRebuild...); err != nil {
		t.Fatalf("second MigrateRebuild must be a no-op: %v", err)
	}
	after, _ := s.GetNodes(wsCtx, "fr_1")
	if len(after) != len(rows) {
		t.Fatalf("the second pass was not a no-op: %d rows → %d", len(rows), len(after))
	}
}

// TestNodesCheckRebuild_FreshInstall — a fresh install's CREATE already carries the word, so the
// rebuild must never fire. This is what keeps the escape hatch free: boot on a large flowrun_nodes
// does not pay a table copy it does not need.
//
// TestNodesCheckRebuild_FreshInstall——全新安装的 CREATE 已含该词，故重建绝不能触发。这正是这个逃生口
// **免费**的原因：在一张大 flowrun_nodes 上启动，不会付一次它并不需要的整表拷贝。
func TestNodesCheckRebuild_FreshInstall(t *testing.T) {
	s, sqlDB := newStatsStore(t) // built from the current Schema
	db := ormpkg.Open(sqlDB)
	at := time.Now().UTC()
	if _, err := sqlDB.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, kind, status, created_at, updated_at)
		 VALUES ('frn_fresh', 'ws_1', 'fr_1', 'step', 'action', 'completed', ?, ?)`, at, at,
	); err != nil {
		t.Fatalf("seed: %v", err)
	}
	var before string
	if err := sqlDB.QueryRow(`SELECT sql FROM sqlite_master WHERE type='table' AND name='flowrun_nodes'`).Scan(&before); err != nil {
		t.Fatalf("read ddl: %v", err)
	}
	if err := dbinfra.MigrateRebuild(db, "flowrun_nodes", NodesCancelledMarker, NodesCheckRebuild...); err != nil {
		t.Fatalf("MigrateRebuild: %v", err)
	}
	var after string
	if err := sqlDB.QueryRow(`SELECT sql FROM sqlite_master WHERE type='table' AND name='flowrun_nodes'`).Scan(&after); err != nil {
		t.Fatalf("read ddl: %v", err)
	}
	if before != after {
		t.Fatalf("a fresh install must not be rebuilt:\nbefore: %s\nafter:  %s", before, after)
	}
	if rows, _ := s.GetNodes(ctxWS("ws_1"), "fr_1"); len(rows) != 1 {
		t.Fatalf("rows = %d, want 1", len(rows))
	}
}
