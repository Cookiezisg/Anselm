package scheduler

import (
	"context"
	"testing"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	flowrunstore "github.com/sunweilin/forgify/backend/internal/infra/store/flowrun"
	triggerstore "github.com/sunweilin/forgify/backend/internal/infra/store/trigger"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
)

// The durable trigger chain: OnTriggerFired persists a firing, then the single-tx claim (ADR-021)
// creates EXACTLY ONE flowrun atomically with claiming the firing. A re-dispatch (boot catchup)
// must NOT create a duplicate — the firing is already started, not pending.
func TestDispatchPending_SingleTxClaim_CreatesFlowrunExactlyOnce(t *testing.T) {
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := dbinfra.Migrate(gdb, &flowrundomain.FlowRun{}, &flowrundomain.Node{}, &triggerdomain.TriggerFiring{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	repo := flowrunstore.New(gdb)
	s := NewService(repo, &fakeWorkflowReader{wf: mkEnabledWorkflow(), ver: mkVersion()},
		notificationspkg.New(nil, zap.NewNop()), zap.NewNop())
	s.SetFiringInbox(triggerstore.New(gdb))
	s.ExecuteFn = func(context.Context, *flowrundomain.FlowRun, *workflowdomain.Graph) {} // noop: assert the create, not the run
	ctx := ctxWith("u1")

	if err := s.OnTriggerFired(ctx, &triggerdomain.TriggerFiring{
		WorkflowID: "wf1", TriggerNodeID: "trig", TriggerKind: "manual", DedupKey: "k1",
	}); err != nil {
		t.Fatalf("OnTriggerFired: %v", err)
	}
	runs, _, _ := repo.List(ctx, flowrundomain.ListFilter{})
	if len(runs) != 1 {
		t.Fatalf("single-tx claim must create exactly one flowrun, got %d", len(runs))
	}

	// Boot catchup re-drain: the firing is now started (not pending) → no duplicate run.
	s.DispatchPending(ctx)
	runs2, _, _ := repo.List(ctx, flowrundomain.ListFilter{})
	if len(runs2) != 1 {
		t.Fatalf("re-dispatch must not create a duplicate run, got %d", len(runs2))
	}
}
