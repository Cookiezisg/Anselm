// retention_test.go pins PurgeTerminalRunsBefore (scheduler 工单⑬) — the SECOND D1 physical-delete
// carve-out, so these tests are the guard rail on a destructive path: the cutoff boundary
// (strictly-before, on completed_at), the terminal-only filter (running/parked survive at ANY age),
// the full cascade (header + node rows + the four audit tables' rows THAT RUN produced), the
// collateral it must NOT touch (another run's rows, a chat-triggered execution, another workspace),
// batching, and idempotence.
//
// retention_test.go 钉死 PurgeTerminalRunsBefore（scheduler 工单⑬）——**D1 的第二个**物理删例外，故这些
// 测试是一条破坏性路径上的护栏：cutoff 边界（严格早于、按 completed_at）、只终态过滤（running/parked 在
// **任何**年龄都活）、完整级联（头 + 节点行 + 四张审计表里**该 run 产生**的行）、它**绝不能**碰的旁系
// （另一个 run 的行、对话触发的执行、另一个 workspace）、分批、幂等。
package flowrun

import (
	"context"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	functiondomain "github.com/sunweilin/anselm/backend/internal/domain/function"
	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
	mcpdomain "github.com/sunweilin/anselm/backend/internal/domain/mcp"
)

func countRows(t *testing.T, h *activityHarness, table, where string, args ...any) int {
	t.Helper()
	var n int
	if err := h.raw.QueryRow(`SELECT COUNT(*) FROM `+table+` WHERE `+where, args...).Scan(&n); err != nil {
		t.Fatalf("count %s: %v", table, err)
	}
	return n
}

// seedAuditRowsFor writes ONE row per audit family attributed to (runID, nodeID) — the rows that
// run PRODUCED, which the purge must take with it.
//
// seedAuditRowsFor 逐审计族各写**一**条归属 (runID, nodeID) 的行——run **产生**的行，清理必须一并带走。
func seedAuditRowsFor(t *testing.T, h *activityHarness, ctx context.Context, suffix, runID, nodeID string, at time.Time) {
	t.Helper()
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_" + suffix, FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 1,
		StartedAt: at, EndedAt: at, FlowrunID: runID, FlowrunNodeID: nodeID,
	}); err != nil {
		t.Fatalf("seed fn exec: %v", err)
	}
	if err := h.hd.SaveCall(ctx, &handlerdomain.Call{
		ID: "hcl_" + suffix, HandlerID: "hd_1", VersionID: "hdv_1", Method: "run", Status: handlerdomain.CallStatusOK,
		TriggeredBy: handlerdomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 1,
		StartedAt: at, EndedAt: at, FlowrunID: runID, FlowrunNodeID: nodeID,
	}); err != nil {
		t.Fatalf("seed hd call: %v", err)
	}
	if err := h.ag.SaveExecution(ctx, &agentdomain.Execution{
		ID: "agx_" + suffix, AgentID: "ag_1", VersionID: "agv_1", Status: agentdomain.ExecutionStatusOK,
		TriggeredBy: agentdomain.TriggeredByWorkflow, Input: map[string]any{}, ElapsedMs: 1,
		StartedAt: at, EndedAt: at, FlowrunID: runID, FlowrunNodeID: nodeID,
	}); err != nil {
		t.Fatalf("seed ag exec: %v", err)
	}
	if err := h.mc.SaveCall(ctx, &mcpdomain.Call{
		ID: "mcl_" + suffix, ServerID: "mcp_1", Tool: "fetch", Status: mcpdomain.CallStatusOK,
		TriggeredBy: mcpdomain.CallTriggeredByWorkflow, ElapsedMs: 1,
		StartedAt: at, EndedAt: at, FlowrunID: runID, FlowrunNodeID: nodeID,
	}); err != nil {
		t.Fatalf("seed mcp call: %v", err)
	}
}

