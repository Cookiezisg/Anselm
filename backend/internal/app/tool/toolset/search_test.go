package toolset

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	agentstatepkg "github.com/sunweilin/foryx/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/foryx/backend/internal/pkg/reqctx"
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
	st := NewSearchTools(lazySet())
	if err := st.ValidateInput([]byte(`{"query":""}`)); !errors.Is(err, ErrEmptyQuery) {
		t.Fatalf("empty query: %v", err)
	}
	if err := st.ValidateInput([]byte(`{"query":"run function"}`)); err != nil {
		t.Fatalf("happy: %v", err)
	}
}

func TestSearchTools_Execute_MatchesAndReturnsFullDef(t *testing.T) {
	st := NewSearchTools(lazySet())
	state := agentstatepkg.New()
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	out, err := st.Execute(ctx, `{"query":"run function"}`)
	if err != nil {
		t.Fatal(err)
	}
	var resp struct {
		Tools []struct {
			Name        string          `json:"name"`
			Description string          `json:"description"`
			Parameters  json.RawMessage `json:"parameters"`
		} `json:"tools"`
	}
	if err := json.Unmarshal([]byte(out), &resp); err != nil {
		t.Fatalf("output not JSON: %v\n%s", err, out)
	}
	if len(resp.Tools) == 0 || resp.Tools[0].Name != "run_function" {
		t.Fatalf("expected run_function top match, got %+v", resp.Tools)
	}
	// Full definition includes the Parameters schema (the whole point of search).
	if !strings.Contains(string(resp.Tools[0].Parameters), "functionId") {
		t.Fatalf("expected full Parameters schema, got %s", resp.Tools[0].Parameters)
	}
	// Discovered tool is recorded in AgentState for the host to load next turn.
	if !state.IsToolDiscovered("run_function") {
		t.Fatalf("run_function not marked discovered")
	}
}

func TestSearchTools_Execute_NoMatch(t *testing.T) {
	st := NewSearchTools(lazySet())
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
	st := NewSearchTools(lazySet())
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
