package scheduler

// Phase 3 durable-engine gap fills (battle: 全量重测). Each test targets a durable/concurrency
// invariant the existing suite left uncovered — see the per-test D-* tags. Deterministic
// (rendezvous channels, no sleeps for the pool ones), race-safe (run with -race).
//
// 第 3 阶段 durable 引擎补缺（战役：全量重测）。每个测试瞄准既有套件未覆盖的 durable/并发不变式——见每测
// 的 D-* 标签。确定性（会合 channel、池测无 sleep），并发安全（-race 跑）。

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"
	"time"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	controldomain "github.com/sunweilin/anselm/backend/internal/domain/control"
	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// ---- D-conc-4: allow_all runs concurrent firings independently to completion --------------
//
// TestConc_AllowAllTwoFiringsBothComplete — the explicit allow_all counterpart to the overlap tests
// (which assert replace/serial/skip/buffer_one SUPPRESS a sibling). allow_all must do the opposite:
// two distinct firings of the same workflow in one batch each seed a run and each runs to completion,
// with no cross-contamination of the trigger payload. TestFiring_SingleTxClaim covers a SINGLE
// allow_all firing; TestFiring_OverlapReplace_SameBatch covers two firings under REPLACE (1 survives).
// Neither pins "allow_all → 2 completed, both payloads intact".
func TestConc_AllowAllTwoFiringsBothComplete(t *testing.T) {
	disp := newDisp()
	svc, store, trg := mkSvcWithInbox(t, firingGraph(), disp, workflowdomain.ConcurrencyAllowAll)
	ctx := ctxWS("ws_1")

	for _, k := range []string{"k1", "k2"} { // two distinct firings, one batch
		if _, err := trg.AppendFiring(ctx, &triggerdomain.Firing{
			WorkspaceID: "ws_1", TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: k,
			Payload: map[string]any{"orderId": k},
		}); err != nil {
			t.Fatalf("AppendFiring %s: %v", k, err)
		}
	}
	if err := svc.DrainFirings(ctx); err != nil {
		t.Fatalf("DrainFirings: %v", err)
	}

	rows, _, _ := store.ListRuns(ctx, flowrundomain.ListFilter{Limit: 10})
	if len(rows) != 2 {
		t.Fatalf("allow_all: both firings must seed a run, got %d (%+v)", len(rows), rows)
	}
	for _, r := range rows {
		if r.Status != flowrundomain.StatusCompleted {
			t.Fatalf("allow_all: every concurrent run must complete independently, got %q (%+v)", r.Status, rows)
		}
	}
	if disp.actionCalls["fn_a"] != 2 {
		t.Fatalf("allow_all: both runs dispatch the action (want 2), got %d", disp.actionCalls["fn_a"])
	}
	// No cross-contamination: each run's trigger node kept its own payload.
	seen := map[string]bool{}
	for _, r := range rows {
		nodes, _ := store.GetNodes(ctx, r.ID)
		for _, n := range nodes {
			if n.NodeID == "start" {
				if oid, _ := n.Result["orderId"].(string); oid != "" {
					seen[oid] = true
				}
			}
		}
	}
	if !seen["k1"] || !seen["k2"] {
		t.Fatalf("each run must keep its own payload (want k1+k2), saw %+v", seen)
	}
}

