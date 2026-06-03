package agent

import (
	"context"
	"testing"
	"time"

	"go.uber.org/zap"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	dbinfra "github.com/sunweilin/forgify/backend/internal/infra/db"
	agentstore "github.com/sunweilin/forgify/backend/internal/infra/store/agent"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newSvcWithStore(t *testing.T) (*Service, *agentstore.Store) {
	t.Helper()
	gdb, err := dbinfra.Open(dbinfra.Config{DataDir: ""})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	if err := dbinfra.Migrate(gdb, agentstore.AutoMigrateModels()...); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	st := agentstore.New(gdb)
	return New(st, zap.NewNop()), st
}

// TestSearchAndGetExecution covers the execution-log surface (mirrors function executions) without
// needing an LLM: a row saved via the store is found by SearchExecutions + GetExecutionDetail.
func TestSearchAndGetExecution(t *testing.T) {
	svc, st := newSvcWithStore(t)
	ctx := reqctxpkg.SetUserID(context.Background(), "u_test")

	a, _, err := svc.Create(ctx, CreateInput{Name: "classifier", Prompt: "classify"})
	if err != nil {
		t.Fatalf("create agent: %v", err)
	}

	now := time.Now().UTC()
	if err := st.SaveExecution(ctx, &agentdomain.AgentExecution{
		Status: agentdomain.ExecutionStatusOK, TriggeredBy: agentdomain.TriggeredByChat,
		Input: map[string]any{"text": "great"}, Output: "positive",
		ElapsedMs: 42, StartedAt: now, EndedAt: now,
		AgentID: a.ID, VersionID: a.ActiveVersionID,
	}); err != nil {
		t.Fatalf("save execution: %v", err)
	}

	res, err := svc.SearchExecutions(ctx, agentdomain.ExecutionFilter{AgentID: a.ID})
	if err != nil {
		t.Fatalf("SearchExecutions: %v", err)
	}
	if res.Count != 1 || len(res.Executions) != 1 {
		t.Fatalf("expected 1 execution, got %d", res.Count)
	}
	if res.Aggregates.OKCount != 1 {
		t.Errorf("aggregates OKCount = %d, want 1", res.Aggregates.OKCount)
	}

	detail, err := svc.GetExecutionDetail(ctx, res.Executions[0].ID)
	if err != nil {
		t.Fatalf("GetExecutionDetail: %v", err)
	}
	if detail.Status != agentdomain.ExecutionStatusOK {
		t.Errorf("detail status = %q", detail.Status)
	}
}

// TestGetExecutionDetail_NotFound returns the typed sentinel (mirrors function ErrExecutionNotFound).
func TestGetExecutionDetail_NotFound(t *testing.T) {
	svc, _ := newSvcWithStore(t)
	ctx := reqctxpkg.SetUserID(context.Background(), "u_test")
	_, err := svc.GetExecutionDetail(ctx, "agx_missing")
	if err == nil {
		t.Fatalf("expected ErrExecutionNotFound, got nil")
	}
}

// TestRevert flips the active version back to a prior accepted version number (mirrors function.Revert).
func TestRevert(t *testing.T) {
	svc, _ := newSvcWithStore(t)
	ctx := reqctxpkg.SetUserID(context.Background(), "u_test")

	a, v1, err := svc.Create(ctx, CreateInput{Name: "router", Prompt: "v1 prompt"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	// Edit → pending v2, then accept → v2 active.
	np := "v2 prompt"
	if _, err := svc.Edit(ctx, EditInput{ID: a.ID, Prompt: &np}); err != nil {
		t.Fatalf("edit: %v", err)
	}
	if _, err := svc.Accept(ctx, a.ID); err != nil {
		t.Fatalf("accept: %v", err)
	}
	after, _ := svc.Get(ctx, a.ID)
	if after.ActiveVersionID == v1.ID {
		t.Fatalf("precondition: active should be v2 after accept")
	}

	// Revert to version 1.
	rv, err := svc.Revert(ctx, a.ID, 1)
	if err != nil {
		t.Fatalf("revert: %v", err)
	}
	if rv.ID != v1.ID {
		t.Errorf("revert returned version %q, want v1 %q", rv.ID, v1.ID)
	}
	reverted, _ := svc.Get(ctx, a.ID)
	if reverted.ActiveVersionID != v1.ID {
		t.Errorf("active after revert = %q, want v1 %q", reverted.ActiveVersionID, v1.ID)
	}
}
