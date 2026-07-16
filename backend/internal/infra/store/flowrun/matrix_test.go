// matrix_test.go pins RunMatrix (scheduler 工单⑩): columns newest→oldest with the run's elapsed,
// rows as the node-id union in first-appearance order (newest run's execution order first, older
// runs' extra nodes appended), SPARSE cells, the loop-iteration aggregation (worst disposition
// wins, ties to the latest turn), the recentN window, workspace isolation, and the empty shape.
//
// matrix_test.go 钉死 RunMatrix（scheduler 工单⑩）：列新→旧带 run 耗时，行是 node id 并集按首次出现序
// （最新 run 的执行序在前、更老 run 独有的节点追加在后），格**稀疏**，loop 迭代聚合（最坏处置胜、同档取
// 最新轮），recentN 窗口，workspace 隔离，空形状。
package flowrun

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// seedMatrixNode inserts one flowrun_nodes row with an exact started_at (the ordering key) — raw
// INSERT because orm's ,created stamp would overwrite the history these tests depend on.
//
// seedMatrixNode 插一条带精确 started_at（排序键）的 flowrun_nodes 行——用裸 INSERT，因为 orm 的
// ,created 戳会覆盖这些测试赖以存在的历史。
func seedMatrixNode(t *testing.T, db *sql.DB, ws, rowID, flowrunID, nodeID, kind, status string, iter int, startedAt time.Time) {
	t.Helper()
	if _, err := db.Exec(
		`INSERT INTO flowrun_nodes (id, workspace_id, flowrun_id, node_id, iteration, kind, status, created_at, started_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		rowID, ws, flowrunID, nodeID, iter, kind, status, startedAt, startedAt, startedAt,
	); err != nil {
		t.Fatalf("seed matrix node %s: %v", rowID, err)
	}
}

func cellFor(m *flowrundomain.Matrix, runID, nodeID string) *flowrundomain.MatrixCell {
	for _, c := range m.Cells {
		if c.FlowRunID == runID && c.NodeID == nodeID {
			return c
		}
	}
	return nil
}

func rowIDs(m *flowrundomain.Matrix) []string {
	out := make([]string, 0, len(m.Rows))
	for _, r := range m.Rows {
		out = append(out, r.NodeID)
	}
	return out
}

// The core shape: two runs of the same workflow, columns newest→oldest, rows in the newest run's
// execution order, cells sparse.
// 核心形状：同一 workflow 的两个 run，列新→旧，行按最新 run 的执行序，格稀疏。
func TestRunMatrix_ColsRowsCellsShape(t *testing.T) {
	store, db := newStatsStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)

	older := base
	olderDone := older.Add(2 * time.Second)
	seedStatsRun(t, db, "ws_1", "fr_old", "wf_1", flowrundomain.StatusCompleted, older, &olderDone)
	seedMatrixNode(t, db, "ws_1", "frn_o1", "fr_old", "seed", "trigger", flowrundomain.NodeCompleted, 0, older)
	seedMatrixNode(t, db, "ws_1", "frn_o2", "fr_old", "fetch", "action", flowrundomain.NodeCompleted, 0, older.Add(time.Second))
	// Only the older run has this node (later removed from the graph) — it must land BELOW the
	// newest run's rows, never interleaved.
	// 只有更老的 run 有这个节点（后来从图里删了）——它必须落在最新 run 各行**之下**、绝不交错。
	seedMatrixNode(t, db, "ws_1", "frn_o3", "fr_old", "legacy", "action", flowrundomain.NodeCompleted, 0, older.Add(2*time.Second))

	newer := base.Add(time.Hour)
	newerDone := newer.Add(5 * time.Second)
	seedStatsRun(t, db, "ws_1", "fr_new", "wf_1", flowrundomain.StatusFailed, newer, &newerDone)
	seedMatrixNode(t, db, "ws_1", "frn_n1", "fr_new", "seed", "trigger", flowrundomain.NodeCompleted, 0, newer)
	seedMatrixNode(t, db, "ws_1", "frn_n2", "fr_new", "fetch", "action", flowrundomain.NodeCompleted, 0, newer.Add(time.Second))
	seedMatrixNode(t, db, "ws_1", "frn_n3", "fr_new", "save", "action", flowrundomain.NodeFailed, 0, newer.Add(2*time.Second))

	m, err := store.RunMatrix(ctx, flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 20})
	if err != nil {
		t.Fatalf("RunMatrix: %v", err)
	}

	// Columns newest→oldest, with the run's own elapsed.
	if len(m.Cols) != 2 || m.Cols[0].FlowRunID != "fr_new" || m.Cols[1].FlowRunID != "fr_old" {
		t.Fatalf("cols must be newest→oldest, got %+v", m.Cols)
	}
	if m.Cols[0].Status != flowrundomain.StatusFailed {
		t.Errorf("col status: got %q want failed", m.Cols[0].Status)
	}
	if m.Cols[0].ElapsedMs == nil || *m.Cols[0].ElapsedMs != 5000 {
		t.Errorf("col elapsedMs: got %v want 5000", m.Cols[0].ElapsedMs)
	}

	// Rows: the newest run's execution order first, then the older run's extra node.
	want := []string{"seed", "fetch", "save", "legacy"}
	got := rowIDs(m)
	if len(got) != len(want) {
		t.Fatalf("rows: got %v want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("rows: got %v want %v", got, want)
		}
	}
	if m.Rows[0].Kind != "trigger" || m.Rows[2].Kind != "action" {
		t.Errorf("row kinds: got %+v", m.Rows)
	}

	// Cells are SPARSE: the newest run never reached `legacy`, the older never reached `save`.
	// 格**稀疏**：最新 run 从未到达 `legacy`，更老的从未到达 `save`。
	if c := cellFor(m, "fr_new", "legacy"); c != nil {
		t.Errorf("sparse violated: fr_new/legacy has a cell %+v", c)
	}
	if c := cellFor(m, "fr_old", "save"); c != nil {
		t.Errorf("sparse violated: fr_old/save has a cell %+v", c)
	}
	if len(m.Cells) != 6 {
		t.Errorf("cells: got %d want 6 (3 per run)", len(m.Cells))
	}
	c := cellFor(m, "fr_new", "save")
	if c == nil || c.Status != flowrundomain.NodeFailed || c.Iterations != 1 || c.Iteration != 0 {
		t.Errorf("fr_new/save cell: got %+v", c)
	}
}

// A loop node's iterations collapse into ONE cell showing the WORST disposition — a later green
// turn must not erase turn 1's failure (the run header is failed too; the cell agrees with it).
//
// loop 节点的各迭代坍缩成**一**格、显示**最坏**处置——后来的绿轮不能抹掉第 1 轮的失败（run 头也是 failed；
// 格与它一致）。
func TestRunMatrix_IterationsAggregateWorstWins(t *testing.T) {
	store, db := newStatsStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)
	done := base.Add(9 * time.Second)
	seedStatsRun(t, db, "ws_1", "fr_loop", "wf_1", flowrundomain.StatusFailed, base, &done)

	seedMatrixNode(t, db, "ws_1", "frn_l0", "fr_loop", "step", "action", flowrundomain.NodeCompleted, 0, base)
	seedMatrixNode(t, db, "ws_1", "frn_l1", "fr_loop", "step", "action", flowrundomain.NodeFailed, 1, base.Add(time.Second))
	seedMatrixNode(t, db, "ws_1", "frn_l2", "fr_loop", "step", "action", flowrundomain.NodeCompleted, 2, base.Add(2*time.Second))

	m, err := store.RunMatrix(ctx, flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 20})
	if err != nil {
		t.Fatalf("RunMatrix: %v", err)
	}
	if len(m.Rows) != 1 || len(m.Cells) != 1 {
		t.Fatalf("a loop node is ONE row and ONE cell, got rows=%d cells=%d", len(m.Rows), len(m.Cells))
	}
	c := m.Cells[0]
	if c.Status != flowrundomain.NodeFailed {
		t.Errorf("worst disposition must win: got %q want failed", c.Status)
	}
	if c.Iteration != 1 {
		t.Errorf("cell must point at the WINNING turn: got iteration=%d want 1", c.Iteration)
	}
	if c.Iterations != 3 {
		t.Errorf("iterations: got %d want 3", c.Iterations)
	}
}

// parked outranks completed (the amber "awaiting a human" cell must survive earlier green turns),
// and a same-rank tie goes to the LATEST turn.
// parked 压过 completed（琥珀「等人」格必须在更早的绿轮之上存活），同档相持取**最新**轮。
func TestRunMatrix_ParkedOutranksCompletedAndTieTakesLatest(t *testing.T) {
	store, db := newStatsStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)
	seedStatsRun(t, db, "ws_1", "fr_p", "wf_1", flowrundomain.StatusRunning, base, nil)
	seedMatrixNode(t, db, "ws_1", "frn_p0", "fr_p", "gate", "approval", flowrundomain.NodeCompleted, 0, base)
	seedMatrixNode(t, db, "ws_1", "frn_p1", "fr_p", "gate", "approval", flowrundomain.NodeParked, 1, base.Add(time.Second))
	seedMatrixNode(t, db, "ws_1", "frn_t0", "fr_p", "tick", "action", flowrundomain.NodeCompleted, 0, base.Add(2*time.Second))
	seedMatrixNode(t, db, "ws_1", "frn_t1", "fr_p", "tick", "action", flowrundomain.NodeCompleted, 1, base.Add(3*time.Second))

	m, err := store.RunMatrix(ctx, flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 20})
	if err != nil {
		t.Fatalf("RunMatrix: %v", err)
	}
	gate := cellFor(m, "fr_p", "gate")
	if gate == nil || gate.Status != flowrundomain.NodeParked || gate.Iteration != 1 {
		t.Errorf("parked must outrank completed: got %+v", gate)
	}
	tick := cellFor(m, "fr_p", "tick")
	if tick == nil || tick.Iteration != 1 || tick.Iterations != 2 {
		t.Errorf("same-rank tie takes the latest turn: got %+v", tick)
	}
	// A still-running run has no completed_at → no elapsed, never a zero that reads as "instant".
	// 仍在跑的 run 无 completed_at → 无耗时，绝不发会被读成「瞬时」的 0。
	if m.Cols[0].ElapsedMs != nil {
		t.Errorf("a running run must omit elapsedMs, got %v", *m.Cols[0].ElapsedMs)
	}
}

// recentN windows the columns to the N most recent runs — and clamping/defaults are the app's, so
// the store honours exactly what it is handed.
// recentN 把列窗到最近 N 个 run——钳制/默认归 app，故 store 恰按交给它的数执行。
func TestRunMatrix_RecentNWindowsNewest(t *testing.T) {
	store, db := newStatsStore(t)
	ctx := ctxWS("ws_1")
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)
	for i := 0; i < 5; i++ {
		at := base.Add(time.Duration(i) * time.Hour)
		done := at.Add(time.Second)
		seedStatsRun(t, db, "ws_1", "fr_"+string(rune('a'+i)), "wf_1", flowrundomain.StatusCompleted, at, &done)
		seedMatrixNode(t, db, "ws_1", "frn_"+string(rune('a'+i)), "fr_"+string(rune('a'+i)), "only", "action", flowrundomain.NodeCompleted, 0, at)
	}
	m, err := store.RunMatrix(ctx, flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 2})
	if err != nil {
		t.Fatalf("RunMatrix: %v", err)
	}
	if len(m.Cols) != 2 || m.Cols[0].FlowRunID != "fr_e" || m.Cols[1].FlowRunID != "fr_d" {
		t.Fatalf("recentN=2 must take the 2 NEWEST, got %+v", m.Cols)
	}
	if len(m.Cells) != 2 {
		t.Errorf("cells must follow the window: got %d want 2", len(m.Cells))
	}
}

// Another workspace's runs and another workflow's runs are invisible — and an unknown workflow
// returns three EMPTY lists, never null (the client zips over them unconditionally).
// 另一个 workspace 与另一个 workflow 的 run 不可见——未知 workflow 返三个**空**列表、绝不 null。
func TestRunMatrix_IsolationAndEmptyShape(t *testing.T) {
	store, db := newStatsStore(t)
	base := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)
	done := base.Add(time.Second)
	seedStatsRun(t, db, "ws_other", "fr_other", "wf_1", flowrundomain.StatusCompleted, base, &done)
	seedMatrixNode(t, db, "ws_other", "frn_other", "fr_other", "n", "action", flowrundomain.NodeCompleted, 0, base)
	seedStatsRun(t, db, "ws_1", "fr_wf2", "wf_2", flowrundomain.StatusCompleted, base, &done)
	seedMatrixNode(t, db, "ws_1", "frn_wf2", "fr_wf2", "n", "action", flowrundomain.NodeCompleted, 0, base)

	m, err := store.RunMatrix(ctxWS("ws_1"), flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 20})
	if err != nil {
		t.Fatalf("RunMatrix: %v", err)
	}
	if len(m.Cols) != 0 || len(m.Rows) != 0 || len(m.Cells) != 0 {
		t.Fatalf("another workspace's run leaked / unknown workflow not empty: %+v", m)
	}
	if m.Cols == nil || m.Rows == nil || m.Cells == nil {
		t.Fatal("empty matrix must be empty LISTS, never null")
	}
}

// A bare ctx (no workspace) must be rejected, not silently answered across workspaces (D2).
// 裸 ctx（无 workspace）必须被拒、而非静默跨 workspace 作答（D2）。
func TestRunMatrix_BareCtxRejected(t *testing.T) {
	store, _ := newStatsStore(t)
	if _, err := store.RunMatrix(context.Background(), flowrundomain.MatrixQuery{WorkflowID: "wf_1", RecentN: 20}); err == nil {
		t.Fatal("a bare ctx must be rejected (D2 workspace isolation)")
	}
}
