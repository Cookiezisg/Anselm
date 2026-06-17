package trigger

import (
	"context"
	"database/sql"
	"errors"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func newStore(t *testing.T) *Store {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

func mkTrigger(t *testing.T, s *Store, ctx context.Context, id, name, kind string, cfg map[string]any) {
	t.Helper()
	if err := s.SaveTrigger(ctx, &triggerdomain.Trigger{ID: id, Name: name, Kind: kind, Config: cfg}); err != nil {
		t.Fatalf("SaveTrigger %s: %v", id, err)
	}
}

func TestTrigger_RoundTrip_WorkspaceAndConfig(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkTrigger(t, s, ctx, "trg_1", "daily", triggerdomain.KindCron, map[string]any{"expression": "0 9 * * *"})
	got, err := s.GetTrigger(ctx, "trg_1")
	if err != nil {
		t.Fatalf("GetTrigger: %v", err)
	}
	if got.WorkspaceID != "ws_1" || got.Kind != triggerdomain.KindCron {
		t.Fatalf("round-trip meta: %+v", got)
	}
	if got.Config["expression"] != "0 9 * * *" {
		t.Fatalf("config json round-trip lost: %+v", got.Config)
	}
}

func TestTrigger_DuplicateName_And_Isolation(t *testing.T) {
	s := newStore(t)
	mkTrigger(t, s, ctxWS("ws_1"), "trg_1", "dup", triggerdomain.KindCron, map[string]any{"expression": "* * * * *"})
	err := s.SaveTrigger(ctxWS("ws_1"), &triggerdomain.Trigger{ID: "trg_2", Name: "dup", Kind: triggerdomain.KindCron, Config: map[string]any{}})
	if !errors.Is(err, triggerdomain.ErrDuplicateName) {
		t.Fatalf("want ErrDuplicateName, got %v", err)
	}
	mkTrigger(t, s, ctxWS("ws_2"), "trg_3", "dup", triggerdomain.KindCron, map[string]any{}) // same name OK in another ws
	if _, err := s.GetTrigger(ctxWS("ws_2"), "trg_1"); !errors.Is(err, triggerdomain.ErrNotFound) {
		t.Fatalf("cross-workspace read should be NotFound, got %v", err)
	}
}

func TestFiring_Dedup(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	first, err := s.AppendFiring(ctx, &triggerdomain.Firing{
		TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k1",
		Payload: map[string]any{"n": float64(1)},
	})
	if err != nil {
		t.Fatalf("AppendFiring 1: %v", err)
	}
	// Same (workflow, trigger, dedupKey) → returns the existing row, not a new one.
	dup, err := s.AppendFiring(ctx, &triggerdomain.Firing{
		TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k1",
		Payload: map[string]any{"n": float64(2)},
	})
	if err != nil {
		t.Fatalf("AppendFiring 2: %v", err)
	}
	if dup.ID != first.ID {
		t.Fatalf("dedup should return existing firing %s, got %s", first.ID, dup.ID)
	}
}

func TestFiring_ClaimSingleTx(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	f, err := s.AppendFiring(ctx, &triggerdomain.Firing{TriggerID: "trg_1", WorkflowID: "wf_1", DedupKey: "k1"})
	if err != nil {
		t.Fatalf("AppendFiring: %v", err)
	}
	frID, err := s.ClaimFiring(ctx, f.ID, func(tx *ormpkg.DB) (string, error) {
		return "fr_run1", nil // scheduler builds the flowrun here
	})
	if err != nil || frID != "fr_run1" {
		t.Fatalf("ClaimFiring: id=%q err=%v", frID, err)
	}
	got, err := s.frs.Get(ctx, f.ID)
	if err != nil {
		t.Fatalf("reload firing: %v", err)
	}
	if got.Status != triggerdomain.FiringStarted || got.FlowrunID != "fr_run1" {
		t.Fatalf("post-claim firing: status=%s flowrun=%s", got.Status, got.FlowrunID)
	}
	// Second claim loses the race — already started, not pending.
	if _, err := s.ClaimFiring(ctx, f.ID, func(tx *ormpkg.DB) (string, error) { return "fr_run2", nil }); !errors.Is(err, triggerdomain.ErrFiringNotPending) {
		t.Fatalf("second claim should be ErrFiringNotPending, got %v", err)
	}
}

func TestActivation_AppendAndSearch(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	must := func(a *triggerdomain.Activation) {
		t.Helper()
		if err := s.AppendActivation(ctx, a); err != nil {
			t.Fatalf("AppendActivation: %v", err)
		}
	}
	must(&triggerdomain.Activation{TriggerID: "trg_1", Kind: triggerdomain.KindSensor, Fired: false, ReturnValue: map[string]any{"count": float64(0)}, Detail: "condition false"})
	must(&triggerdomain.Activation{TriggerID: "trg_1", Kind: triggerdomain.KindSensor, Fired: true, Payload: map[string]any{"x": float64(1)}, FiringCount: 2})
	must(&triggerdomain.Activation{TriggerID: "trg_other", Kind: triggerdomain.KindCron, Fired: true})

	all, _, err := s.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: "trg_1"})
	if err != nil || len(all) != 2 {
		t.Fatalf("search trg_1: n=%d err=%v", len(all), err)
	}
	firedOnly, _, err := s.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: "trg_1", FiredOnly: true})
	if err != nil || len(firedOnly) != 1 || !firedOnly[0].Fired {
		t.Fatalf("FiredOnly: n=%d err=%v", len(firedOnly), err)
	}
	// Non-fired activation kept its observed return value for debugging "why didn't it fire".
	misses, _, _ := s.SearchActivations(ctx, triggerdomain.ActivationFilter{TriggerID: "trg_1"})
	var miss *triggerdomain.Activation
	for _, a := range misses {
		if !a.Fired {
			miss = a
		}
	}
	if miss == nil || miss.ReturnValue["count"] != float64(0) {
		t.Fatalf("non-fired activation should keep ReturnValue: %+v", miss)
	}
}
