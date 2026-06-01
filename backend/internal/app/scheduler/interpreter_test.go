package scheduler

import (
	"context"
	"errors"
	"testing"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	flowruneventstore "github.com/sunweilin/forgify/backend/internal/infra/store/flowrunevent"
)

// countingRouter records how many times each node was actually dispatched, so a test can
// assert that replay COPIES journaled results rather than re-running them.
type countingRouter struct{ calls map[string]int }

func (c *countingRouter) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	c.calls[in.Node.ID]++
	return DispatchOutput{Outputs: map[string]any{"echo": in.Node.ID}}
}

// trigger(t) -> function(a) -> function(b): a minimal linear flow.
func linearGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "linear",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "b", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "a"},
			{ID: "e2", From: "a", To: "b"},
		},
	}
}

// trigger -> case(when payload.x>5 -> hi, else -> lo). case routes via branches[].to.
func caseGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "case",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.x > 5", "to": "hi"},
					map[string]any{"when": "true", "to": "lo"},
				},
			}},
			{ID: "hi", Type: workflowdomain.NodeTypeFunction},
			{ID: "lo", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "c"},
			{ID: "e2", From: "c", To: "hi"},
			{ID: "e3", From: "c", To: "lo"},
		},
	}
}

func newJournal(t *testing.T) *flowruneventstore.Store {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := dbinfra.Migrate(gdb, flowruneventstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return flowruneventstore.New(gdb)
}

// The承重 invariant (17 §4, ADR-016/019): replaying the same journal is deterministic and
// COPIES journaled activity results — it never re-runs an already-recorded activity.
func TestInterpreter_ReplayIsDeterministicAndCopiesNotReruns(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	graph := linearGraph()
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_det", graph, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	j1, _ := journal.LoadJournal(ctx, "fr_det")
	if router.calls["a"] != 1 || router.calls["b"] != 1 {
		t.Fatalf("first run should dispatch a,b exactly once: %v", router.calls)
	}

	if _, err := New(journal, router).Resume(ctx, "fr_det", graph, nil); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if router.calls["a"] != 1 || router.calls["b"] != 1 {
		t.Fatalf("replay re-ran an already-journaled activity (must copy, not re-run): %v", router.calls)
	}
	j2, _ := journal.LoadJournal(ctx, "fr_det")
	if len(j2) != len(j1) {
		t.Fatalf("replay changed the journal: was %d events, now %d", len(j1), len(j2))
	}
	for i := range j1 {
		if j1[i].Type != j2[i].Type || j1[i].NodeID != j2[i].NodeID || j1[i].Seq != j2[i].Seq {
			t.Fatalf("replay diverged at #%d: %+v vs %+v", i, j1[i], j2[i])
		}
	}
}

// A linear run journals node_started+node_completed per activity (not the trigger) in seq order.
func TestInterpreter_LinearRunJournalsEachActivity(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_lin", linearGraph(), nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	evs, _ := journal.LoadJournal(ctx, "fr_lin")
	want := []struct {
		typ, node string
	}{
		{flowrundomain.EventNodeStarted, "a"}, {flowrundomain.EventNodeCompleted, "a"},
		{flowrundomain.EventNodeStarted, "b"}, {flowrundomain.EventNodeCompleted, "b"},
	}
	if len(evs) != len(want) {
		t.Fatalf("want %d events, got %d: %+v", len(want), len(evs), evs)
	}
	for i, w := range want {
		if evs[i].Type != w.typ || evs[i].NodeID != w.node {
			t.Fatalf("event #%d: got %s/%s want %s/%s", i, evs[i].Type, evs[i].NodeID, w.typ, w.node)
		}
	}
}

// WithTick fires a best-effort runtime tick at each activity transition (running -> ok) in seq order,
// for activities only (not the trigger) — the orchestration UI's live canvas signal (08 CANON-X4).
func TestInterpreter_WithTick_FiresRunningThenOkPerActivity(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	var ticks []string
	tick := func(nodeID, status string, _ int) { ticks = append(ticks, nodeID+":"+status) }
	if _, err := New(journal, router).WithTick(tick).Run(ctx, "fr_tick", linearGraph(), nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	want := []string{"a:running", "a:ok", "b:running", "b:ok"}
	if len(ticks) != len(want) {
		t.Fatalf("want %d ticks %v, got %d: %v", len(want), want, len(ticks), ticks)
	}
	for i := range want {
		if ticks[i] != want[i] {
			t.Fatalf("tick #%d: got %q want %q (full: %v)", i, ticks[i], want[i], ticks)
		}
	}
}

// A failing activity ticks running -> failed so the operator sees the node go red live.
func TestInterpreter_WithTick_FiresFailedOnActivityError(t *testing.T) {
	journal := newJournal(t)
	router := NewRouter()
	router.Set(workflowdomain.NodeTypeFunction, DispatcherFunc(func(_ context.Context, _ DispatchInput) DispatchOutput {
		return DispatchOutput{Error: errTestFail}
	}))
	ctx := context.Background()

	var ticks []string
	tick := func(nodeID, status string, _ int) { ticks = append(ticks, nodeID+":"+status) }
	g := workflowdomain.Graph{
		Name: "fail",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{{ID: "e1", From: "t", To: "a"}},
	}
	if _, err := New(journal, router).WithTick(tick).Run(ctx, "fr_tickfail", g, nil); err == nil {
		t.Fatal("expected the failing activity to error")
	}
	want := []string{"a:running", "a:failed"}
	if len(ticks) != len(want) || ticks[0] != want[0] || ticks[1] != want[1] {
		t.Fatalf("want %v, got %v", want, ticks)
	}
}

// case node: per-branch CEL guard, first-true-wins; routes via branches[].to + journals branch_taken.
func TestInterpreter_CaseFirstTrueWins(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_hi", caseGraph(), map[string]any{"x": 10}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["hi"] != 1 || router.calls["lo"] != 0 {
		t.Fatalf("x=10 (>5) must route to hi, not lo: %v", router.calls)
	}
	evs, _ := journal.LoadJournal(ctx, "fr_hi")
	found := false
	for _, e := range evs {
		if e.Type == flowrundomain.EventBranchTaken && e.NodeID == "c" {
			found = true
			if to := asMap(e.Result)["to"]; to != "hi" {
				t.Fatalf("branch_taken to=%v want hi", to)
			}
		}
	}
	if !found {
		t.Fatal("case did not journal branch_taken")
	}
}

// case falls through to the when:"true" branch when the guard is false.
func TestInterpreter_CaseFallthroughToTrueBranch(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_lo", caseGraph(), map[string]any{"x": 1}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["lo"] != 1 || router.calls["hi"] != 0 {
		t.Fatalf("x=1 (<=5) must fall through to lo: %v", router.calls)
	}
}

