package scheduler

import (
	"encoding/json"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	entitystreamapp "github.com/sunweilin/anselm/backend/internal/app/entitystream"
	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// Single-run :cancel (scheduler 工单②) — the engine-level semantics, item by item:
// ① non-running → ErrNotCancellable (422); ② running→cancelled is first-wins (concurrent double
// cancel / cancel vs natural terminal — the DB guard arbitrates); ③ an interrupted in-flight node
// writes NO row (never a lying `failed`); ④ parked approvals are swept (no dead inbox entries);
// ⑤ cancelling a draining workflow's last in-flight run settles draining→inactive; ⑥ exactly one
// DURABLE run_terminal frame, and only from the guard winner.
//
// 单 run :cancel（scheduler 工单②）——引擎级语义逐项：① 非 running → ErrNotCancellable（422）；
// ② running→cancelled first-wins（并发双 cancel / cancel 与自然终态竞态——DB 守卫仲裁）；③ 被打断
// 在飞节点**不落行**（绝不误写 failed）；④ parked 审批被收（收件箱不留死项）；⑤ 取消 draining
// workflow 最后在途 run 触发 draining→inactive 结算；⑥ 恰一条 **durable** run_terminal 帧、且只出
// 自守卫赢家。

// A run parked on an approval (scheduler_test.go's approvalGraph: start → human → publish) is the
// canonical "long run": it stays running with no in-flight advance (the drive returned at the park)
// — cancellable purely via the store.
// park 在审批上的 run（scheduler_test.go 的 approvalGraph：start → human → publish）是标准「长 run」：
// 保持 running 且无在飞 advance（驱动在 park 处已返回）——纯经 store 即可取消。

// TestCancelRun_NotRunning422 — ① only a running run is cancellable: a completed run returns
// ErrNotCancellable (its recorded terminal stands), an unknown id returns ErrNotFound.
func TestCancelRun_NotRunning422(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("a", workflowdomain.NodeKindAction, "fn_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "a")},
	}
	svc, store := mkSvc(t, g, newDisp(), nil, nil, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCompleted)

	if err := svc.CancelRun(ctx, runID); !errors.Is(err, flowrundomain.ErrNotCancellable) {
		t.Fatalf("cancel of a completed run: want ErrNotCancellable, got %v", err)
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCompleted) // terminal untouched
	if err := svc.CancelRun(ctx, "fr_missing"); !errors.Is(err, flowrundomain.ErrNotFound) {
		t.Fatalf("cancel of a missing run: want ErrNotFound, got %v", err)
	}
	// ⑥ honest wire: the only terminal frame is the natural `completed` — the losing cancel emitted nothing.
	// ⑥ 线缆诚实：唯一终态帧是自然 `completed`——输掉的 cancel 什么也没发。
	terms := b.signals(entitystreamapp.NodeRunTerminal)
	if len(terms) != 1 || !strings.Contains(string(terms[0].Node.Content), `"status":"completed"`) {
		t.Fatalf("want exactly the natural completed terminal frame, got %d: %+v", len(terms), terms)
	}
}

// TestCancelRun_ParkedRun_SweepsInboxAndSettlesDrain — ④⑤⑥ on one parked run: cancel flips the
// header, resolves the parked approval row (inbox emptied, the row lands failed — the run header
// records the real cause), fires the drain reconcile, and emits exactly one durable cancelled
// run_terminal.
func TestCancelRun_ParkedRun_SweepsInboxAndSettlesDrain(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{"apf_1": {Template: "ok?"}}}
	svc, store := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	recon := &fakeReconciler{}
	svc.SetLifecycleReconciler(recon)
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{"v": "99"})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusRunning) // parked → still running
	if parked, _ := store.ListParkedNodes(ctx); len(parked) != 1 {
		t.Fatalf("precondition: want 1 parked node, got %d", len(parked))
	}

	if err := svc.CancelRun(ctx, runID); err != nil {
		t.Fatalf("CancelRun: %v", err)
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCancelled)

	// ④ the inbox holds no dead entry; the swept row records a terminal (failed — the one
	// non-completed node terminal; the header carries the real cause `cancelled`).
	// ④ 收件箱无死项；被收的行落终态（failed——唯一非 completed 节点终态；真实因 `cancelled` 在头上）。
	if parked, _ := store.ListParkedNodes(ctx); len(parked) != 0 {
		t.Fatalf("parked approval must be swept on cancel, still %d in the inbox", len(parked))
	}
	nodes, _ := store.GetNodes(ctx, runID)
	for _, n := range nodes {
		if n.NodeID == "human" && n.Status != flowrundomain.NodeFailed {
			t.Fatalf("swept approval row: want failed, got %s", n.Status)
		}
	}

	// ⑤ cancelling the workflow's last in-flight run reconciles its drain (draining→inactive).
	// ⑤ 取消最后一个在途 run 结算排空（draining→inactive）。
	if len(recon.drained) == 0 || recon.drained[len(recon.drained)-1] != "wf_1" {
		t.Fatalf("cancel of the last in-flight run must reconcile drain for wf_1, got %v", recon.drained)
	}

	// ⑥ exactly one DURABLE cancelled run_terminal. ⑥ 恰一条 durable cancelled 终态帧。
	terms := b.signals(entitystreamapp.NodeRunTerminal)
	if len(terms) != 1 {
		t.Fatalf("want exactly 1 run_terminal frame, got %d", len(terms))
	}
	if terms[0].Ephemeral {
		t.Fatal("run_terminal must be durable (survive reconnect)")
	}
	if !strings.Contains(string(terms[0].Node.Content), `"status":"cancelled"`) ||
		!strings.Contains(string(terms[0].Node.Content), runID) {
		t.Fatalf("run_terminal content: %s", terms[0].Node.Content)
	}
}

