// timing_test.go pins the node queue stamps (scheduler 工单⑫): ready_at / started_at are captured
// in memory during a drive and ride each row's single record-once INSERT — and their semantics
// under :replay (a re-run row gets FRESH stamps at the same iteration; completed rows keep theirs)
// and crash recovery (a recovered re-run's ready_at is the RECOVERING drive's walk time — a new
// queue start, never a pretend-seamless resume) hold exactly as legislated in database.md.
//
// timing_test.go 钉死节点排队戳（scheduler 工单⑫）：ready_at / started_at 驱动期间内存暂存、随各行唯一
// 一次 record-once INSERT 落盘——且其 :replay 语义（重跑行在同 iteration 拿**新**戳；completed 行戳保留）
// 与崩溃恢复语义（恢复重跑的 ready_at 是**恢复驱动**的 walk 时刻——新的排队起点、绝不伪装无缝）逐字符合
// database.md 立法。
package scheduler

import (
	"errors"
	"testing"
	"time"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// requireStamps asserts a row carries both stamps in causal order: readyAt ≤ startedAt (≤ completedAt).
// requireStamps 断言行带两戳且因果有序：readyAt ≤ startedAt（≤ completedAt）。
func requireStamps(t *testing.T, r *flowrundomain.FlowRunNode) {
	t.Helper()
	if r == nil {
		t.Fatal("node row missing")
	}
	if r.ReadyAt == nil || r.StartedAt == nil {
		t.Fatalf("node %s must carry queue stamps, got ready=%v started=%v", r.NodeID, r.ReadyAt, r.StartedAt)
	}
	if r.StartedAt.Before(*r.ReadyAt) {
		t.Fatalf("node %s startedAt %v before readyAt %v", r.NodeID, r.StartedAt, r.ReadyAt)
	}
	if r.CompletedAt != nil && r.CompletedAt.Before(*r.StartedAt) {
		t.Fatalf("node %s completedAt %v before startedAt %v", r.NodeID, r.CompletedAt, r.StartedAt)
	}
}

// TestStamps_TerminalRowsCarryQueueStamps: every scheduled row (action, failed action, control)
// lands with ready_at ≤ started_at on its one INSERT; the seed trigger row stays NULL (never queued).
func TestStamps_TerminalRowsCarryQueueStamps(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("a", "action", "fn_a", map[string]string{"x": "start.v"}),
			node("b", "action", "fn_b", map[string]string{"y": "a.n"}),
		},
		Edges: []workflowdomain.Edge{edge("e1", "start", "", "a"), edge("e2", "a", "", "b")},
	}
	disp := newDisp()
	svc, store := mkSvc(t, g, disp, nil, nil, "")
	ctx := ctxWS("ws_1")
	before := time.Now().UTC()
	id := mustRun(t, svc, ctx, map[string]any{"v": "hi"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	rows := nodeRows(t, store, ctx, id)
	for _, nid := range []string{"a", "b"} {
		requireStamps(t, rows[nid])
		if rows[nid].ReadyAt.Before(before) {
			t.Fatalf("node %s readyAt %v predates the run", nid, rows[nid].ReadyAt)
		}
	}
	// b queues behind a in the same batch-less chain: its readyAt is a's completion turn, never
	// earlier than a's readyAt. b 排在 a 之后：其 readyAt 是 a 完成后的那轮、绝不早于 a 的 readyAt。
	if rows["b"].ReadyAt.Before(*rows["a"].ReadyAt) {
		t.Fatalf("b readyAt %v before a readyAt %v", rows["b"].ReadyAt, rows["a"].ReadyAt)
	}
	// The seed trigger row was never scheduled — stamps stay NULL (absence is honest).
	// seed trigger 行从未被调度——戳保持 NULL（缺席即诚实）。
	trig := rows["start"]
	if trig.ReadyAt != nil || trig.StartedAt != nil {
		t.Fatalf("seed trigger row must carry no queue stamps, got ready=%v started=%v", trig.ReadyAt, trig.StartedAt)
	}
}

// TestStamps_FailedRowCarriesStamps_ReplayGetsFreshOnes: a failed row carries the stamps of ITS
// attempt; :replay physically clears it and the re-run writes a NEW row with FRESH (later) stamps at
// the same iteration, while the completed predecessor keeps its original stamps byte-for-byte
// (record-once: copied, never re-executed).
func TestStamps_FailedRowCarriesStamps_ReplayGetsFreshOnes(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("a", "action", "fn_a", map[string]string{"x": "start.v"}),
			node("b", "action", "fn_boom", map[string]string{"y": "a.n"}),
		},
		Edges: []workflowdomain.Edge{edge("e1", "start", "", "a"), edge("e2", "a", "", "b")},
	}
	disp := newDisp()
	disp.failRefs["fn_boom"] = true
	svc, store := mkSvc(t, g, disp, nil, nil, "")
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "1"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusFailed)

	first := nodeRows(t, store, ctx, id)
	requireStamps(t, first["b"]) // the failed attempt's own stamps. 失败尝试自己的戳。
	aReady, aStarted := *first["a"].ReadyAt, *first["a"].StartedAt
	bFirstStarted := *first["b"].StartedAt

	// Let the clock move past the first attempt's stamps, then repair and replay.
	// 让时钟越过首次尝试的戳，再修好重放。
	time.Sleep(15 * time.Millisecond)
	disp.mu.Lock()
	disp.failRefs["fn_boom"] = false
	disp.mu.Unlock()
	if err := svc.Replay(ctx, id); err != nil {
		t.Fatalf("Replay: %v", err)
	}
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	second := nodeRows(t, store, ctx, id)
	requireStamps(t, second["b"])
	// New row, new queue origin: the replay attempt's stamps postdate the failed attempt's.
	// 新行新排队起点：replay 尝试的戳晚于失败尝试的。
	if !second["b"].StartedAt.After(bFirstStarted) {
		t.Fatalf("replayed b startedAt %v must postdate the failed attempt's %v", second["b"].StartedAt, bFirstStarted)
	}
	if second["b"].Iteration != 0 {
		t.Fatalf("replay re-runs the SAME iteration, got %d", second["b"].Iteration)
	}
	// The completed predecessor was copied, not re-run — stamps identical.
	// completed 前驱被抄、未重跑——戳逐字不变。
	if !second["a"].ReadyAt.Equal(aReady) || !second["a"].StartedAt.Equal(aStarted) {
		t.Fatalf("completed a's stamps must survive replay: ready %v→%v started %v→%v",
			aReady, second["a"].ReadyAt, aStarted, second["a"].StartedAt)
	}
	if disp.calls("fn_a") != 1 {
		t.Fatalf("a must not re-run on replay, ran %d times", disp.calls("fn_a"))
	}
}

