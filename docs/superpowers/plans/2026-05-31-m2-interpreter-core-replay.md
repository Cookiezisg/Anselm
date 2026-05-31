# M2 — Interpreter Core + Crash-Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline). Steps use checkbox (`- [ ]`) syntax. This is the承重 milestone — the replay-determinism property test is the gate; write it first and keep it green through every later task.

**Goal:** Replace the topo-walk scheduler with a durable interpreter that walks a pinned graph, journals each activity, and replays deterministically — for **linear (sequence) flows only** (case/fork-join/loop = M3, approval = M4).

**Architecture:** One goroutine walks the pinned graph from the trigger node. Each agent/tool node is an **activity**: journal `node_started` → `Router.Dispatch` → journal `node_completed`(Outputs) or `node_failed`(Error). `Run` (fresh) and `Resume` (post-crash) share **one loop**: before executing a step, look up its highest-generation record-once event (ADR-019 copy-hit) via the M1 journal — hit `node_completed` ⇒ copy result, **do not call Dispatch**; miss ⇒ run + journal. The journal (`flowrunevent.Store`, M1) is the only state; `ExecutionContext`/`PausedState`/topo machinery are deleted (ADR-016).

**Tech Stack:** Go, the M1 `flowruneventstore` + `flowrundomain` journal, the existing `Router`/`Dispatcher` contract (`DispatchInput{Node,NodeIn,ExecCtx}`→`DispatchOutput{Outputs,NextPort,Error}`), in-mem SQLite tests.

**Contract:** `17` §3 (linear subset)/§4 (replay) + ADR-016/017/019.

---

## Scope (M2 only)

- **In:** trigger entry; tool/agent nodes as journaled activities; single-out-edge sequential walk; `Run` + `Resume`; crash-replay copy-hit; the replay-determinism property test; linear pipeline test. Delete topo/pause/rehydrate/subdag + `PausedState`.
- **Out (later milestones):** `case`/`branch_taken`/fork-join/loop/`iteration_key`>0 (M3); `approval`/`signal_*`/timer (M4); trigger inbox/dispatcher (M5); `:replay`/generation++/drain (M6); agent sub-step replay (M7). In M2 every activity has `iteration_key=0`, `generation=0`.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `backend/internal/app/scheduler/interpreter.go` | the durable interpreter: `Run`/`Resume` + the walk loop + activity journaling + copy-hit | Create |
| `backend/internal/app/scheduler/interpreter_test.go` | **replay-determinism property test** (命脉) + linear-walk unit tests | Create |
| `backend/internal/app/scheduler/scheduler.go` | `StartRun` stays; `executeRun` → calls interpreter; drop `ExecuteFn` pluggability | Modify |
| `backend/internal/app/scheduler/state.go` | topo + `ExecutionContext` | **Delete** (fold the minimal `ExecutionContext` the `Dispatcher` interface still needs into interpreter.go, or keep a slim struct — confirm refs at execution) |
| `backend/internal/app/scheduler/pause.go` / `rehydrate.go` / `subdag.go` | pause-snapshot + topo drive + sub-dag | **Delete** |
| `backend/internal/app/scheduler/retry.go` | per-node retry/timeout wrap | **Keep** (reused by the activity executor; the skipped stale test there dies here too — delete `TestNodeTimeoutDuration_DefaultByType`) |
| `backend/internal/domain/flowrun/flowrun.go` | drop `PausedState` field + struct + the 3 paused sentinels | Modify |
| `backend/internal/infra/store/flowrun/flowrun.go` | drop `SetPausedState`/`ClearPausedState`/`ListPaused` from port+impl | Modify |
| `backend/cmd/server/main.go` | drop `RehydrateOnBoot` paused-scan call; interpreter wiring | Modify |