// replay copies the recorded branch_taken decision — it does not re-evaluate the guard
// (the basis for deterministic active-branch join, 17 §3).
func TestInterpreter_CaseReplay_CopiesDecision(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_cr", caseGraph(), map[string]any{"x": 10}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if _, err := New(journal, router).Resume(ctx, "fr_cr", caseGraph(), map[string]any{"x": 10}); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if router.calls["hi"] != 1 || router.calls["lo"] != 0 {
		t.Fatalf("replay must copy the branch decision (hi once, lo zero): %v", router.calls)
	}
}

// trigger -> case(loop head): while payload.n < 2, emit n+1 and back-edge to itself; else -> done.
// A structured loop via a case back-edge; counter rides in the payload (04 §loop).
func loopGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "loop",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.n < 2", "to": "c", "emit": map[string]any{"n": "payload.n + 1"}},
					map[string]any{"when": "true", "to": "done"},
				},
			}},
			{ID: "done", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "c"},
			{ID: "e2", From: "c", To: "c"},
			{ID: "e3", From: "c", To: "done"},
		},
	}
}

// the loop runs to exit; each case activation gets a distinct iteration_key (ADR-017 back-edge
// ordinal), so the per-iteration branch_taken events don't collide and `done` runs exactly once.
func TestInterpreter_StructuredLoop_IterationKey(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_loop", loopGraph(), map[string]any{"n": 0}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["done"] != 1 {
		t.Fatalf("done should run exactly once after the loop exits: %v", router.calls)
	}
	var iters []int
	for _, e := range mustLoad(t, journal, "fr_loop") {
		if e.Type == flowrundomain.EventBranchTaken && e.NodeID == "c" {
			iters = append(iters, e.IterationKey)
		}
	}
	if len(iters) != 3 || iters[0] != 0 || iters[1] != 1 || iters[2] != 2 {
		t.Fatalf("case branch_taken iteration_keys = %v, want [0 1 2]", iters)
	}
}

