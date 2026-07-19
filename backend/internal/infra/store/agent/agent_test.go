package agent

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
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

func TestStore_AgentVersionRoundTrip(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()

	a := &agentdomain.Agent{ID: "ag_1", Name: "alpha", ActiveVersionID: "agv_1", CreatedAt: now, UpdatedAt: now}
	if err := s.Create(ctx, a); err != nil {
		t.Fatalf("create: %v", err)
	}
	v := &agentdomain.Version{
		ID: "agv_1", AgentID: "ag_1", Version: 1, Prompt: "p",
		Tools: []agentdomain.ToolRef{{Ref: "fn_x", Name: "x"}}, Knowledge: []string{"doc_1"}, CreatedAt: now,
	}
	if err := s.CreateVersion(ctx, v); err != nil {
		t.Fatalf("createVersion: %v", err)
	}

	got, err := s.Get(ctx, "ag_1")
	if err != nil || got.Name != "alpha" {
		t.Fatalf("get: %v %+v", err, got)
	}
	gv, err := s.GetVersion(ctx, "agv_1")
	if err != nil || len(gv.Tools) != 1 || gv.Tools[0].Ref != "fn_x" || len(gv.Knowledge) != 1 {
		t.Fatalf("version json round-trip: %v %+v", err, gv)
	}

	if err := s.Create(ctx, &agentdomain.Agent{ID: "ag_2", Name: "alpha", CreatedAt: now, UpdatedAt: now}); !errors.Is(err, agentdomain.ErrNameConflict) {
		t.Fatalf("want ErrNameConflict, got %v", err)
	}

	n, _ := s.NextVersionNumber(ctx, "ag_1")
	if n != 2 {
		t.Fatalf("next version want 2, got %d", n)
	}
}

func TestStore_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	now := time.Now().UTC()
	if err := s.Create(ctxWS("ws_1"), &agentdomain.Agent{ID: "ag_1", Name: "x", CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatalf("create: %v", err)
	}
	if _, err := s.Get(ctxWS("ws_2"), "ag_1"); !errors.Is(err, agentdomain.ErrNotFound) {
		t.Fatalf("cross-ws should be NotFound, got %v", err)
	}
}

// TestStore_ListSearch — ?search is a case-insensitive name substring (WhereLike), same as the other 3 entity stores.
//
// TestStore_ListSearch —— ?search 是大小写不敏感的 name 子串（WhereLike），与另 3 个实体 store 同键。
func TestStore_ListSearch(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()
	if err := s.Create(ctx, &agentdomain.Agent{ID: "ag_1", Name: "Quarterly Report", CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatalf("create ag_1: %v", err)
	}
	if err := s.Create(ctx, &agentdomain.Agent{ID: "ag_2", Name: "random helper", CreatedAt: now, UpdatedAt: now}); err != nil {
		t.Fatalf("create ag_2: %v", err)
	}
	rows, _, err := s.ListAgents(ctx, agentdomain.ListFilter{Search: "REPORT"})
	if err != nil {
		t.Fatalf("search: %v", err)
	}
	if len(rows) != 1 || rows[0].ID != "ag_1" {
		t.Fatalf("search 'REPORT' should match only ag_1, got %d rows", len(rows))
	}
}

func TestStore_ExecutionsPagingAggregates(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	now := time.Now().UTC()
	for i, st := range []string{"ok", "ok", "failed"} {
		e := &agentdomain.Execution{
			ID: fmt.Sprintf("agx_%d", i), AgentID: "ag_1", VersionID: "agv_1",
			Status: st, TriggeredBy: "chat", StartedAt: now, EndedAt: now, CreatedAt: now,
		}
		if err := s.SaveExecution(ctx, e); err != nil {
			t.Fatalf("save exec: %v", err)
		}
	}
	rows, _, err := s.ListExecutions(ctx, agentdomain.ExecutionFilter{AgentID: "ag_1"})
	if err != nil || len(rows) != 3 {
		t.Fatalf("list: %v %d", err, len(rows))
	}
	agg, err := s.ComputeExecutionAggregates(ctx, agentdomain.ExecutionFilter{AgentID: "ag_1"})
	if err != nil || agg.OKCount != 2 || agg.FailedCount != 1 {
		t.Fatalf("aggregates: %v %+v", err, agg)
	}
}