// The cascade: an over-the-line run takes its header, its node rows and all four families of the
// audit rows it produced — and leaves everything else standing.
// 级联：一个越线的 run 带走它的头、它的节点行、以及它产生的全部四族审计行——其余一切留着。
func TestPurgeTerminalRunsBefore_CascadeAndCollateral(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -90)

	// The doomed run: finished 100 days ago.
	old := now.AddDate(0, 0, -100)
	seedStatsRun(t, h.raw, "ws_1", "fr_old", "wf_1", flowrundomain.StatusCompleted, old, &old)
	seedMatrixNode(t, h.raw, "ws_1", "frn_old", "fr_old", "n_a", "action", flowrundomain.NodeCompleted, 0, old)
	seedAuditRowsFor(t, h, ctx, "old", "fr_old", "n_a", old)

	// The keeper: finished yesterday, same workflow, same node names.
	fresh := now.AddDate(0, 0, -1)
	seedStatsRun(t, h.raw, "ws_1", "fr_fresh", "wf_1", flowrundomain.StatusCompleted, fresh, &fresh)
	seedMatrixNode(t, h.raw, "ws_1", "frn_fresh", "fr_fresh", "n_a", "action", flowrundomain.NodeCompleted, 0, fresh)
	seedAuditRowsFor(t, h, ctx, "fresh", "fr_fresh", "n_a", fresh)

	// A chat-triggered execution (flowrun_id = '') is nobody's run history — it must never be swept.
	// 对话触发的执行（flowrun_id = ''）不是任何 run 的历史——绝不能被清。
	if err := h.fn.SaveExecution(ctx, &functiondomain.Execution{
		ID: "fne_chat", FunctionID: "fn_1", VersionID: "fnv_1", Status: functiondomain.ExecutionStatusOK,
		TriggeredBy: functiondomain.TriggeredByChat, Input: map[string]any{}, ElapsedMs: 1,
		StartedAt: old, EndedAt: old,
	}); err != nil {
		t.Fatalf("seed chat exec: %v", err)
	}

	n, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, flowrundomain.RetentionBatchSize)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if n != 1 {
		t.Fatalf("purged: got %d want 1", n)
	}

	if got := countRows(t, h, "flowruns", "id = 'fr_old'"); got != 0 {
		t.Errorf("header survived the line: %d rows", got)
	}
	if got := countRows(t, h, "flowrun_nodes", "flowrun_id = 'fr_old'"); got != 0 {
		t.Errorf("node rows survived (orphaned): %d rows", got)
	}
	for _, table := range auditTables {
		if got := countRows(t, h, table, "flowrun_id = 'fr_old'"); got != 0 {
			t.Errorf("%s: the purged run's audit rows survived (orphaned): %d rows", table, got)
		}
		// Collateral: the fresh run's audit rows and the chat execution are untouched.
		if got := countRows(t, h, table, "flowrun_id = 'fr_fresh'"); got != 1 {
			t.Errorf("%s: the fresh run's audit row was swept: %d rows want 1", table, got)
		}
	}
	if got := countRows(t, h, "flowruns", "id = 'fr_fresh'"); got != 1 {
		t.Errorf("the fresh run was swept: %d rows want 1", got)
	}
	if got := countRows(t, h, "flowrun_nodes", "flowrun_id = 'fr_fresh'"); got != 1 {
		t.Errorf("the fresh run's node row was swept: %d rows want 1", got)
	}
	if got := countRows(t, h, "function_executions", "id = 'fne_chat'"); got != 1 {
		t.Errorf("a chat-triggered execution (flowrun_id='') was swept: %d rows want 1", got)
	}

	// Idempotent: nothing left to take.
	again, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, flowrundomain.RetentionBatchSize)
	if err != nil || again != 0 {
		t.Fatalf("second sweep must be a no-op: purged=%d err=%v", again, err)
	}
}

// running / parked runs are NEVER purged, however old — an in-flight run is not history, and a run
// awaiting a human is a live obligation. A terminal row that cannot be dated (NULL completed_at)
// is kept too: a destructive sweep must not guess.
//
// running / parked 的 run **永不**清，不管多老——在飞的 run 不是历史，等人的 run 是活的义务。断不了年份的
// 终态行（completed_at 为 NULL）也留：破坏性清理不能靠猜。
func TestPurgeTerminalRunsBefore_NeverTouchesLiveOrUndatedRuns(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -90)
	ancient := now.AddDate(0, 0, -900)

	// Running for 900 days (a wedged run) — and one parked on an approval nobody answered.
	seedStatsRun(t, h.raw, "ws_1", "fr_running", "wf_1", flowrundomain.StatusRunning, ancient, nil)
	seedStatsRun(t, h.raw, "ws_1", "fr_parked", "wf_1", flowrundomain.StatusRunning, ancient, nil)
	seedParkedNode(t, h.raw, "ws_1", "frn_p", "fr_parked", "gate", ancient)
	// Terminal but undated (a malformed/legacy row).
	seedStatsRun(t, h.raw, "ws_1", "fr_undated", "wf_1", flowrundomain.StatusCompleted, ancient, nil)

	n, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, flowrundomain.RetentionBatchSize)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if n != 0 {
		t.Fatalf("purged %d rows; running/parked/undated runs must NEVER be swept", n)
	}
	for _, id := range []string{"fr_running", "fr_parked", "fr_undated"} {
		if got := countRows(t, h, "flowruns", "id = ?", id); got != 1 {
			t.Errorf("%s was swept", id)
		}
	}
	if got := countRows(t, h, "flowrun_nodes", "flowrun_id = 'fr_parked'"); got != 1 {
		t.Errorf("a parked node (a live inbox item) was swept")
	}
}

