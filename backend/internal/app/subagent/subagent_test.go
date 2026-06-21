package subagent

import (
	"context"
	"database/sql"
	"encoding/json"
	"iter"
	"slices"
	"strings"
	"testing"
	"time"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	messagesstore "github.com/sunweilin/anselm/backend/internal/infra/store/messages"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// --- fakes -----------------------------------------------------------------

type fakeClient struct{ script []llminfra.StreamEvent }

func (c *fakeClient) Stream(_ context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		for _, ev := range c.script {
			if !yield(ev) {
				return
			}
		}
	}
}

func textTurn(text string) []llminfra.StreamEvent {
	return []llminfra.StreamEvent{
		{Type: llminfra.EventText, Delta: text},
		{Type: llminfra.EventFinish, FinishReason: "stop", InputTokens: 7, OutputTokens: 9},
	}
}

type fakeResolver struct{ client llminfra.Client }

func (r fakeResolver) Resolve(_ context.Context) (Bundle, error) {
	return Bundle{Client: r.client, Request: llminfra.Request{ModelID: "fake-model"}, Provider: "fake"}, nil
}

type fakeTool struct{ name string }

func (f fakeTool) Name() string                                    { return f.name }
func (f fakeTool) Description() string                             { return f.name }
func (f fakeTool) Parameters() json.RawMessage                     { return json.RawMessage(`{"type":"object"}`) }
func (f fakeTool) ValidateInput(json.RawMessage) error             { return nil }
func (f fakeTool) Execute(context.Context, string) (string, error) { return "", nil }

type fakeTools struct{ tools []toolapp.Tool }

func (f fakeTools) Tools() []toolapp.Tool { return f.tools }

func newStore(t *testing.T) messagesdomain.Repository {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range messagesstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	return messagesstore.New(ormpkg.Open(sqlDB))
}

func ctxWS(id string) context.Context { return reqctxpkg.SetWorkspaceID(context.Background(), id) }

// --- registry --------------------------------------------------------------

func TestRegistry_BuiltInTypes(t *testing.T) {
	r := NewRegistry()
	for _, name := range []string{"Explore", "Plan", "general-purpose"} {
		if _, ok := r.Get(name); !ok {
			t.Fatalf("missing built-in type %q", name)
		}
	}
	if _, ok := r.Get("nope"); ok {
		t.Fatal("unknown type should not resolve")
	}
}

// TestAnnotateTerminal — F150: a subagent that did NOT finish cleanly must flag the terminal condition
// to the parent (not read as a clean completion carrying only its preamble text); a clean run passes through.
func TestAnnotateTerminal(t *testing.T) {
	if got := annotateTerminal(loopapp.Result{Status: messagesdomain.StatusCompleted, LastMessage: "done"}); got != "done" {
		t.Fatalf("clean completion must pass through unchanged, got %q", got)
	}
	cancelled := annotateTerminal(loopapp.Result{Status: messagesdomain.StatusCancelled, StopReason: "cancelled", LastMessage: "partial work"})
	if !strings.Contains(cancelled, "did not finish cleanly") || !strings.Contains(cancelled, "partial work") {
		t.Fatalf("a cancelled subagent must flag the terminal AND keep its partial text, got %q", cancelled)
	}
	errEmpty := annotateTerminal(loopapp.Result{Status: messagesdomain.StatusError, ErrMsg: "provider boom"})
	if !strings.Contains(errEmpty, "provider boom") {
		t.Fatalf("an error terminal with no text must still surface the reason, got %q", errEmpty)
	}
}

func TestFilterTools(t *testing.T) {
	all := []toolapp.Tool{fakeTool{"Read"}, fakeTool{"Grep"}, fakeTool{"Write"}, fakeTool{"Subagent"}, fakeTool{"get_subagent_trace"}}

	explore, _ := NewRegistry().Get("Explore")
	got := names(filterTools(explore, all))
	// Explore whitelist keeps Read + Grep, drops Write (not whitelisted) and Subagent (recursion).
	if len(got) != 2 || !has(got, "Read") || !has(got, "Grep") || has(got, "Subagent") || has(got, "Write") {
		t.Fatalf("Explore filter wrong: %v", got)
	}

	gp, _ := NewRegistry().Get("general-purpose")
	got = names(filterTools(gp, all))
	// general-purpose keeps everything EXCEPT Subagent (recursion guard) AND get_subagent_trace
	// (isolation: a subagent must not read the parent conversation's subagent traces, F149).
	if len(got) != 3 || has(got, "Subagent") || has(got, "get_subagent_trace") {
		t.Fatalf("general-purpose filter wrong (must strip Subagent + get_subagent_trace): %v", got)
	}
}

// --- Spawn end-to-end ------------------------------------------------------