// replaying a completed loop copies every iteration's recorded decision/result — no re-run.
func TestInterpreter_LoopReplay_NoRerun(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()

	if _, err := New(journal, router).Run(ctx, "fr_lr", loopGraph(), map[string]any{"n": 0}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if _, err := New(journal, router).Resume(ctx, "fr_lr", loopGraph(), map[string]any{"n": 0}); err != nil {
		t.Fatalf("resume: %v", err)
	}
	if router.calls["done"] != 1 {
		t.Fatalf("replay must copy the loop (done once total): %v", router.calls)
	}
}

func mustLoad(t *testing.T, j *flowruneventstore.Store, id string) []flowrundomain.FlowRunEvent {
	t.Helper()
	evs, err := j.LoadJournal(context.Background(), id)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	return evs
}

// trigger -> f -> {a, b} -> j: an AND-split (f forks) and an AND-join (j awaits both a and b).
func andJoinGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "andjoin",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "f", Type: workflowdomain.NodeTypeFunction},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "b", Type: workflowdomain.NodeTypeFunction},
			{ID: "j", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "f"},
			{ID: "e2", From: "f", To: "a"},
			{ID: "e3", From: "f", To: "b"},
			{ID: "e4", From: "a", To: "j"},
			{ID: "e5", From: "b", To: "j"},
		},
	}
}

// AND-join (WP3): f forks to a+b; j awaits BOTH (forward in-degree 2) and runs exactly once.
func TestInterpreter_ANDJoin_AwaitsAll(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	if _, err := New(journal, router).Run(context.Background(), "fr_and", andJoinGraph(), nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	for _, n := range []string{"f", "a", "b", "j"} {
		if router.calls[n] != 1 {
			t.Fatalf("AND-join: %s ran %d times, want 1: %v", n, router.calls[n], router.calls)
		}
	}
}

// trigger -> case -> {a, b} -> j: a case diamond. case picks one branch; the join awaits only the
// activated in-edge (the skipped branch must not deadlock it — A-1, 17 §3 active-branch join).
func activeBranchGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "activebranch",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.x > 5", "to": "a"},
					map[string]any{"when": "true", "to": "b"},
				},
			}},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "b", Type: workflowdomain.NodeTypeFunction},
			{ID: "j", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "c"},
			{ID: "e2", From: "c", To: "a"},
			{ID: "e3", From: "c", To: "b"},
			{ID: "e4", From: "a", To: "j"},
			{ID: "e5", From: "b", To: "j"},
		},
	}
}

// the case-diamond the old engine dead-locked on: case picks a, b is skipped, j still fires with
// a's input — proving active-branch join does NOT wait for the skipped branch (A-1).
func TestInterpreter_ActiveBranchJoin_NoDeadlock(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	if _, err := New(journal, router).Run(context.Background(), "fr_ab", activeBranchGraph(), map[string]any{"x": 10}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["a"] != 1 || router.calls["b"] != 0 || router.calls["j"] != 1 {
		t.Fatalf("active-branch join: want a=1 b=0 j=1, got %v", router.calls)
	}
}

// trigger -> approval -> yes:dy / no:dn. approval routes via FromPort = decision.
func approvalGraph() workflowdomain.Graph {
	return workflowdomain.Graph{
		Name: "approval",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "ap", Type: workflowdomain.NodeTypeApproval},
			{ID: "dy", Type: workflowdomain.NodeTypeFunction},
			{ID: "dn", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "ap"},
			{ID: "e2", From: "ap", FromPort: "yes", To: "dy"},
			{ID: "e3", From: "ap", FromPort: "no", To: "dn"},
		},
	}
}

// approval parks the run (journals signal_awaited; caller sets status awaiting_signal) until a
// signal arrives — no downstream runs while parked.
func TestInterpreter_Approval_Parks(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	parked, err := New(journal, router).Run(context.Background(), "fr_ap", approvalGraph(), nil)
	if err != nil {
		t.Fatalf("run: %v", err)
	}
	if !parked {
		t.Fatal("approval must park the run")
	}
	if router.calls["dy"] != 0 || router.calls["dn"] != 0 {
		t.Fatalf("nothing downstream should run while parked: %v", router.calls)
	}
	found := false
	for _, e := range mustLoad(t, journal, "fr_ap") {
		if e.Type == flowrundomain.EventSignalAwaited && e.NodeID == "ap" {
			found = true
		}
	}
	if !found {
		t.Fatal("approval did not journal signal_awaited")
	}
}