// The cutoff is STRICTLY before, on completed_at — the window semantics flowrun-stats' completedSince
// uses. A run that started long ago but finished inside the window is FRESH and stays.
//
// cutoff 是**严格早于**、按 completed_at——与 flowrun-stats 的 completedSince 同一窗口语义。很久以前起跑、
// 但在窗内**落定**的 run 是**新鲜**的、留下。
func TestPurgeTerminalRunsBefore_CutoffBoundaryOnCompletedAt(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -90)

	// Exactly ON the line — strictly-before means it stays.
	seedStatsRun(t, h.raw, "ws_1", "fr_on", "wf_1", flowrundomain.StatusCompleted, cutoff.Add(-time.Hour), &cutoff)
	// One second over the line — it goes.
	over := cutoff.Add(-time.Second)
	seedStatsRun(t, h.raw, "ws_1", "fr_over", "wf_1", flowrundomain.StatusFailed, over, &over)
	// A three-year run that failed an hour ago: OLD by started_at, FRESH by completed_at. It stays —
	// the whole reason the line reads completed_at.
	// 一个跑了三年、一小时前才失败的 run：按 started_at 是**旧**的、按 completed_at 是**新鲜**的。它留下——
	// 这正是线读 completed_at 的全部理由。
	recent := now.Add(-time.Hour)
	seedStatsRun(t, h.raw, "ws_1", "fr_long", "wf_1", flowrundomain.StatusFailed, now.AddDate(-3, 0, 0), &recent)
	// cancelled is terminal too — a neutral disposition is still history past the line.
	seedStatsRun(t, h.raw, "ws_1", "fr_cancelled", "wf_1", flowrundomain.StatusCancelled, over, &over)

	n, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, flowrundomain.RetentionBatchSize)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if n != 2 {
		t.Fatalf("purged %d want 2 (fr_over + fr_cancelled)", n)
	}
	for _, id := range []string{"fr_on", "fr_long"} {
		if got := countRows(t, h, "flowruns", "id = ?", id); got != 1 {
			t.Errorf("%s must survive the line", id)
		}
	}
	for _, id := range []string{"fr_over", "fr_cancelled"} {
		if got := countRows(t, h, "flowruns", "id = ?", id); got != 0 {
			t.Errorf("%s must be swept", id)
		}
	}
}

// The batch bound is honoured (the tx must stay short on a single-connection DB), and repeated
// batches drain the backlog without skipping.
// 批的上界被遵守（单连接 DB 上事务必须短），且反复批次把积压排空、不漏。
func TestPurgeTerminalRunsBefore_Batches(t *testing.T) {
	h := newActivityHarness(t)
	ctx := ctxWS("ws_1")
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -90)
	old := now.AddDate(0, 0, -100)

	for i := 0; i < 5; i++ {
		id := "fr_" + string(rune('a'+i))
		at := old.Add(time.Duration(i) * time.Minute)
		seedStatsRun(t, h.raw, "ws_1", id, "wf_1", flowrundomain.StatusCompleted, at, &at)
		seedMatrixNode(t, h.raw, "ws_1", "frn_"+string(rune('a'+i)), id, "n", "action", flowrundomain.NodeCompleted, 0, at)
	}

	n, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, 2)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if n != 2 {
		t.Fatalf("batch=2 must purge exactly 2, got %d", n)
	}
	if got := countRows(t, h, "flowruns", "workspace_id = 'ws_1'"); got != 3 {
		t.Fatalf("after one batch: got %d runs want 3", got)
	}
	total := n
	for {
		got, err := h.fr.PurgeTerminalRunsBefore(ctx, cutoff, 2)
		if err != nil {
			t.Fatalf("purge: %v", err)
		}
		total += got
		if got < 2 {
			break
		}
	}
	if total != 5 {
		t.Fatalf("batched sweep must drain all 5, got %d", total)
	}
	if got := countRows(t, h, "flowrun_nodes", "workspace_id = 'ws_1'"); got != 0 {
		t.Errorf("node rows orphaned after the batched sweep: %d", got)
	}
}

// D2: another workspace's over-the-line runs are invisible to this one's sweep, and a bare ctx is
// rejected rather than silently sweeping across workspaces.
// D2：另一个 workspace 越线的 run 对这个的清理不可见，且裸 ctx 被拒、而非静默跨 workspace 清理。
func TestPurgeTerminalRunsBefore_WorkspaceIsolation(t *testing.T) {
	h := newActivityHarness(t)
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -90)
	old := now.AddDate(0, 0, -100)
	seedStatsRun(t, h.raw, "ws_other", "fr_other", "wf_1", flowrundomain.StatusCompleted, old, &old)
	seedMatrixNode(t, h.raw, "ws_other", "frn_other", "fr_other", "n", "action", flowrundomain.NodeCompleted, 0, old)

	n, err := h.fr.PurgeTerminalRunsBefore(ctxWS("ws_1"), cutoff, flowrundomain.RetentionBatchSize)
	if err != nil {
		t.Fatalf("purge: %v", err)
	}
	if n != 0 {
		t.Fatalf("ws_1's sweep purged %d of ws_other's runs — D2 broken", n)
	}
	if got := countRows(t, h, "flowruns", "id = 'fr_other'"); got != 1 {
		t.Errorf("another workspace's run was swept")
	}

	if _, err := h.fr.PurgeTerminalRunsBefore(context.Background(), cutoff, 10); err == nil {
		t.Fatal("a bare ctx must be rejected (D2), never sweep every workspace")
	}
}
