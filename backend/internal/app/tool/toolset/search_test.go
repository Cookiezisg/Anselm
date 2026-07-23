package toolset

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	agentstatepkg "github.com/sunweilin/anselm/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// fakeTool is a minimal toolapp.Tool for ranking/return tests.
type fakeTool struct {
	name   string
	desc   string
	params string
}

func (f fakeTool) Name() string                                  { return f.name }
func (f fakeTool) Description() string                           { return f.desc }
func (f fakeTool) Parameters() json.RawMessage                   { return json.RawMessage(f.params) }
func (fakeTool) ValidateInput(json.RawMessage) error             { return nil }
func (fakeTool) Execute(context.Context, string) (string, error) { return "ok", nil }

func lazySet() []toolapp.Tool {
	return []toolapp.Tool{
		fakeTool{name: "run_function", desc: "Run a user-defined function by id with arguments.", params: `{"type":"object","properties":{"functionId":{"type":"string"}}}`},
		fakeTool{name: "trigger_workflow", desc: "Start a workflow run by id.", params: `{"type":"object"}`},
		fakeTool{name: "call_mcp_tool", desc: "Call a tool on a connected MCP server.", params: `{"type":"object"}`},
	}
}

func TestSearchTools_ValidateInput(t *testing.T) {
	st := NewSearchTools(lazySet(), nil)
	if err := st.ValidateInput([]byte(`{"query":""}`)); !errors.Is(err, ErrEmptyQuery) {
		t.Fatalf("empty query: %v", err)
	}
	if err := st.ValidateInput([]byte(`{"query":"run function"}`)); err != nil {
		t.Fatalf("happy: %v", err)
	}
}

func TestSearchTools_Execute_MatchesAndReturnsCompactActivation(t *testing.T) {
	st := NewSearchTools(lazySet(), nil)
	state := agentstatepkg.New()
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	out, err := st.Execute(ctx, `{"query":"run function"}`)
	if err != nil {
		t.Fatal(err)
	}
	var resp struct {
		Tools []struct {
			Name    string `json:"name"`
			Purpose string `json:"purpose"`
		} `json:"loaded_tools"`
	}
	if err := json.Unmarshal([]byte(out), &resp); err != nil {
		t.Fatalf("output not JSON: %v\n%s", err, out)
	}
	if len(resp.Tools) == 0 || resp.Tools[0].Name != "run_function" {
		t.Fatalf("expected run_function top match, got %+v", resp.Tools)
	}
	// The durable result must not duplicate the full schema; the host offers it
	// exactly once in the next request's tools field.
	if strings.Contains(out, "functionId") || strings.Contains(out, `"parameters"`) {
		t.Fatalf("activation result duplicated a full schema: %s", out)
	}
	// Discovered tool is recorded in AgentState for the host to load next turn.
	if !state.IsToolDiscovered("run_function") {
		t.Fatalf("run_function not marked discovered")
	}
}

func TestSearchTools_Execute_NoMatch(t *testing.T) {
	st := NewSearchTools(lazySet(), nil)
	ctx := reqctxpkg.WithAgentState(context.Background(), agentstatepkg.New())
	out, err := st.Execute(ctx, `{"query":"quantum teleportation"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "No tools matched") {
		t.Fatalf("expected no-match guidance, got %q", out)
	}
}

func TestSearchTools_Execute_NoAgentState_Tolerated(t *testing.T) {
	// search_tools is read-only discovery — absent AgentState just skips the
	// discovered-mark (host falls back to re-search), not a failure.
	st := NewSearchTools(lazySet(), nil)
	out, err := st.Execute(context.Background(), `{"query":"workflow"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "trigger_workflow") {
		t.Fatalf("expected workflow match even without state, got %q", out)
	}
}

func TestRankLazy_ScoreOrderAndLimit(t *testing.T) {
	lazy := []toolapp.Tool{
		fakeTool{name: "a", desc: "alpha beta gamma"}, // matches 2 terms
		fakeTool{name: "b", desc: "alpha only"},       // matches 1 term
		fakeTool{name: "c", desc: "nothing here"},     // matches 0 → excluded
	}
	got := rankLazy(lazy, "alpha beta", 5)
	if len(got) != 2 {
		t.Fatalf("want 2 matches (c excluded), got %d", len(got))
	}
	if got[0].Name() != "a" || got[1].Name() != "b" {
		t.Fatalf("want a (score 2) before b (score 1), got %s %s", got[0].Name(), got[1].Name())
	}
	// limit caps results.
	if capped := rankLazy(lazy, "alpha", 1); len(capped) != 1 {
		t.Fatalf("limit=1 should cap to 1, got %d", len(capped))
	}
}

// TestSearchTools_RanksDynamicMCPTools — F52: a per-request dynamic tool (an MCP server tool from the
// ctx workspace) is discoverable via search_tools alongside the static lazy set, and is marked
// discovered so the host then offers it.
func TestSearchTools_RanksDynamicMCPTools(t *testing.T) {
	dyn := func(context.Context) []toolapp.Tool {
		return []toolapp.Tool{fakeTool{name: "mcp__weather__forecast", desc: "Get the weather forecast for a city.", params: `{"type":"object"}`}}
	}
	st := NewSearchTools(lazySet(), dyn)
	state := agentstatepkg.New()
	ctx := reqctxpkg.WithAgentState(context.Background(), state)
	out, err := st.Execute(ctx, `{"query":"weather forecast city"}`)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "mcp__weather__forecast") {
		t.Fatalf("dynamic MCP tool should be discoverable via search_tools; got %s", out)
	}
	if !state.IsToolDiscovered("mcp__weather__forecast") {
		t.Fatalf("a found dynamic tool must be marked discovered")
	}
	// nil dynamic provider must still work (degrade gracefully).
	if NewSearchTools(lazySet(), nil).pool(ctx) == nil {
		t.Fatalf("nil dynamic provider should return the static lazy pool, not nil")
	}
}