func TestSpawn_PersistsSubMessage(t *testing.T) {
	store := newStore(t)
	svc := NewService(Deps{
		Messages: store,
		Resolver: fakeResolver{client: &fakeClient{script: textTurn("explored: found it")}},
		Tools:    fakeTools{tools: []toolapp.Tool{fakeTool{"Read"}}},
	}, zap.NewNop())

	ctx := reqctxpkg.SetConversationID(ctxWS("ws_1"), "cv_1")
	ctx = reqctxpkg.SetToolCallID(ctx, "blk_tc") // simulates loop seeding the spawning tool_call id

	result, err := svc.Spawn(ctx, "Explore", "find the thing")
	if err != nil {
		t.Fatalf("Spawn: %v", err)
	}
	if result != "explored: found it" {
		t.Fatalf("result wrong: %q", result)
	}

	thread, err := store.LoadThread(ctx, "cv_1")
	if err != nil {
		t.Fatalf("LoadThread: %v", err)
	}
	if len(thread) != 1 {
		t.Fatalf("want 1 sub-message, got %d", len(thread))
	}
	m := thread[0]
	if m.SubagentID == "" {
		t.Fatalf("sub-message must be tagged with a SubagentID: %+v", m)
	}
	if m.Role != messagesdomain.RoleAssistant || m.Status != messagesdomain.StatusCompleted {
		t.Fatalf("sub-message terminal wrong: %+v", m)
	}
	if anchor, _ := m.Attrs[attrParentBlockID].(string); anchor != "blk_tc" {
		t.Fatalf("sub-message must anchor at the spawning tool_call: %v", m.Attrs)
	}
	if len(m.Blocks) != 1 || m.Blocks[0].Content != "explored: found it" {
		t.Fatalf("sub-message blocks wrong: %+v", m.Blocks)
	}
}

func TestSpawn_RecursionRefused(t *testing.T) {
	svc := NewService(Deps{
		Messages: newStore(t),
		Resolver: fakeResolver{client: &fakeClient{script: textTurn("x")}},
		Tools:    fakeTools{},
	}, zap.NewNop())

	// A ctx already inside a subagent run → spawning is refused (depth 1).
	ctx := reqctxpkg.SetSubagentID(reqctxpkg.SetConversationID(ctxWS("ws_1"), "cv_1"), "subagt_parent")
	if _, err := svc.Spawn(ctx, "Explore", "nested"); err == nil {
		t.Fatal("a subagent must not be able to spawn another subagent")
	}
}

func TestSpawn_UnknownType(t *testing.T) {
	svc := NewService(Deps{Messages: newStore(t), Resolver: fakeResolver{client: &fakeClient{}}, Tools: fakeTools{}}, zap.NewNop())
	if _, err := svc.Spawn(reqctxpkg.SetConversationID(ctxWS("ws_1"), "cv_1"), "Nope", "x"); err == nil {
		t.Fatal("unknown subagent type should error")
	}
}

func names(tools []toolapp.Tool) []string {
	out := make([]string, len(tools))
	for i, t := range tools {
		out[i] = t.Name()
	}
	return out
}

func has(ss []string, s string) bool { return slices.Contains(ss, s) }

// blockingClient blocks its stream on ctx until the subagent's wall clock cancels it, then emits the
// cancel-shaped EventError a dead/half-open connection would — the "never finishes on its own" shape.
type blockingClient struct{}

func (c *blockingClient) Stream(ctx context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		<-ctx.Done()
		yield(llminfra.StreamEvent{Type: llminfra.EventError, Err: ctx.Err()})
	}
}

// TestSpawn_WallClockTimeout pins F152 step A: Spawn calls loop.Run directly (not via InvokeAgent or
// processTask), so it owns a whole-run wall clock (reusing ChatTurnSec). A subagent whose stream never
// returns is cut off by that deadline — finite, recorded cancelled, annotated for the parent — instead
// of running until it happens to inherit a parent deadline (or, on a future no-parent-deadline path,
// forever). Deterministic: a never-returning fake stream + a 1s cap; no real 35min run.
func TestSpawn_WallClockTimeout(t *testing.T) {
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.ChatTurnSec = 1 // shrink the subagent's own wall clock to 1s
		return l
	})
	defer limitspkg.SetProvider(limitspkg.Default)

	store := newStore(t)
	svc := NewService(Deps{
		Messages: store,
		Resolver: fakeResolver{client: &blockingClient{}},
		Tools:    fakeTools{tools: []toolapp.Tool{fakeTool{"Read"}}},
	}, zap.NewNop())
	ctx := reqctxpkg.SetConversationID(ctxWS("ws_1"), "cv_1")
	ctx = reqctxpkg.SetToolCallID(ctx, "blk_tc")

	start := time.Now()
	result, err := svc.Spawn(ctx, "Explore", "do work forever")
	elapsed := time.Since(start)
	if err != nil {
		t.Fatalf("Spawn: %v", err)
	}
	if elapsed > 20*time.Second { // generous CI bound; the 1s cap should cut it off near-instantly
		t.Fatalf("subagent wall clock did not cut off a never-returning stream: ran %s", elapsed)
	}
	if !strings.Contains(result, "did not finish cleanly") {
		t.Fatalf("a timed-out subagent must annotate the cutoff for the parent (F150/F152), got %q", result)
	}
	// the sub-message persists as a non-completed terminal (the cancel shape), never stuck streaming.
	thread, err := store.LoadThread(ctx, "cv_1")
	if err != nil || len(thread) != 1 {
		t.Fatalf("LoadThread: %v (%d msgs)", err, len(thread))
	}
	if st := thread[0].Status; st == messagesdomain.StatusCompleted || st == messagesdomain.StatusStreaming {
		t.Fatalf("a timed-out subagent sub-message must be a cancel/error terminal, got %q", st)
	}
}
