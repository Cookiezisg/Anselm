package scheduler

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// fakeReconciler records which workflows the scheduler asked to settle their drain.
type fakeReconciler struct{ drained []string }

func (f *fakeReconciler) MarkRunAttention(_ context.Context, _ string, _ bool, _ string) error {
	return nil
}

func (f *fakeReconciler) MarkInactiveIfDrained(_ context.Context, workflowID string) error {
	f.drained = append(f.drained, workflowID)
	return nil
}

// TestDrainReconcile_FiresOnRunSettle: when a run reaches a terminal state and its workflow has no
// other runs in flight, the scheduler asks the LifecycleReconciler to settle the drain (the
// :deactivate→draining→inactive auto-flip). A one-node run completes → reconcile fires for wf_1.
func TestDrainReconcile_FiresOnRunSettle(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("a", workflowdomain.NodeKindAction, "fn_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "a")},
	}
	svc, store := mkSvc(t, g, newDisp(), nil, nil, "")
	recon := &fakeReconciler{}
	svc.SetLifecycleReconciler(recon)
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCompleted)
	if len(recon.drained) == 0 || recon.drained[len(recon.drained)-1] != "wf_1" {
		t.Fatalf("a settled run with 0 in-flight should reconcile drain for wf_1, got %v", recon.drained)
	}
}

// TestKillWorkflow_CancelsParkedRun: a run parked on an approval is StatusRunning but has no
// in-flight advance (the goroutine returned at the park). Kill marks it cancelled — the simple
// not-blocked path (cancelInflight is a no-op, the store write does the work).
func TestKillWorkflow_CancelsParkedRun(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("ap", workflowdomain.NodeKindApproval, "apf_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "ap")},
	}
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{"apf_1": {Template: "ok?"}}}
	svc, store := mkSvc(t, g, newDisp(), nil, apf, "")
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusRunning) // parked → run stays running

	killed, err := svc.KillWorkflow(ctx, "wf_1")
	if err != nil {
		t.Fatalf("KillWorkflow: %v", err)
	}
	if killed != 1 {
		t.Fatalf("killed = %d, want 1", killed)
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCancelled)
}

// losingRunStore makes ONE run's header guard lose, deterministically: the run reaches its natural
// terminal an instant before the cancel's guarded UPDATE, so MarkRunTerminal matches 0 rows and
// reports won=false. That interleaving is real (a node finishing as the user hits kill) but
// unschedulable from a test, and RunStore being a port is the seam that makes it reproducible.
//
// losingRunStore 让**一个** run 的头守卫确定性地输：该 run 在 cancel 的守卫 UPDATE 前一瞬走到自己的自然
// 终态，故 MarkRunTerminal 匹配 0 行、报 won=false。这个交错是真实的（用户按下 kill 的同时某节点跑完了），
// 但在测试里排不出来——RunStore 是端口，这就是让它可复现的那道缝。
type losingRunStore struct {
	RunStore
	loseFor string
}

func (l *losingRunStore) MarkRunTerminal(ctx context.Context, id, status, msg string) (bool, error) {
	if id != l.loseFor {
		return l.RunStore.MarkRunTerminal(ctx, id, status, msg)
	}
	// The natural terminal lands first and WINS the guard...
	if _, err := l.RunStore.MarkRunTerminal(ctx, id, flowrundomain.StatusFailed, "natural failure"); err != nil {
		return false, err
	}
	// ...so the caller's cancel finds 0 rows, exactly as the real guard would report it.
	return false, nil
}

// TestKillWorkflow_GuardLoser_LeavesParkedRowAlone — the sweep is gated on WINNING the header guard,
// and that gate is a correctness boundary, not etiquette. A loser's run reached its own terminal; if
// that terminal is `failed`, the run is still replayable and its parked approval is still live — a
// human can decide it after a :replay resurrects the run (which is exactly why the failRun path never
// sweeps either). Sweeping it anyway would write a `cancelled` row onto a REPLAYABLE run, and
// :replay cannot clear it (DeleteFailedNodes takes only failed rows, and D1 permits no third
// delete): the approval would be permanently stuck, silently skipped by every subsequent re-walk.
//
// TestKillWorkflow_GuardLoser_LeavesParkedRowAlone——收割闸在「赢了头守卫」上，而那道闸是**正确性**边界、
// 不是礼貌。输家的 run 走到的是它自己的终态；若那是 `failed`，run 仍可 replay、它的 parked 审批仍然活着
// ——:replay 把 run 救回来后人仍可决策它（这也正是 failRun 路径同样从不收割的原因）。硬收割会把一条
// `cancelled` 行写到一个**可 replay** 的 run 上，而 :replay 清不掉它（DeleteFailedNodes 只收 failed 行，
// 且 D1 不容第三个删）：该审批就永久卡死、被之后每次重走静默跳过。
func TestKillWorkflow_GuardLoser_LeavesParkedRowAlone(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("ap", workflowdomain.NodeKindApproval, "apf_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "ap")},
	}
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{"apf_1": {Template: "ok?"}}}
	svc, store := mkSvc(t, g, newDisp(), nil, apf, "")
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusRunning)

	// Re-seat the service on a store whose guard loses for this run.
	svc.runs = &losingRunStore{RunStore: store, loseFor: runID}

	if _, err := svc.KillWorkflow(ctx, "wf_1"); err != nil {
		t.Fatalf("KillWorkflow: %v", err)
	}

	// The natural terminal stands — kill did not clobber it.
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusFailed)

	// And the parked row is UNTOUCHED: still parked, still in the inbox, still decidable.
	// parked 行**没被碰**：仍 parked、仍在收件箱、仍可决策。
	parked, _ := store.ListParkedNodes(ctx)
	if len(parked) != 1 || parked[0].FlowRunID != runID {
		t.Fatalf("the guard loser must not sweep a run it did not cancel: inbox=%+v", parked)
	}
	if parked[0].Status != flowrundomain.NodeParked {
		t.Fatalf("parked row disposition = %q, want parked (untouched)", parked[0].Status)
	}
}