// ---- D-appr-4: human decision vs timeout sweep — first-wins, exactly one winner ------------
//
// TestApproval_HumanVsTimeoutFirstWinsRace pins the first-wins arbiter (ResolveParkedNode's
// conditional UPDATE WHERE status='parked') against a CONCURRENT human decide + timeout sweep on the
// SAME parked node. Existing coverage: TestApproval_ParkResumeYes (sequential second-decide loses),
// the testend human-vs-human concurrent decide race (contract_entities), and TestApproval_Timeout
// (sequential timeout). None races a human decision against the timeout sweep. Run with -race.
func TestApproval_HumanVsTimeoutFirstWinsRace(t *testing.T) {
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "1s", TimeoutBehavior: approvaldomain.TimeoutReject},
	}}
	disp := newDisp()
	svc, store := mkSvc(t, approvalGraph(), disp, nil, apf, "")
	ctx := ctxWS("ws_1")
	id := mustRun(t, svc, ctx, map[string]any{"v": "1"})
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusRunning) // parked at human

	// Race a human YES against the timeout sweep whose deadline (1s) is already far in the past.
	var wg sync.WaitGroup
	var humanErr error
	wg.Add(2)
	go func() { defer wg.Done(); humanErr = svc.DecideApproval(ctx, id, "human", "yes", "human") }()
	go func() { defer wg.Done(); _ = svc.CheckTimeouts(ctx, time.Now().Add(time.Hour)) }()
	wg.Wait()

	// The human either won (nil) or lost cleanly to the timeout (ErrNodeNotParked) — never corruption.
	if humanErr != nil && !errors.Is(humanErr, flowrundomain.ErrNodeNotParked) {
		t.Fatalf("human decide must be nil (won) or ErrNodeNotParked (lost), got %v", humanErr)
	}
	// The parked node settled EXACTLY ONCE to a terminal decision and the run completed.
	assertRunStatus(t, store, ctx, id, flowrundomain.StatusCompleted)
	h := nodeRows(t, store, ctx, id)["human"]
	if h == nil || h.Status != flowrundomain.NodeCompleted {
		t.Fatalf("human node must settle to completed exactly once, got %+v", h)
	}
	d, _ := h.Result["decision"].(string)
	if d != workflowdomain.ApprovalPortYes && d != workflowdomain.ApprovalPortNo {
		t.Fatalf("settled decision must be yes(human) or no(timeout-reject), got %q", d)
	}
	// Downstream is consistent with the single winner: yes→publish ran; no→publish pruned.
	if d == workflowdomain.ApprovalPortYes && disp.actionCalls["fn_pub"] != 1 {
		t.Fatalf("human-yes winner must run publish once, got %d", disp.actionCalls["fn_pub"])
	}
	if d == workflowdomain.ApprovalPortNo && disp.actionCalls["fn_pub"] != 0 {
		t.Fatalf("timeout-reject winner must NOT run publish, got %d", disp.actionCalls["fn_pub"])
	}
	// The loser's follow-up is a clean no-op (first-wins): a later decide returns ErrNodeNotParked.
	if err := svc.DecideApproval(ctx, id, "human", "no", "late"); !errors.Is(err, flowrundomain.ErrNodeNotParked) {
		t.Fatalf("post-settlement decide must lose, got %v", err)
	}
}

// ---- multi-workflow fake (mkSvc's fakeWorkflows serves a single workflow) ------------------
//
// multiWorkflows serves several workflows/versions by id so one Service can drive two DIFFERENT
// graphs concurrently (needed to saturate the pool with one workflow while parking on another).
type multiWorkflows struct {
	wfs  map[string]*workflowdomain.Workflow // workflowID → workflow
	vers map[string]*workflowdomain.Version  // versionID → version
}

func (m *multiWorkflows) GetWorkflow(_ context.Context, id string) (*workflowdomain.Workflow, error) {
	if w, ok := m.wfs[id]; ok {
		return w, nil
	}
	return nil, workflowdomain.ErrNotFound
}
func (m *multiWorkflows) GetActiveVersion(_ context.Context, id string) (*workflowdomain.Version, error) {
	w, ok := m.wfs[id]
	if !ok {
		return nil, workflowdomain.ErrNotFound
	}
	return m.vers[w.ActiveVersionID], nil
}
func (m *multiWorkflows) GetVersion(_ context.Context, verID string) (*workflowdomain.Version, error) {
	if v, ok := m.vers[verID]; ok {
		return v, nil
	}
	return nil, workflowdomain.ErrNotFound
}
func (m *multiWorkflows) BuildPinClosure(context.Context, *workflowdomain.Graph) (map[string]string, error) {
	return map[string]string{}, nil
}