// TestCancelRun_ConcurrentDoubleCancel_FirstWins — ② two racing cancels of one parked run: the DB
// guard (UPDATE ... WHERE status='running') admits exactly one winner; the loser gets a clean
// ErrNotCancellable and emits nothing — one cancelled run_terminal total.
func TestCancelRun_ConcurrentDoubleCancel_FirstWins(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{"apf_1": {Template: "ok?"}}}
	svc, store := mkSvc(t, approvalGraph(), newDisp(), nil, apf, "")
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")

	runID := mustRun(t, svc, ctx, map[string]any{"v": "99"})
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusRunning)

	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			errs[i] = svc.CancelRun(ctx, runID)
		}(i)
	}
	wg.Wait()

	wins, losses := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			wins++
		case errors.Is(err, flowrundomain.ErrNotCancellable):
			losses++
		default:
			t.Fatalf("unexpected cancel error: %v", err)
		}
	}
	if wins != 1 || losses != 1 {
		t.Fatalf("first-wins: want exactly 1 winner + 1 ErrNotCancellable loser, got wins=%d losses=%d", wins, losses)
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCancelled)
	if terms := b.signals(entitystreamapp.NodeRunTerminal); len(terms) != 1 {
		t.Fatalf("only the guard winner may emit run_terminal: got %d frames", len(terms))
	}
}

// TestCancelRun_InterruptsBlockedAgent_NoRowForInterruptedNode — ③ the core in-flight proof: a run
// blocked deep inside a long agent is interrupted by CancelRun cancelling its registered ctx (the
// inflight registry, shared with kill). The interrupted node writes NO flowrun_nodes row — not a
// `failed` one either (nodeInterrupted bail) — and the blocked StartRun returns CLEANLY (no error:
// an interruption is not a walk failure). The run's terminal is cancelled, owned by the canceller.
func TestCancelRun_InterruptsBlockedAgent_NoRowForInterruptedNode(t *testing.T) {
	g := workflowdomain.Graph{
		Nodes: []workflowdomain.Node{
			node("t", workflowdomain.NodeKindTrigger, "trg_1", nil),
			node("a", workflowdomain.NodeKindAgent, "ag_1", nil),
		},
		Edges: []workflowdomain.Edge{edge("e", "t", "", "a")},
	}
	disp := &blockingAgentDispatcher{entered: make(chan string, 1)}
	store, _ := newStore(t)
	graphJSON := mustJSON(t, g)
	wf := &fakeWorkflows{
		wf:   &workflowdomain.Workflow{ID: "wf_1", Concurrency: workflowdomain.ConcurrencyAllowAll, ActiveVersionID: "wfv_1", LifecycleState: workflowdomain.LifecycleActive},
		ver:  &workflowdomain.Version{ID: "wfv_1", WorkflowID: "wf_1", Version: 1, Graph: graphJSON},
		pins: map[string]string{},
	}
	svc := NewService(store, wf, &fakeControl{byID: nil}, &fakeApproval{byID: nil}, disp, nil, nil)
	b := &sigBridge{}
	svc.SetEntitiesBridge(b)
	ctx := ctxWS("ws_1")

	done := make(chan error, 1)
	go func() {
		_, err := svc.StartRun(ctx, StartInput{WorkflowID: "wf_1", Payload: map[string]any{}})
		done <- err
	}()
	select {
	case <-disp.entered: // the agent node is now blocking on its ctx
	case <-time.After(2 * time.Second):
		t.Fatal("RunAgent never entered — the run did not reach the agent node")
	}
	running, err := store.ListRunningByWorkflow(ctx, "wf_1")
	if err != nil || len(running) != 1 {
		t.Fatalf("want 1 running run, got %d (err=%v)", len(running), err)
	}
	runID := running[0].ID

	if err := svc.CancelRun(ctx, runID); err != nil {
		t.Fatalf("CancelRun: %v", err)
	}
	select {
	case startErr := <-done: // the blocked advance was interrupted and returned
		if startErr != nil {
			t.Fatalf("an interrupted StartRun must return cleanly (durable state is authoritative), got %v", startErr)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("cancel did not interrupt the blocked advance")
	}
	assertRunStatus(t, store, ctx, runID, flowrundomain.StatusCancelled)

	// ③ the interrupted agent node left NO row of any status — only the seed trigger row exists.
	// ③ 被打断的 agent 节点没留下任何状态的行——只有 seed trigger 行。
	nodes, err := store.GetNodes(ctx, runID)
	if err != nil {
		t.Fatalf("GetNodes: %v", err)
	}
	if len(nodes) != 1 || nodes[0].NodeID != "t" {
		t.Fatalf("want only the trigger row, got %d rows: %+v", len(nodes), nodes)
	}
	// No lying node tick either: the wire saw no `failed` for a node that did not fail.
	// 也没有撒谎的节点 tick：线缆没见到「没失败的节点」的 failed。
	for _, s := range b.signals(entitystreamapp.NodeRun) {
		if strings.Contains(string(s.Node.Content), `"nodeId":"a"`) {
			t.Fatalf("interrupted node must not tick: %s", s.Node.Content)
		}
	}
}

// mustJSON marshals a graph for direct fake wiring (mkSvc's sibling for custom dispatchers).
// mustJSON 序列化图供直接 fake 装配（自定义 dispatcher 时 mkSvc 的兄弟）。
func mustJSON(t *testing.T, g workflowdomain.Graph) string {
	t.Helper()
	raw, err := json.Marshal(g)
	if err != nil {
		t.Fatalf("marshal graph: %v", err)
	}
	return string(raw)
}