// blockingAgentDispatcher's RunAgent signals that it entered, then blocks until its ctx is cancelled
// — modelling a long agent stuck mid-run. This is exactly the case kill must interrupt.
type blockingAgentDispatcher struct{ entered chan string }

func (d *blockingAgentDispatcher) RunAction(context.Context, string, string, map[string]any) (map[string]any, error) {
	return map[string]any{}, nil
}
func (d *blockingAgentDispatcher) RunAgent(ctx context.Context, ref, _ string, _ map[string]any) (map[string]any, error) {
	d.entered <- ref
	<-ctx.Done()
	return nil, ctx.Err()
}

// TestKillWorkflow_InterruptsBlockedAgent is the core proof of the kill mechanism: a run blocked deep
// inside a long-running agent node is interrupted by KillWorkflow cancelling its registered ctx — the
// blocked advance returns, and the run lands cancelled (NOT failed, because kill marks cancelled
// before the ctx-cancel turns the agent's return into a node failure).
func TestKillWorkflow_InterruptsBlockedAgent(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("a", workflowdomain.NodeKindAgent, "ag_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "a")},
	}
	store, _ := newStore(t)
	raw, _ := json.Marshal(g)
	wf := &fakeWorkflows{
		wf:   &workflowdomain.Workflow{ID: "wf_1", Concurrency: workflowdomain.ConcurrencyAllowAll, ActiveVersionID: "wfv_1", LifecycleState: workflowdomain.LifecycleActive},
		ver:  &workflowdomain.Version{ID: "wfv_1", WorkflowID: "wf_1", Version: 1, Graph: string(raw)},
		pins: map[string]string{},
	}
	disp := &blockingAgentDispatcher{entered: make(chan string, 1)}
	svc := NewService(store, wf, &fakeControl{byID: map[string][]controldomain.Branch{}}, &fakeApproval{byID: map[string]*approvaldomain.Version{}}, disp, nil, nil)
	ctx := ctxWS("ws_1")

	done := make(chan struct{})
	go func() {
		_, _ = svc.StartRun(ctx, StartInput{WorkflowID: "wf_1", Payload: map[string]any{}})
		close(done)
	}()

	select {
	case <-disp.entered: // RunAgent started and is now blocking on its ctx
	case <-time.After(2 * time.Second):
		t.Fatal("RunAgent never entered — the run did not reach the agent node")
	}

	running, err := store.ListRunningByWorkflow(ctx, "wf_1")
	if err != nil {
		t.Fatalf("ListRunningByWorkflow: %v", err)
	}
	if len(running) != 1 {
		t.Fatalf("want 1 running run, got %d", len(running))
	}
	runID := running[0].ID

	killed, err := svc.KillWorkflow(ctx, "wf_1")
	if err != nil {
		t.Fatalf("KillWorkflow: %v", err)
	}
	if killed != 1 {
		t.Fatalf("killed = %d, want 1", killed)
	}

	select {
	case <-done: // StartRun's Advance returned — the blocked node was interrupted
	case <-time.After(2 * time.Second):
		t.Fatal("kill did not interrupt the blocked advance")
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCancelled)
}

// TestService_Shutdown_CancelsAllInflight — R3: scheduler.Shutdown cancels EVERY in-flight advance's
// ctx (so a backend shutdown interrupts runs wedged mid-node after the grace) and clears the registry.
func TestService_Shutdown_CancelsAllInflight(t *testing.T) {
	s := &Service{inflight: map[string]context.CancelFunc{}}
	c1, _ := s.trackInflight(context.Background(), "fr_1")
	c2, _ := s.trackInflight(context.Background(), "fr_2")

	s.Shutdown()

	for i, c := range []context.Context{c1, c2} {
		select {
		case <-c.Done():
		case <-time.After(time.Second):
			t.Fatalf("in-flight ctx %d not cancelled by Shutdown", i)
		}
	}
	if len(s.inflight) != 0 {
		t.Fatalf("inflight registry not cleared: %d entries", len(s.inflight))
	}
}