// ---- D-pool-4: a fully-saturated Advance pool never starves timeout settlement -------------
//
// TestPool_SaturatedPoolDoesNotStarveTimeoutSettlement is the direct proof of the F174 build.go
// invariant "审批超时扫描跑在自己的 ticker 上……满载的池绝不饿死审批超时结算". It wedges ALL
// advanceWorkers pool workers, then proves CheckTimeouts still settles a parked approval — the
// settlement is a direct store call (ResolveParkedNode), never routed through the pool. TestHOL_*
// proves a wedged worker doesn't block ANOTHER RUN (with a free worker available); it never saturates
// every worker nor exercises the off-pool timeout sweep. Deterministic (rendezvous gate, no sleeps).
func TestPool_SaturatedPoolDoesNotStarveTimeoutSettlement(t *testing.T) {
	slowRaw, _ := json.Marshal(holGraph())      // trigger → action fn_a (wedges when start.slow)
	apprRaw, _ := json.Marshal(approvalGraph()) // trigger → approval apf_1 → publish fn_pub
	wfs := &multiWorkflows{
		wfs: map[string]*workflowdomain.Workflow{
			"wf_slow": {ID: "wf_slow", Concurrency: workflowdomain.ConcurrencyAllowAll, ActiveVersionID: "wfv_slow", LifecycleState: workflowdomain.LifecycleActive},
			"wf_appr": {ID: "wf_appr", Concurrency: workflowdomain.ConcurrencyAllowAll, ActiveVersionID: "wfv_appr", LifecycleState: workflowdomain.LifecycleActive},
		},
		vers: map[string]*workflowdomain.Version{
			"wfv_slow": {ID: "wfv_slow", WorkflowID: "wf_slow", Version: 1, Graph: string(slowRaw)},
			"wfv_appr": {ID: "wfv_appr", WorkflowID: "wf_appr", Version: 1, Graph: string(apprRaw)},
		},
	}
	apf := &fakeApproval{byID: map[string]*approvaldomain.Version{
		"apf_1": {Template: "ok?", Timeout: "1s", TimeoutBehavior: approvaldomain.TimeoutReject},
	}}
	disp := newDisp()
	disp.gateFlag, disp.gate, disp.entered = "flag", make(chan struct{}), make(chan string, advanceWorkers+1)
	store, _ := newStore(t)
	svc := NewService(store, wfs, &fakeControl{byID: map[string][]controldomain.Branch{}}, apf, disp, nil, nil)
	svc.StartPool()
	defer svc.StopPool()   // runs last: drains workers after the gate is released
	defer close(disp.gate) // runs first at return: release the wedged workers so StopPool can drain
	ctx := ctxWS("ws_1")

	// Saturate EVERY pool worker with a wedged wf_slow run.
	for i := 0; i < advanceWorkers; i++ {
		run := &flowrundomain.FlowRun{WorkflowID: "wf_slow", VersionID: "wfv_slow", PinnedRefs: map[string]string{}, Status: flowrundomain.StatusRunning}
		rid, err := store.CreateRunWithTrigger(ctx, run, &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger", Status: flowrundomain.NodeCompleted, Result: map[string]any{"slow": true}})
		if err != nil {
			t.Fatalf("seed slow %d: %v", i, err)
		}
		svc.enqueueAdvance(ctx, rid)
	}
	for i := 0; i < advanceWorkers; i++ {
		select {
		case <-disp.entered:
		case <-time.After(2 * time.Second):
			t.Fatalf("only %d/%d workers saturated — pool did not drive every wedged run", i, advanceWorkers)
		}
	}

	// With every worker wedged, start a run that parks at an approval (StartRun drives inline, off-pool).
	apprID, err := svc.StartRun(ctx, StartInput{WorkflowID: "wf_appr", Payload: map[string]any{"v": "1"}})
	if err != nil {
		t.Fatalf("StartRun appr: %v", err)
	}
	if r := nodeRows(t, store, ctx, apprID)["human"]; r == nil || r.Status != flowrundomain.NodeParked {
		t.Fatalf("approval run must park at human, got %+v", r)
	}

	// THE PROOF: the independent timeout sweep settles the parked approval even though the pool is
	// fully saturated (no worker is free) — settlement is not pool-routed.
	if err := svc.CheckTimeouts(ctx, time.Now().Add(time.Hour)); err != nil {
		t.Fatalf("CheckTimeouts: %v", err)
	}
	h := nodeRows(t, store, ctx, apprID)["human"]
	if h == nil || h.Status != flowrundomain.NodeCompleted {
		t.Fatalf("timeout settlement starved by a saturated pool: human=%+v", h)
	}
	if d, _ := h.Result["decision"].(string); d != workflowdomain.ApprovalPortNo {
		t.Fatalf("timeout-reject must settle the node to 'no', got %q", d)
	}
	// And the slow runs are STILL wedged (running) — the sweep did not wait on a free worker.
	slow, _, _ := store.ListRuns(ctx, flowrundomain.ListFilter{Limit: 20})
	wedged := 0
	for _, r := range slow {
		if r.WorkflowID == "wf_slow" && r.Status == flowrundomain.StatusRunning {
			wedged++
		}
	}
	if wedged != advanceWorkers {
		t.Fatalf("all %d slow runs must still be wedged during settlement, %d running", advanceWorkers, wedged)
	}
}

// ---- D-pool-5: boot Recover ENQUEUES onto the pool (never drives inline) -------------------
//
// TestPool_RecoverEnqueuesNonInline pins StartPool-before-Recover (build.go): a slow recovered run
// must not block boot. With the pool started, Recover must ENQUEUE each running run (returning
// promptly) rather than drive it inline — inline would deadlock the boot goroutine on the wedged node.
// TestCrashRecovery_CompletedRowsSkip exercises Recover WITHOUT a pool (inline); no test proves the
// pooled-Recover non-blocking path. Deterministic (rendezvous gate).
func TestPool_RecoverEnqueuesNonInline(t *testing.T) {
	disp := newDisp()
	disp.gateFlag, disp.gate, disp.entered = "flag", make(chan struct{}), make(chan string, 2)
	svc, store := mkSvc(t, holGraph(), disp, nil, nil, workflowdomain.ConcurrencyAllowAll)
	svc.StartPool()
	defer svc.StopPool()
	defer close(disp.gate)
	ctx := ctxWS("ws_1")

	idSlow := seedRun(t, store, ctx, map[string]any{"slow": true})  // wedges in fn_a
	idFast := seedRun(t, store, ctx, map[string]any{"slow": false}) // runs free

	// Recover must return promptly (enqueue), NOT block on the wedged recovered run.
	done := make(chan error, 1)
	go func() { done <- svc.Recover(ctx) }()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("Recover: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Recover blocked on a slow recovered run — it must enqueue onto the pool, not drive inline")
	}

	// The pool actually drove the recovered runs: the wedged one entered its node; the fast one
	// completed WHILE the slow one is still wedged.
	select {
	case <-disp.entered:
	case <-time.After(2 * time.Second):
		t.Fatal("pool never drove the recovered slow run")
	}
	waitForRunStatus(t, store, ctx, idFast, flowrundomain.StatusCompleted, 2*time.Second)
	if r, _ := store.GetRun(ctx, idSlow); r.Status != flowrundomain.StatusRunning {
		t.Fatalf("slow recovered run must still be wedged (running), got %q", r.Status)
	}
}

