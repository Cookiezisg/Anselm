package todo

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	tododomain "github.com/sunweilin/forgify/backend/internal/domain/todo"
	todostore "github.com/sunweilin/forgify/backend/internal/infra/store/todo"
	ormpkg "github.com/sunweilin/forgify/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// fakeBridge captures published stream events for assertion.
type fakeBridge struct{ events []streamdomain.Event }

func (f *fakeBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	f.events = append(f.events, e)
	return streamdomain.Envelope{Event: e}, nil
}

func (f *fakeBridge) Subscribe(context.Context, int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

func newSvc(t *testing.T) (*Service, *fakeBridge) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range todostore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	br := &fakeBridge{}
	return New(todostore.New(ormpkg.Open(sqlDB)), br, zap.NewNop()), br
}

// runCtx seeds workspace + conversation — the ctx a chat/agent loop hands to a tool call.
func runCtx(conv string) context.Context {
	return reqctxpkg.SetConversationID(reqctxpkg.SetWorkspaceID(context.Background(), "ws_1"), conv)
}

func strPtr(s string) *string { return &s }

func TestWrite_PersistsRendersBroadcasts(t *testing.T) {
	svc, br := newSvc(t)
	ctx := runCtx("conv_1")
	out, err := svc.Write(ctx, []tododomain.Item{
		{Content: "Run tests", Status: tododomain.StatusInProgress, ActiveForm: "Running tests"},
		{Content: "Ship it"}, // status/activeForm defaulted
	})
	if err != nil {
		t.Fatalf("Write: %v", err)
	}
	if !strings.Contains(out, "[→] Running tests") || !strings.Contains(out, "[ ] Ship it") {
		t.Errorf("tool-result render: %q", out)
	}

	got, _ := svc.Get(ctx)
	if len(got) != 2 || got[1].Status != tododomain.StatusPending || got[1].ActiveForm != "Ship it" {
		t.Errorf("persisted/normalized: %+v", got)
	}

	if len(br.events) != 1 {
		t.Fatalf("want 1 live push, got %d", len(br.events))
	}
	e := br.events[0]
	if e.Scope.Kind != streamdomain.KindConversation || e.Scope.ID != "conv_1" {
		t.Errorf("must anchor messages stream to conversation: %+v", e.Scope)
	}
	sig, ok := e.Frame.(streamdomain.Signal)
	if !ok || sig.Node.Type != "todo" {
		t.Errorf("frame must be Signal node.type=todo: %T %q", e.Frame, sig.Node.Type)
	}
	if !sig.Durable() {
		t.Error("todo signal must be durable (reconnect replays last board state)")
	}
	var payload map[string]any
	if err := json.Unmarshal(sig.Node.Content, &payload); err != nil {
		t.Fatalf("payload: %v", err)
	}
	if payload["conversationId"] != "conv_1" {
		t.Errorf("payload conversationId: %+v", payload)
	}
	if _, hasSub := payload["subagentId"]; hasSub {
		t.Errorf("main-list payload must omit subagentId: %+v", payload)
	}
}

func TestWrite_SubagentScopeIsolatedButAnchoredToConversation(t *testing.T) {
	svc, br := newSvc(t)
	ctx := reqctxpkg.SetSubagentID(runCtx("conv_1"), "subagent_9")
	if _, err := svc.Write(ctx, []tododomain.Item{{Content: "sub task"}}); err != nil {
		t.Fatalf("Write: %v", err)
	}
	subItems, _ := svc.GetForScope(ctx, "conv_1", strPtr("subagent_9"))
	if len(subItems) != 1 || subItems[0].Content != "sub task" {
		t.Errorf("subagent scope list: %+v", subItems)
	}
	mainItems, _ := svc.GetForScope(ctx, "conv_1", nil)
	if len(mainItems) != 0 {
		t.Errorf("subagent write polluted the main board: %+v", mainItems)
	}
	e := br.events[0]
	if e.Scope.Kind != streamdomain.KindConversation || e.Scope.ID != "conv_1" {
		t.Errorf("subagent push must still anchor the conversation (reach its view): %+v", e.Scope)
	}
	var payload map[string]any
	_ = json.Unmarshal(e.Frame.(streamdomain.Signal).Node.Content, &payload)
	if payload["subagentId"] != "subagent_9" {
		t.Errorf("payload must carry subagentId for subtree nesting: %+v", payload)
	}
}

func TestWrite_EmptyClears(t *testing.T) {
	svc, _ := newSvc(t)
	ctx := runCtx("conv_1")
	_, _ = svc.Write(ctx, []tododomain.Item{{Content: "x"}})
	out, err := svc.Write(ctx, nil)
	if err != nil {
		t.Fatalf("clear: %v", err)
	}
	if !strings.Contains(out, "cleared") {
		t.Errorf("clear render: %q", out)
	}
	if got, _ := svc.Get(ctx); len(got) != 0 {
		t.Errorf("list not cleared: %+v", got)
	}
}

func TestWrite_MissingConversation_Errors(t *testing.T) {
	svc, _ := newSvc(t)
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1") // no conversation seeded
	if _, err := svc.Write(ctx, []tododomain.Item{{Content: "x"}}); !errors.Is(err, reqctxpkg.ErrMissingConversationID) {
		t.Errorf("missing conversation: err = %v, want ErrMissingConversationID", err)
	}
}

func TestWrite_Validation(t *testing.T) {
	svc, _ := newSvc(t)
	ctx := runCtx("conv_1")
	if _, err := svc.Write(ctx, []tododomain.Item{{Content: "   "}}); !errors.Is(err, tododomain.ErrEmptyContent) {
		t.Errorf("empty content: %v", err)
	}
	if _, err := svc.Write(ctx, []tododomain.Item{{Content: "x", Status: "bogus"}}); !errors.Is(err, tododomain.ErrInvalidStatus) {
		t.Errorf("bad status: %v", err)
	}
	big := make([]tododomain.Item, tododomain.MaxItems+1)
	for i := range big {
		big[i] = tododomain.Item{Content: "x"}
	}
	if _, err := svc.Write(ctx, big); !errors.Is(err, tododomain.ErrTooManyItems) {
		t.Errorf("too many items: %v", err)
	}
}

func TestSystemReminder_InjectsOnlyWhenOpen(t *testing.T) {
	svc, _ := newSvc(t)
	ctx := runCtx("conv_1")

	if _, ok := svc.SystemReminder(ctx); ok {
		t.Error("empty list must not inject")
	}

	_, _ = svc.Write(ctx, []tododomain.Item{
		{Content: "Do A", Status: tododomain.StatusInProgress, ActiveForm: "Doing A"},
		{Content: "Do B", Status: tododomain.StatusCompleted},
	})
	block, ok := svc.SystemReminder(ctx)
	if !ok {
		t.Fatal("a list with an open task must inject")
	}
	if !strings.Contains(block, "1 open, 1 done") || !strings.Contains(block, "Doing A") {
		t.Errorf("reminder block: %q", block)
	}

	_, _ = svc.Write(ctx, []tododomain.Item{{Content: "Do A", Status: tododomain.StatusCompleted}})
	if _, ok := svc.SystemReminder(ctx); ok {
		t.Error("a fully-completed list must not inject")
	}
}
