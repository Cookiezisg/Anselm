package approval_test

import (
	"context"
	"testing"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	approvalstore "github.com/sunweilin/forgify/backend/internal/infra/store/approval"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *approvalstore.Store {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := dbinfra.Migrate(gdb, approvalstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return approvalstore.New(gdb)
}

func ctxU() context.Context { return reqctxpkg.SetUserID(context.Background(), "u1") }

// Park is idempotent on replay: re-parking the same (flowrun, node) leaves a single row.
func TestPark_IdempotentOnReplay(t *testing.T) {
	s := newStore(t)
	ctx := ctxU()
	mk := func() *flowrundomain.Approval {
		return &flowrundomain.Approval{FlowrunID: "fr1", NodeID: "n1", Prompt: "ok?"}
	}
	if err := s.Park(ctx, mk()); err != nil {
		t.Fatalf("park 1: %v", err)
	}
	if err := s.Park(ctx, mk()); err != nil {
		t.Fatalf("park 2 (replay): %v", err)
	}
	parked, err := s.ListParked(ctx)
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(parked) != 1 {
		t.Fatalf("re-park must be idempotent: want 1 row, got %d", len(parked))
	}
}

// Decide flips one parked row out of the inbox; ListParked returns only still-parked rows.
func TestDecide_RemovesFromInbox(t *testing.T) {
	s := newStore(t)
	ctx := ctxU()
	_ = s.Park(ctx, &flowrundomain.Approval{FlowrunID: "fr1", NodeID: "n1"})
	_ = s.Park(ctx, &flowrundomain.Approval{FlowrunID: "fr1", NodeID: "n2"})
	if err := s.Decide(ctx, "fr1", "n1", flowrundomain.ApprovalApproved, "lgtm"); err != nil {
		t.Fatalf("decide: %v", err)
	}
	parked, _ := s.ListParked(ctx)
	if len(parked) != 1 || parked[0].NodeID != "n2" {
		t.Fatalf("after deciding n1, only n2 should remain parked: %+v", parked)
	}
}

// CancelParked flips every still-parked row of a flowrun to cancelled (inbox emptied).
func TestCancelParked_EmptiesInbox(t *testing.T) {
	s := newStore(t)
	ctx := ctxU()
	_ = s.Park(ctx, &flowrundomain.Approval{FlowrunID: "fr1", NodeID: "n1"})
	_ = s.Park(ctx, &flowrundomain.Approval{FlowrunID: "fr1", NodeID: "n2"})
	if err := s.CancelParked(ctx, "fr1"); err != nil {
		t.Fatalf("cancel: %v", err)
	}
	parked, _ := s.ListParked(ctx)
	if len(parked) != 0 {
		t.Fatalf("after cancel, inbox must be empty, got %d", len(parked))
	}
}
