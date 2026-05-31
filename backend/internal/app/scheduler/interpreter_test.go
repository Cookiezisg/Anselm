package scheduler

import (
	"context"
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

	if err := New(journal, router).Run(ctx, "fr_det", graph); err != nil {
		t.Fatalf("run: %v", err)
	}
	j1, _ := journal.LoadJournal(ctx, "fr_det")
	if router.calls["a"] != 1 || router.calls["b"] != 1 {
		t.Fatalf("first run should dispatch a,b exactly once: %v", router.calls)
	}

	// Replay on the SAME journal with a fresh interpreter (post-crash recovery).
	if err := New(journal, router).Resume(ctx, "fr_det", graph); err != nil {
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

	if err := New(journal, router).Run(ctx, "fr_lin", linearGraph()); err != nil {
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