// once the decision is journaled (signal_received), re-walking routes via the yes/no port and
// the run completes (durable approval = journal signal; the basis for crash-safe pause/resume).
func TestInterpreter_Approval_ResumeRoutesByDecision(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx := context.Background()
	if _, err := New(journal, router).Run(ctx, "fr_apr", approvalGraph(), nil); err != nil {
		t.Fatalf("park: %v", err)
	}
	if _, err := journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: "fr_apr", Type: flowrundomain.EventSignalReceived, NodeID: "ap",
		Result: map[string]any{"decision": "yes"},
	}); err != nil {
		t.Fatalf("inject signal: %v", err)
	}
	parked, err := New(journal, router).Resume(ctx, "fr_apr", approvalGraph(), nil)
	if err != nil {
		t.Fatalf("resume: %v", err)
	}
	if parked {
		t.Fatal("after the decision the run must complete, not park")
	}
	if router.calls["dy"] != 1 || router.calls["dn"] != 0 {
		t.Fatalf("decision=yes must route to dy: %v", router.calls)
	}
}

// A cancelled run ctx surfaces as context.Canceled from the walk (so executeRun maps it to
// cancelled), NOT swallowed into a NODE_FAILED (concurrency-error-edges-2).
func TestInterpreter_CancelledCtx_ReturnsCtxErr(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := New(journal, router).Run(ctx, "fr_cancel", linearGraph(), nil)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("cancelled ctx must surface context.Canceled, got %v", err)
	}
}

// A malformed emit CEL expression fails the case node (returned error) instead of silently
// writing nil into the payload field (cel-safety-2).
func TestInterpreter_EmitCompileError_FailsNode(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	g := workflowdomain.Graph{
		Name: "bad_emit",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "true", "to": "x", "emit": map[string]any{"bad": "payload.("}},
				},
			}},
		},
		Edges: []workflowdomain.EdgeSpec{{ID: "e1", From: "t", To: "c"}},
	}
	if _, err := New(journal, router).Run(context.Background(), "fr_bademit", g, nil); err == nil {
		t.Fatal("a malformed emit expr must fail the node, not silently write nil")
	}
}

// ctx is wired (17 §7 input = payload + ctx): a case guard reading ctx.runId routes correctly,
// proving the variable is populated — not the old declared-but-empty fail-to-false (cel-safety-3).
func TestInterpreter_CtxWired_GuardReadsRunId(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	g := workflowdomain.Graph{
		Name: "ctx_guard",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "ctx.runId == 'fr_ctx'", "to": "hit"},
					map[string]any{"when": "true", "to": "miss"},
				},
			}},
			{ID: "hit", Type: workflowdomain.NodeTypeFunction},
			{ID: "miss", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "c"},
			{ID: "e2", From: "c", To: "hit"},
			{ID: "e3", From: "c", To: "miss"},
		},
	}
	if _, err := New(journal, router).Run(context.Background(), "fr_ctx", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["hit"] != 1 || router.calls["miss"] != 0 {
		t.Fatalf("ctx.runId guard must route to hit (ctx wired, not empty): %v", router.calls)
	}
}

// A journaled number is reloaded as float64; without boundary normalization a downstream CEL
// `payload.n + 1` (double+int, no overload) errors → the guard silently fail-to-false and the run
// misroutes. Normalizing copy-hit numbers back to int64 keeps fresh and replayed arithmetic
// identical (cel-safety-1). Here `a` copy-hits a seeded node_completed carrying n=1.
func TestInterpreter_NumberCopyHit_StaysIntForCELArithmetic(t *testing.T) {
	journal := newJournal(t)
	ctx := context.Background()
	if _, err := journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: "fr_num", Type: flowrundomain.EventNodeCompleted, NodeID: "a", IterationKey: 0,
		Result: map[string]any{"n": 1},
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}
	router := &countingRouter{calls: map[string]int{}}
	g := workflowdomain.Graph{
		Name: "num",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.n + 1 == 2", "to": "done"},
					map[string]any{"when": "true", "to": "miss"},
				},
			}},
			{ID: "done", Type: workflowdomain.NodeTypeFunction},
			{ID: "miss", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "a"},
			{ID: "e2", From: "a", To: "c"},
			{ID: "e3", From: "c", To: "done"},
			{ID: "e4", From: "c", To: "miss"},
		},
	}
	if _, err := New(journal, router).Run(ctx, "fr_num", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["done"] != 1 || router.calls["miss"] != 0 {
		t.Fatalf("payload.n+1==2 over a journaled (float64) counter must hold as int: %v", router.calls)
	}
}

