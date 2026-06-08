package workflow

import (
	"context"
	"database/sql"
	"errors"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
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

// mkWf inserts a workflow with valid CHECK-passing defaults.
func mkWf(t *testing.T, s *Store, ctx context.Context, id, name, activeVer string) {
	t.Helper()
	w := &workflowdomain.Workflow{
		ID: id, Name: name, ActiveVersionID: activeVer, Tags: []string{},
		LifecycleState: workflowdomain.LifecycleInactive,
		Concurrency:    workflowdomain.ConcurrencySerial,
		LastActionBy:   workflowdomain.ActorUser,
	}
	if err := s.SaveWorkflow(ctx, w); err != nil {
		t.Fatalf("SaveWorkflow %s: %v", id, err)
	}
}

func mkVer(t *testing.T, s *Store, ctx context.Context, id, wfID string, n int) {
	t.Helper()
	v := &workflowdomain.Version{ID: id, WorkflowID: wfID, Version: n, Graph: `{"nodes":[],"edges":[]}`}
	if err := s.SaveVersion(ctx, v); err != nil {
		t.Fatalf("SaveVersion %s: %v", id, err)
	}
}

func TestWorkflow_RoundTrip_WorkspaceFilled(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "pipeline", "")
	got, err := s.GetWorkflow(ctx, "wf_1")
	if err != nil {
		t.Fatalf("GetWorkflow: %v", err)
	}
	if got.Name != "pipeline" || got.WorkspaceID != "ws_1" {
		t.Fatalf("round-trip: %+v", got)
	}
	if got.LifecycleState != workflowdomain.LifecycleInactive || got.Concurrency != workflowdomain.ConcurrencySerial {
		t.Fatalf("lifecycle/concurrency not round-tripped: %+v", got)
	}
	if got.CreatedAt.IsZero() {
		t.Error("created_at not auto-stamped")
	}
}

func TestWorkflow_GraphRoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	graph := `{"nodes":[{"id":"t","kind":"trigger","ref":"trg_a"}],"edges":[]}`
	v := &workflowdomain.Version{ID: "wfv_1", WorkflowID: "wf_1", Version: 1, Graph: graph}
	if err := s.SaveVersion(ctx, v); err != nil {
		t.Fatalf("SaveVersion: %v", err)
	}
	got, err := s.GetVersion(ctx, "wfv_1")
	if err != nil {
		t.Fatalf("GetVersion: %v", err)
	}
	if got.Graph != graph {
		t.Fatalf("graph blob not round-tripped: %q", got.Graph)
	}
}

func TestWorkflow_DuplicateName(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "dup", "")
	w := &workflowdomain.Workflow{
		ID: "wf_2", Name: "dup", Tags: []string{},
		LifecycleState: workflowdomain.LifecycleInactive, Concurrency: workflowdomain.ConcurrencySerial, LastActionBy: workflowdomain.ActorUser,
	}
	if err := s.SaveWorkflow(ctx, w); !errors.Is(err, workflowdomain.ErrDuplicateName) {
		t.Fatalf("want ErrDuplicateName, got %v", err)
	}
}

func TestWorkflow_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	mkWf(t, s, ctxWS("ws_1"), "wf_1", "a", "")
	mkWf(t, s, ctxWS("ws_2"), "wf_2", "a", "") // same name OK in another workspace
	if _, err := s.GetWorkflow(ctxWS("ws_2"), "wf_1"); !errors.Is(err, workflowdomain.ErrNotFound) {
		t.Fatalf("cross-workspace read should be NotFound, got %v", err)
	}
}

func TestWorkflow_SoftDelete(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "a", "")
	if err := s.DeleteWorkflow(ctx, "wf_1"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.GetWorkflow(ctx, "wf_1"); !errors.Is(err, workflowdomain.ErrNotFound) {
		t.Fatalf("deleted should be NotFound, got %v", err)
	}
	if err := s.DeleteWorkflow(ctx, "wf_1"); !errors.Is(err, workflowdomain.ErrNotFound) {
		t.Fatalf("re-delete should be NotFound, got %v", err)
	}
}

func TestWorkflow_ListPagination(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	for i := range 5 {
		mkWf(t, s, ctx, "wf_"+string(rune('a'+i)), "n"+string(rune('a'+i)), "")
		time.Sleep(time.Millisecond)
	}
	page1, next, err := s.ListWorkflows(ctx, workflowdomain.ListFilter{Limit: 2})
	if err != nil || len(page1) != 2 || next == "" {
		t.Fatalf("page1: rows=%d next=%q err=%v", len(page1), next, err)
	}
	page2, _, err := s.ListWorkflows(ctx, workflowdomain.ListFilter{Limit: 2, Cursor: next})
	if err != nil || len(page2) != 2 {
		t.Fatalf("page2: rows=%d err=%v", len(page2), err)
	}
	if page1[0].ID == page2[0].ID {
		t.Fatal("pages overlap")
	}
}