> **Execution-time grounding (read before editing):** `scheduler.go` (`StartRun`/`executeRun`/`Service`), `state.go` (`ExecutionContext` fields the `Dispatcher`s read), `retry.go` (`dispatchWithPolicies` signature), `pause.go` (`continueRun` — confirm nothing else calls it), and `grep -rn ExecutionContext|PausedState|ListPaused|RehydrateOnBoot` to find every ref before deleting. The dispatchers (`dispatch_*.go`) keep their `Dispatcher` interface; M2 only exercises function/handler (as the `tool` activity) — node-type collapse to 5 kinds is M3.

---

## Task 1: Replay-determinism property test [命脉, RED first]

**Files:** Create `backend/internal/app/scheduler/interpreter_test.go`

- [ ] **Step 1: Write the property test against a counting fake dispatcher.**

The test builds a 2-activity linear graph, runs it (counting Dispatch calls + capturing the journal), then **replays with a fresh interpreter on the same journal** and asserts: (a) identical event sequence (type+node+seq), (b) **Dispatch call count does not increase** (replay copies, never re-runs).

```go
package scheduler

import (
	"context"
	"testing"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	flowruneventstore "github.com/sunweilin/forgify/backend/internal/infra/store/flowrunevent"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// countingRouter records how many times each node was actually dispatched.
type countingRouter struct{ calls map[string]int }

func (c *countingRouter) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	c.calls[in.Node.ID]++
	return DispatchOutput{Outputs: map[string]any{"echo": in.Node.ID}, NextPort: ""}
}

// linearGraph: trigger(t) -> tool(a) -> tool(b). (helper builds workflowdomain.Graph)
func linearGraph() workflowdomain.Graph { /* nodes t,a,b + edges t->a, a->b; complete at execution */ }

func TestInterpreter_ReplayIsDeterministicAndCopiesNotReruns(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil { t.Fatal(err) }
	if err := dbinfra.Migrate(gdb, flowruneventstore.AutoMigrateModels()...); err != nil { t.Fatal(err) }
	journal := flowruneventstore.New(gdb)
	router := &countingRouter{calls: map[string]int{}}
	graph := linearGraph()
	ctx := context.Background()

	// First run: executes both activities once.
	in1 := New(journal, router) // interpreter constructor
	if err := in1.Run(ctx, "fr_det", graph); err != nil { t.Fatalf("run: %v", err) }
	j1, _ := journal.LoadJournal(ctx, "fr_det")
	if router.calls["a"] != 1 || router.calls["b"] != 1 {
		t.Fatalf("first run should dispatch a,b once: %v", router.calls)
	}

	// Replay on the SAME journal with a fresh interpreter: must copy, not re-dispatch.
	in2 := New(journal, router)
	if err := in2.Resume(ctx, "fr_det", graph); err != nil { t.Fatalf("resume: %v", err) }
	if router.calls["a"] != 1 || router.calls["b"] != 1 {
		t.Fatalf("replay re-ran an already-journaled activity: %v", router.calls)
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
```

- [ ] **Step 2: Run — verify RED** (`New`/`Run`/`Resume` undefined).

Run: `cd backend && go test ./internal/app/scheduler/ -run TestInterpreter_Replay -v`
Expected: FAIL (build: undefined New/Run/Resume).

---

## Task 2: Interpreter — linear walk + activity journaling [make Task 1's first-run pass]

**Files:** Create `backend/internal/app/scheduler/interpreter.go`

- [ ] **Step 1: Implement `New`, `Run`, and the walk that journals activities.**