// TestPool_ShutdownSkipsBufferedRun proves the R3/F174 shutdown fix: a run still BUFFERED in the
// Advance queue when Shutdown fires is SKIPPED by StopPool's queue-drain, not driven to full
// completion. Without the advClosing guard, StopPool's close(q) would drain every buffered run to
// completion on an uncancellable Detached ctx — an unbounded advWG.Wait that blocks shutdown past the
// grace (→ SIGKILL orphaning sandbox subprocesses). The skipped run stays Running for boot Recover.
//
// TestPool_ShutdownSkipsBufferedRun 证 R3/F174 关停修复:Shutdown 触发时仍缓冲在 Advance 队列里的 run 被
// StopPool 的排空跳过、而非跑到完成。无 advClosing 守卫时,StopPool 的 close(q) 会在不可取消的 Detached ctx 上
// 把每个缓冲 run 跑完——无界 advWG.Wait 把关停拖过宽限（→ SIGKILL 孤儿化 sandbox 子进程）。被跳过的 run 保持
// Running 待 boot Recover。
func TestPool_ShutdownSkipsBufferedRun(t *testing.T) {
	disp := newDisp()
	svc, store := mkSvc(t, firingGraph(), disp, nil, nil, workflowdomain.ConcurrencyAllowAll)
	ctx := ctxWS("ws_1")
	svc.StartPool()

	// Shutdown flags the pool closing (inflight empty here → cancel-all is a no-op); from now drive() skips.
	svc.Shutdown()

	// Seed a Running run (trigger node completed) and enqueue it — it buffers; a worker drains it.
	run := &flowrundomain.FlowRun{WorkflowID: "wf_1", VersionID: "wfv_1", PinnedRefs: map[string]string{}, Status: flowrundomain.StatusRunning}
	rid, err := store.CreateRunWithTrigger(ctx, run, &flowrundomain.FlowRunNode{NodeID: "start", Kind: "trigger", Status: flowrundomain.NodeCompleted, Result: map[string]any{"orderId": "o-1"}})
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	svc.enqueueAdvance(ctx, rid)

	// StopPool drains the buffered job; drive() must SKIP it (advClosing) rather than dispatch fn_a.
	svc.StopPool()

	if n := disp.calls("fn_a"); n != 0 {
		t.Fatalf("a run buffered when Shutdown fired must be SKIPPED, not executed — fn_a dispatched %d times", n)
	}
	got, err := store.GetRun(ctx, rid)
	if err != nil {
		t.Fatalf("GetRun: %v", err)
	}
	if got.Status != flowrundomain.StatusRunning {
		t.Fatalf("a skipped run must stay Running for boot Recover, got %s", got.Status)
	}
}
