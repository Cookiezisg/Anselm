package todo

import (
	"context"
	"database/sql"
	"testing"

	_ "github.com/glebarez/go-sqlite"

	tododomain "github.com/sunweilin/forgify/backend/internal/domain/todo"
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

// ctxWS carries a workspace id — the orm isolation axis every todos row lives under.
func ctxWS(ws string) context.Context {
	return reqctxpkg.SetWorkspaceID(context.Background(), ws)
}

func items(contents ...string) []tododomain.Item {
	out := make([]tododomain.Item, len(contents))
	for i, c := range contents {
		out[i] = tododomain.Item{Content: c, ActiveForm: c, Status: tododomain.StatusPending}
	}
	return out
}

func TestGetByScope_AbsentReturnsNil(t *testing.T) {
	s := newStore(t)
	got, err := s.GetByScope(ctxWS("ws_1"), "conv_x")
	if err != nil {
		t.Fatalf("GetByScope: %v", err)
	}
	if got != nil {
		t.Errorf("absent scope must be (nil,nil): got %+v", got)
	}
}

func TestUpsert_InsertThenReplacePreservesCreatedAt(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	if err := s.Upsert(ctx, &tododomain.List{ScopeID: "conv_1", ConversationID: "conv_1", Items: items("a", "b")}); err != nil {
		t.Fatalf("insert: %v", err)
	}
	got, err := s.GetByScope(ctx, "conv_1")
	if err != nil || got == nil {
		t.Fatalf("get after insert: %v %+v", err, got)
	}
	if len(got.Items) != 2 || got.Items[0].Content != "a" {
		t.Errorf("items after insert: %+v", got.Items)
	}
	if got.CreatedAt.IsZero() || got.UpdatedAt.IsZero() {
		t.Error("orm did not auto-stamp timestamps")
	}
	created := got.CreatedAt

	if err := s.Upsert(ctx, &tododomain.List{ScopeID: "conv_1", ConversationID: "conv_1", Items: items("c")}); err != nil {
		t.Fatalf("replace: %v", err)
	}
	got2, _ := s.GetByScope(ctx, "conv_1")
	if len(got2.Items) != 1 || got2.Items[0].Content != "c" {
		t.Errorf("whole-list replace failed: %+v (want single 'c')", got2.Items)
	}
	if !got2.CreatedAt.Equal(created) {
		t.Errorf("created_at not preserved across replace: %v vs %v", got2.CreatedAt, created)
	}
}

func TestUpsert_WorkspaceIsolation(t *testing.T) {
	s := newStore(t)
	if err := s.Upsert(ctxWS("ws_1"), &tododomain.List{ScopeID: "conv_1", ConversationID: "conv_1", Items: items("secret")}); err != nil {
		t.Fatalf("insert ws_1: %v", err)
	}
	got, err := s.GetByScope(ctxWS("ws_2"), "conv_1")
	if err != nil {
		t.Fatalf("get ws_2: %v", err)
	}
	if got != nil {
		t.Errorf("workspace leak: ws_2 saw ws_1's list %+v", got)
	}
}

func TestUpsert_MainVsSubagentAreDistinctRows(t *testing.T) {
	s := newStore(t)
	ctx := ctxWS("ws_1")
	sub := "subagent_1"
	if err := s.Upsert(ctx, &tododomain.List{ScopeID: "conv_1", ConversationID: "conv_1", Items: items("main")}); err != nil {
		t.Fatalf("main: %v", err)
	}
	if err := s.Upsert(ctx, &tododomain.List{ScopeID: sub, ConversationID: "conv_1", SubagentID: &sub, Items: items("sub")}); err != nil {
		t.Fatalf("subagent: %v", err)
	}
	main, _ := s.GetByScope(ctx, "conv_1")
	sa, _ := s.GetByScope(ctx, sub)
	if main == nil || sa == nil {
		t.Fatalf("both scope rows must exist: main=%+v sa=%+v", main, sa)
	}
	if main.Items[0].Content != "main" || sa.Items[0].Content != "sub" {
		t.Errorf("subagent polluted main board: main=%+v sa=%+v", main.Items, sa.Items)
	}
	if sa.SubagentID == nil || *sa.SubagentID != sub {
		t.Errorf("subagent_id json round-trip failed: %+v", sa.SubagentID)
	}
}