// numberRouter returns a JSON-style float64 output, as a real dispatcher does after decoding
// sandbox stdout — exercises the FRESH-output normalization (round-2: the asymmetric half).
type numberRouter struct{ n float64 }

func (r *numberRouter) Dispatch(_ context.Context, in DispatchInput) DispatchOutput {
	return DispatchOutput{Outputs: map[string]any{"n": r.n}}
}

// A FRESH activity output carrying a float64 must be normalized to int64 at the same boundary the
// copy-hit is, so a downstream CEL `payload.n + 1` works on the first (non-replay) run too.
func TestInterpreter_FreshActivityNumber_NormalizedForCEL(t *testing.T) {
	journal := newJournal(t)
	router := &numberRouter{n: 1}
	g := workflowdomain.Graph{
		Name: "fresh_num",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.n + 1 == 2", "to": "done"},
					map[string]any{"when": "true", "to": "miss"},
				},
			}},
			{ID: "done", Type: workflowdomain.NodeTypeFunction},
			{ID: "miss", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "a"},
			{ID: "e2", From: "a", To: "c"},
			{ID: "e3", From: "c", To: "done"},
			{ID: "e4", From: "c", To: "miss"},
		},
	}
	if _, err := New(journal, router).Run(context.Background(), "fr_fresh", g, nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	// 'a' is dispatched (not seeded), so this proves the FRESH path normalizes.
	if router2done := dispatchedTo(journal, t, "fr_fresh", "done"); !router2done {
		t.Fatal("fresh float64 activity output must normalize so `payload.n+1==2` routes to done")
	}
}

// dispatchedTo reports whether nodeID has a journaled node_completed (i.e. the branch ran).
func dispatchedTo(j *flowruneventstore.Store, t *testing.T, runID, nodeID string) bool {
	for _, e := range mustLoad(t, j, runID) {
		if e.NodeID == nodeID && e.Type == flowrundomain.EventNodeCompleted {
			return true
		}
	}
	return false
}

// A dryRun=true preview must NOT invoke the real dispatcher for side-effect nodes (function/...),
// yet the flow still completes via mock node_completed events (review R2 dryRun).
func TestInterpreter_DryRun_SkipsSideEffectDispatch(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	if _, err := New(journal, router).WithDryRun(true).Run(context.Background(), "fr_dry", linearGraph(), nil); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["a"] != 0 || router.calls["b"] != 0 {
		t.Fatalf("dry-run must NOT dispatch side-effect nodes, got %v", router.calls)
	}
	if !dispatchedTo(journal, t, "fr_dry", "b") {
		t.Fatal("dry-run should still journal a mock node_completed so the flow completes")
	}
}

// A loop whose body contains an ACTIVITY must carry the loop counter through that activity: the
// activity output merges onto the inbound payload rather than replacing it. Without merge the
// counter is dropped and the loop exits after one iteration (review R2 replay-3 / loop authoring).
func TestInterpreter_LoopBodyActivity_CounterSurvivesMerge(t *testing.T) {
	journal := newJournal(t)
	router := &countingRouter{calls: map[string]int{}}
	g := workflowdomain.Graph{
		Name: "loop_body",
		Nodes: []workflowdomain.NodeSpec{
			{ID: "t", Type: workflowdomain.NodeTypeTrigger},
			{ID: "c", Type: workflowdomain.NodeTypeCondition, Config: map[string]any{
				"branches": []any{
					map[string]any{"when": "payload.n < 2", "to": "a", "emit": map[string]any{"n": "payload.n + 1"}},
					map[string]any{"when": "true", "to": "done"},
				},
			}},
			{ID: "a", Type: workflowdomain.NodeTypeFunction},
			{ID: "done", Type: workflowdomain.NodeTypeFunction},
		},
		Edges: []workflowdomain.EdgeSpec{
			{ID: "e1", From: "t", To: "c"},
			{ID: "e2", From: "c", To: "a"},    // loop branch (n<2)
			{ID: "e3", From: "a", To: "c"},    // back-edge
			{ID: "e4", From: "c", To: "done"}, // exit branch
		},
	}
	if _, err := New(journal, router).Run(context.Background(), "fr_lba", g, map[string]any{"n": 0}); err != nil {
		t.Fatalf("run: %v", err)
	}
	if router.calls["a"] != 2 {
		t.Fatalf("loop-body activity must run once per iteration (counter survives merge): got %d", router.calls["a"])
	}
	if router.calls["done"] != 1 {
		t.Fatalf("done should run exactly once after the loop exits: got %d", router.calls["done"])
	}
}