// TestStamps_RecoveryIsANewQueueStart: after a "crash" (a run seeded but never driven — the
// in-memory stamps died with the drive), the recovering Advance recomputes ready and stamps anew:
// ready_at sits at the RECOVERY walk, after the crash gap — never backdated to the run's birth.
func TestStamps_RecoveryIsANewQueueStart(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("start", "trigger", "trg_1", nil),
			node("a", "action", "fn_a", map[string]string{"x": "start.v"}),
		},
		Edges: []workflowdomain.Edge{edge("e1", "start", "", "a")},
	}
	disp := newDisp()
	svc, store := mkSvc(t, g, disp, nil, nil, "")
	ctx := ctxWS("ws_1")

	// Seed the run directly (header + trigger row), like a crash right after creation: no drive ran,
	// no node row exists, no stamp survived. 直接 seed（头+trigger 行），如创建后即崩：没驱动过、无节点行、无戳存活。
	run := &flowrundomain.FlowRun{WorkflowID: "wf_1", VersionID: "wfv_1", Status: flowrundomain.StatusRunning}
	trig := &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger", Ref: "trg_1", Status: flowrundomain.NodeCompleted, Result: map[string]any{"v": "1"}}
	id, err := store.CreateRunWithTrigger(ctx, run, trig)
	if err != nil {
		t.Fatalf("seed: %v", err)
	}

	time.Sleep(15 * time.Millisecond) // the crash gap. 崩溃间隙。
	recoveryFloor := time.Now().UTC()
	if err := svc.Advance(ctx, id); err != nil { // what boot Recover enqueues. boot Recover 入队的正是它。
		t.Fatalf("Advance: %v", err)
	}
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	a := nodeRows(t, store, ctx, id)["a"]
	requireStamps(t, a)
	if a.ReadyAt.Before(recoveryFloor) {
		t.Fatalf("recovered readyAt %v must be the recovery walk's (≥ %v), not backdated to the run's birth", a.ReadyAt, recoveryFloor)
	}
}

// TestListActivity_UnknownRunIs404: the app guard — an unknown run id is an honest
// FLOWRUN_NOT_FOUND before the projection runs (the projection alone cannot tell "no activity yet"
// from "no such run"). The projection itself is store-tested (activity_test.go) + testend.
//
// TestListActivity_UnknownRunIs404：app 守卫——未知 run id 在投影跑之前就是诚实 FLOWRUN_NOT_FOUND
// （光靠投影分不清「还没活动」与「无此 run」）。投影本身由 store 测试（activity_test.go）+ testend 兜。
func TestListActivity_UnknownRunIs404(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{node("start", "trigger", "trg_1", nil)},
	}
	svc, _ := mkSvc(t, g, newDisp(), nil, nil, "")
	if _, _, err := svc.ListActivity(ctxWS("ws_1"), "fr_ghost", "", 10); !errors.Is(err, flowrundomain.ErrNotFound) {
		t.Fatalf("unknown run must be ErrNotFound, got %v", err)
	}
}

// TestStamps_ParkedRowKeepsStampsThroughDecision: a parked approval row carries the stamps of its
// park; the decision flips status/result/completed_at and the stamps survive untouched.
func TestStamps_ParkedRowKeepsStampsThroughDecision(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "approve {{ input.amt }}?", AllowReason: true},
	}}
	disp := newDisp()
	svc, store := mkSvc(t, approvalGraph(), disp, nil, apf, "")
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "9"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusRunning) // parked at human

	parked := nodeRows(t, store, ctx, id)["human"]
	requireStamps(t, parked)
	if parked.CompletedAt != nil {
		t.Fatalf("parked row must have nil completedAt, got %v", parked.CompletedAt)
	}
	pReady, pStarted := *parked.ReadyAt, *parked.StartedAt

	time.Sleep(15 * time.Millisecond)
	if err := svc.DecideApproval(ctx, id, "human", "yes", "ok"); err != nil {
		t.Fatalf("DecideApproval: %v", err)
	}
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)

	decided := nodeRows(t, store, ctx, id)["human"]
	if decided.Status != flowrundomain.NodeCompleted || decided.CompletedAt == nil {
		t.Fatalf("decided row wrong: %+v", decided)
	}
	if !decided.ReadyAt.Equal(pReady) || !decided.StartedAt.Equal(pStarted) {
		t.Fatalf("decision must not touch the park's stamps: ready %v→%v started %v→%v",
			pReady, decided.ReadyAt, pStarted, decided.StartedAt)
	}
}