Core loop (concrete; the activity executor reuses `retry.go`'s wrap during execution-time wiring):
```go
package scheduler

import (
	"context"
	"fmt"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

type Interpreter struct {
	journal  flowrundomain.JournalRepository
	dispatch Dispatcher // Router satisfies this
}

func New(journal flowrundomain.JournalRepository, dispatch Dispatcher) *Interpreter {
	return &Interpreter{journal: journal, dispatch: dispatch}
}

// Run executes a fresh flowrun; Resume replays an existing one. Identical loop —
// both consult the journal before each activity, so Run is just Resume on an empty journal.
func (in *Interpreter) Run(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	return in.walk(ctx, flowrunID, g)
}
func (in *Interpreter) Resume(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	return in.walk(ctx, flowrunID, g)
}

func (in *Interpreter) walk(ctx context.Context, flowrunID string, g workflowdomain.Graph) error {
	events, err := in.journal.LoadJournal(ctx, flowrunID)
	if err != nil { return err }
	done := completedResults(events) // map[nodeID]result for iteration_key=0,gen=0 (M2 linear)

	node := triggerNode(g)
	payload := map[string]any{} // M2: trigger payload comes from flowrun.input in execution wiring
	for {
		next, out, runErr := in.step(ctx, flowrunID, g, node, payload, done)
		if runErr != nil { return runErr }
		if next == nil { return nil } // no successor = terminal (WP11, M2 linear)
		node, payload = next, out
	}
}

// step runs (or copies) one node and returns its successor + output payload.
func (in *Interpreter) step(ctx context.Context, flowrunID string, g workflowdomain.Graph,
	node workflowdomain.NodeSpec, payload map[string]any, done map[string]any) (*workflowdomain.NodeSpec, map[string]any, error) {

	if node.Type == workflowdomain.NodeTypeTrigger {
		return successor(g, node, ""), payload, nil // entry, not an activity
	}
	// activity: copy-hit or run
	if cached, ok := done[node.ID]; ok {
		return successor(g, node, ""), asMap(cached), nil // ADR-019 copy-hit: no Dispatch
	}
	if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: flowrunID, Type: flowrundomain.EventNodeStarted, NodeID: node.ID,
	}); err != nil { return nil, nil, err }

	res := in.dispatch.Dispatch(ctx, DispatchInput{Node: node, NodeIn: payload})
	if res.Error != nil {
		_, _ = in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
			FlowrunID: flowrunID, Type: flowrundomain.EventNodeFailed, NodeID: node.ID,
			Result: map[string]any{"error": res.Error.Error()},
		})
		return nil, nil, fmt.Errorf("scheduler.step %s: %w", node.ID, res.Error)
	}
	if _, err := in.journal.AppendEvent(ctx, &flowrundomain.FlowRunEvent{
		FlowrunID: flowrunID, Type: flowrundomain.EventNodeCompleted, NodeID: node.ID,
		Result: res.Outputs,
	}); err != nil { return nil, nil, err }
	return successor(g, node, res.NextPort), res.Outputs, nil
}
```
Helpers to implement in the same file: `completedResults` (highest-gen `node_completed` per nodeID — M2: gen0/iter0 only), `triggerNode`, `successor(g, node, port)` (single out-edge for M2; multi-edge = M3), `asMap`. Use exact `workflowdomain.Graph`/`NodeSpec`/`EdgeSpec` field names read at execution.

- [ ] **Step 2: Run — Task 1 first-run assertions pass; replay assertions may still fail until copy-hit verified.**

Run: `cd backend && go test ./internal/app/scheduler/ -run TestInterpreter_Replay -v`
Expected: PASS (the copy-hit via `done` map makes replay copy, not re-dispatch).

- [ ] **Step 3: Commit.**

```bash
git add backend/internal/app/scheduler/interpreter.go backend/internal/app/scheduler/interpreter_test.go
git commit -m "feat(scheduler): durable interpreter — linear walk + activity journaling + replay copy-hit (M2, TDD, ADR-016/019)"
```

---

## Task 3: Wire `StartRun` → interpreter; delete topo/pause machinery

**Files:** Modify `scheduler.go`, `main.go`; Delete `state.go`/`pause.go`/`rehydrate.go`/`subdag.go`; Modify `flowrun.go` (domain+store)

- [ ] **Step 1: Read the seams.** `grep -rn 'ExecutionContext\|PausedState\|ListPaused\|RehydrateOnBoot\|continueRun\|driveLoop\|buildTopo' backend/internal backend/cmd` — enumerate every reference before deleting.
- [ ] **Step 2: Rewrite `executeRun`** to load the pinned graph + `flowrun.input`, construct `New(journalRepo, router)`, call `Run`; on terminal set `flowrun.status=completed` (single terminal write), on activity error `failed`. Drop the `ExecuteFn` field.
- [ ] **Step 3: Delete** `state.go`/`pause.go`/`rehydrate.go`/`subdag.go` and the `ExecutionContext`-only bits the `Dispatcher` no longer needs (if `DispatchInput.ExecCtx` is still referenced by dispatchers, keep a minimal `ExecutionContext{}` shim in interpreter.go until M3 collapses dispatchers). Delete `PausedState` struct+field + `ErrNotPaused`/`ErrApprovalNodeNotFound`/`ErrApprovalDecisionInvalid` sentinels; drop `SetPausedState`/`ClearPausedState`/`ListPaused` from the flowrun repo port+impl. Remove the `RehydrateOnBoot` paused-scan from `main.go` (boot replay of unfinished flowruns is M5/M6; M2 leaves a TODO-free stub or removes the call).
- [ ] **Step 4: Build + full gate.** `cd backend && go build ./... && go vet ./... ; /Users/SP14921/go/bin/staticcheck ./internal/app/scheduler/ ./internal/domain/flowrun/`. Fix every compile ref the deletions broke. Delete the stale `TestNodeTimeoutDuration_DefaultByType` (skipped in M1).
- [ ] **Step 5: Commit.** `git commit -m "refactor(scheduler): interpreter replaces topo-walk; delete pause/rehydrate/subdag + PausedState (M2, ADR-016)"`

---

## Task 4: Linear pipeline test + M2 gate

**Files:** Create `backend/test/durable/linear_pipeline_test.go`

- [ ] **Step 1: Write an end-to-end linear pipeline test** (T5) via `harness.New(t)`: seed a workflow with trigger→tool(function)→tool, `StartRun`, assert `flowrun.status=completed` + the journal has `node_started`/`node_completed` per activity in seq order. (Use a fake/echo function callable; full callable wiring exists.)
- [ ] **Step 2: Run** `go test ./test/durable/ -run TestLinear -v` → PASS.
- [ ] **Step 3: Full gate** — `make unit` + `make mock` + `staticcheck` green (paste output, verification-before-completion).
- [ ] **Step 4:** Update IMPLEMENTATION-LOG (M2 done: interpreter + replay determinism proven; old scheduler deleted) + changelog dev-log. Commit + push.

---

## Self-Review

**Spec coverage (M2 task #3 + 17 §3-linear/§4):** linear walk ✓ (T2); activity journaling node_started/completed/failed ✓ (T2); replay copy-hit (ADR-019, gen0/iter0) ✓ (T2 + the命脉 test T1); Run/Resume one loop ✓ (T2); delete topo/pause/rehydrate/subdag + PausedState ✓ (T3); linear pipeline ✓ (T4). Gaps (intentional, later milestones): branch_taken/fork-join/loop (M3), approval/timer (M4), boot-replay of unfinished runs (M5/M6), agent sub-step (M7).

**Placeholder scan:** `linearGraph()`/`completedResults`/`successor`/`triggerNode`/`asMap` bodies + exact `workflowdomain.Graph`/`NodeSpec`/`EdgeSpec` field names are execution-time (read `domain/workflow/{version,node,edge}.go` first) — flagged, not silent TODOs. The `ExecutionContext` shim decision (keep-minimal vs delete) is resolved by the T3-Step1 grep. These are the only deferred resolutions; the命脉 test (T1) is fully code-complete.

**Type consistency:** `New(journal, dispatch)` ↔ used in T1 test + T2 impl ✓; `Run`/`Resume`/`walk`/`step` signatures consistent ✓; `Dispatcher`/`DispatchInput`/`DispatchOutput` match the real contract (read from dispatcher.go) ✓; event types (`EventNodeStarted`/`Completed`/`Failed`) match M1's `flowrundomain` consts ✓; `JournalRepository.AppendEvent`/`LoadJournal` match M1's port ✓.