func TestWorkflow_VersionMaxAndByNumber(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "a", "")
	if n, err := s.MaxVersionNumber(ctx, "wf_1"); err != nil || n != 0 {
		t.Fatalf("max with no versions: n=%d err=%v", n, err)
	}
	mkVer(t, s, ctx, "wfv_1", "wf_1", 1)
	mkVer(t, s, ctx, "wfv_2", "wf_1", 2)
	if n, err := s.MaxVersionNumber(ctx, "wf_1"); err != nil || n != 2 {
		t.Fatalf("max: n=%d err=%v", n, err)
	}
	v, err := s.GetVersionByNumber(ctx, "wf_1", 2)
	if err != nil || v.ID != "wfv_2" {
		t.Fatalf("by number: %+v err=%v", v, err)
	}
	if _, err := s.GetVersionByNumber(ctx, "wf_1", 9); !errors.Is(err, workflowdomain.ErrVersionNotFound) {
		t.Fatalf("missing number should be ErrVersionNotFound, got %v", err)
	}
}

func TestWorkflow_TrimProtectsActive(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "a", "wfv_1") // active = v1 (oldest), as after a revert
	for i := 1; i <= 5; i++ {
		mkVer(t, s, ctx, "wfv_"+string(rune('0'+i)), "wf_1", i)
	}
	if err := s.TrimOldestVersions(ctx, "wf_1", 3); err != nil {
		t.Fatalf("trim: %v", err)
	}
	if _, err := s.GetVersion(ctx, "wfv_1"); err != nil {
		t.Fatalf("active v1 must survive trim, got %v", err)
	}
	if _, err := s.GetVersion(ctx, "wfv_2"); !errors.Is(err, workflowdomain.ErrVersionNotFound) {
		t.Fatalf("v2 should be trimmed, got %v", err)
	}
	if _, err := s.GetVersion(ctx, "wfv_3"); err != nil {
		t.Fatalf("v3 should survive, got %v", err)
	}
}

func TestWorkflow_SetActiveVersion(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "a", "wfv_1")
	if err := s.SetActiveVersion(ctx, "wf_1", "wfv_2"); err != nil {
		t.Fatalf("SetActiveVersion: %v", err)
	}
	got, _ := s.GetWorkflow(ctx, "wf_1")
	if got.ActiveVersionID != "wfv_2" {
		t.Fatalf("active not moved: %q", got.ActiveVersionID)
	}
	if err := s.SetActiveVersion(ctx, "wf_missing", "wfv_x"); !errors.Is(err, workflowdomain.ErrNotFound) {
		t.Fatalf("missing workflow should be NotFound, got %v", err)
	}
}

func TestWorkflow_UpdateMetaAndActiveList(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_1", "a", "")
	mkWf(t, s, ctx, "wf_2", "b", "")

	yes := true
	if err := s.UpdateWorkflowMeta(ctx, "wf_1", workflowdomain.MetaUpdate{
		Active:         &yes,
		LifecycleState: ptr(workflowdomain.LifecycleActive),
		LastActionBy:   ptr(workflowdomain.ActorSystem),
	}); err != nil {
		t.Fatalf("UpdateWorkflowMeta: %v", err)
	}
	got, _ := s.GetWorkflow(ctx, "wf_1")
	if !got.Active || got.LifecycleState != workflowdomain.LifecycleActive || got.LastActionBy != workflowdomain.ActorSystem {
		t.Fatalf("meta not updated: %+v", got)
	}

	active, err := s.ListActiveWorkflows(ctx)
	if err != nil || len(active) != 1 || active[0].ID != "wf_1" {
		t.Fatalf("ListActiveWorkflows: %v rows=%v", err, active)
	}

	// Empty patch is a no-op (no error, no row change).
	if err := s.UpdateWorkflowMeta(ctx, "wf_1", workflowdomain.MetaUpdate{}); err != nil {
		t.Fatalf("empty patch should be no-op, got %v", err)
	}
	// Missing workflow is NotFound.
	if err := s.UpdateWorkflowMeta(ctx, "wf_missing", workflowdomain.MetaUpdate{Active: &yes}); !errors.Is(err, workflowdomain.ErrNotFound) {
		t.Fatalf("missing workflow should be NotFound, got %v", err)
	}
}

func TestWorkflow_GetByIDsPreservesOrder(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	mkWf(t, s, ctx, "wf_a", "a", "")
	mkWf(t, s, ctx, "wf_b", "b", "")
	rows, err := s.GetWorkflowsByIDs(ctx, []string{"wf_b", "wf_a", "wf_missing"})
	if err != nil {
		t.Fatalf("GetWorkflowsByIDs: %v", err)
	}
	if len(rows) != 2 || rows[0].ID != "wf_b" || rows[1].ID != "wf_a" {
		t.Fatalf("order not preserved / missing not skipped: %v", rows)
	}
}

func ptr[T any](v T) *T { return &v }
