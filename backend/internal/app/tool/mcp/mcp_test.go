// mcp_test.go — unit tests for SearchMCP + CallMCP. Identity / static
// metadata / schema / ValidateInput / Execute friendly-error mapping.
// Service-level integration is covered in app/mcp/mcp_test.go;
// end-to-end with a real subprocess lives in D6-5 pipeline.
//
// mcp_test.go ——SearchMCP + CallMCP 单测。Identity / 静态元数据 / schema /
// ValidateInput / Execute 友好错误映射。Service 集成在 app/mcp/mcp_test.go；
// 真子进程端到端在 D6-5 pipeline。
package mcp

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// ── SearchMCP identity / metadata / schema ───────────────────────────

func TestSearchMCP_Identity(t *testing.T) {
	tt := &SearchMCP{}
	if tt.Name() != "search_mcp_tools" {
		t.Errorf("Name() = %q", tt.Name())
	}
	if tt.Description() == "" {
		t.Error("Description empty")
	}
	if len(tt.Parameters()) == 0 {
		t.Error("Parameters empty")
	}
}

func TestSearchMCP_StaticMetadata(t *testing.T) {
	tt := &SearchMCP{}
	if !tt.IsReadOnly() {
		t.Error("search_mcp should be IsReadOnly=true (discovery only)")
	}
	if tt.NeedsReadFirst() {
		t.Error("NeedsReadFirst should be false")
	}
	if tt.RequiresWorkspace() {
		t.Error("RequiresWorkspace should be false")
	}
}

func TestSearchMCP_Schema_RequiresQuery(t *testing.T) {
	var schema map[string]any
	_ = json.Unmarshal((&SearchMCP{}).Parameters(), &schema)
	required, _ := schema["required"].([]any)
	if len(required) != 1 || required[0] != "query" {
		t.Errorf("required = %v, want [query]", required)
	}
}

// ── SearchMCP.ValidateInput ──────────────────────────────────────────

func TestSearchMCP_ValidateInput_Happy(t *testing.T) {
	if err := (&SearchMCP{}).ValidateInput(json.RawMessage(`{"query":"github pr"}`)); err != nil {
		t.Errorf("happy: %v", err)
	}
}

func TestSearchMCP_ValidateInput_EmptyQuery(t *testing.T) {
	err := (&SearchMCP{}).ValidateInput(json.RawMessage(`{"query":""}`))
	if !errors.Is(err, ErrEmptyQuery) {
		t.Errorf("err = %v, want ErrEmptyQuery", err)
	}
}

func TestSearchMCP_ValidateInput_WhitespaceQuery(t *testing.T) {
	err := (&SearchMCP{}).ValidateInput(json.RawMessage(`{"query":"   \t\n  "}`))
	if !errors.Is(err, ErrEmptyQuery) {
		t.Errorf("err = %v, want ErrEmptyQuery", err)
	}
}

func TestSearchMCP_ValidateInput_MalformedJSON(t *testing.T) {
	err := (&SearchMCP{}).ValidateInput(json.RawMessage(`not-json`))
	if err == nil {
		t.Error("malformed JSON should error")
	}
}

func TestSearchMCP_CheckPermissions_Allow(t *testing.T) {
	for _, mode := range []toolapp.PermissionMode{
		toolapp.PermissionModeDefault,
		toolapp.PermissionModeAcceptEdits,
		toolapp.PermissionModePlan,
	} {
		if got := (&SearchMCP{}).CheckPermissions(json.RawMessage(`{}`), mode); got != toolapp.PermissionAllow {
			t.Errorf("mode %v: got %v, want PermissionAllow", mode, got)
		}
	}
}

// ── SearchMCP.Execute parse failures ─────────────────────────────────

func TestSearchMCP_Execute_MalformedArgsJSON(t *testing.T) {
	tt := &SearchMCP{} // svc nil; Execute returns parse error before reaching svc
	_, err := tt.Execute(context.Background(), `not-json`)
	if err == nil || !strings.Contains(err.Error(), "parse args") {
		t.Errorf("want parse-args error, got %v", err)
	}
}

// ── CallMCP identity / metadata / schema ─────────────────────────────

func TestCallMCP_Identity(t *testing.T) {
	tt := &CallMCP{}
	if tt.Name() != "call_mcp_tool" {
		t.Errorf("Name() = %q", tt.Name())
	}
	if tt.IsReadOnly() {
		t.Error("CallMCP IsReadOnly should be false (MCP tool may write)")
	}
}

func TestCallMCP_Schema_RequiresServerToolArgs(t *testing.T) {
	var schema map[string]any
	_ = json.Unmarshal((&CallMCP{}).Parameters(), &schema)
	required, _ := schema["required"].([]any)
	got := map[string]bool{}
	for _, r := range required {
		got[r.(string)] = true
	}
	for _, want := range []string{"server", "tool", "args"} {
		if !got[want] {
			t.Errorf("required missing %q (got %v)", want, required)
		}
	}
}

// ── CallMCP.ValidateInput ────────────────────────────────────────────

func TestCallMCP_ValidateInput_Happy(t *testing.T) {
	err := (&CallMCP{}).ValidateInput(json.RawMessage(`{"server":"gh","tool":"list_prs","args":{}}`))
	if err != nil {
		t.Errorf("happy: %v", err)
	}
}

func TestCallMCP_ValidateInput_EmptyServer(t *testing.T) {
	err := (&CallMCP{}).ValidateInput(json.RawMessage(`{"server":"","tool":"x","args":{}}`))
	if !errors.Is(err, ErrEmptyServer) {
		t.Errorf("err = %v, want ErrEmptyServer", err)
	}
}

func TestCallMCP_ValidateInput_EmptyTool(t *testing.T) {
	err := (&CallMCP{}).ValidateInput(json.RawMessage(`{"server":"x","tool":"","args":{}}`))
	if !errors.Is(err, ErrEmptyTool) {
		t.Errorf("err = %v, want ErrEmptyTool", err)
	}
}

func TestCallMCP_ValidateInput_WhitespaceServer(t *testing.T) {
	err := (&CallMCP{}).ValidateInput(json.RawMessage(`{"server":"  \t","tool":"x","args":{}}`))
	if !errors.Is(err, ErrEmptyServer) {
		t.Errorf("err = %v, want ErrEmptyServer", err)
	}
}

// ── CallMCP.Execute parse failures ───────────────────────────────────

func TestCallMCP_Execute_MalformedArgsJSON(t *testing.T) {
	tt := &CallMCP{}
	_, err := tt.Execute(context.Background(), `not-json`)
	if err == nil || !strings.Contains(err.Error(), "parse args") {
		t.Errorf("want parse-args error, got %v", err)
	}
}

// ── mapCallToolErrorToFriendly: every sentinel produces a readable string ─

func TestMapCallToolErrorToFriendly_AllSentinelsCovered(t *testing.T) {
	cases := []struct {
		err           error
		mustContain   string
		mustNotMatch  string // catches "default" path leakage when a sentinel was supposed to match
	}{
		{
			err:         mcpdomain.ErrServerNotFound,
			mustContain: "is not configured",
		},
		{
			err:         mcpdomain.ErrServerNotConnected,
			mustContain: "is not connected",
		},
		{
			err:         mcpdomain.ErrToolNotFound,
			mustContain: "does not exist on server",
		},
		{
			err:         mcpdomain.ErrToolCallTimeout,
			mustContain: "timed out",
		},
		{
			err:         mcpdomain.ErrToolCallFailed,
			mustContain: "failed:",
		},
		{
			err:          errors.New("some other random error"),
			mustContain:  "call_mcp gh/x failed",
			mustNotMatch: "is not configured", // ensure we don't false-positive a sentinel
		},
	}

	for _, c := range cases {
		got := mapCallToolErrorToFriendly("gh", "x", c.err)
		if !strings.Contains(got, c.mustContain) {
			t.Errorf("err=%v: got %q, want substring %q", c.err, got, c.mustContain)
		}
		if c.mustNotMatch != "" && strings.Contains(got, c.mustNotMatch) {
			t.Errorf("err=%v: got %q, must not contain %q", c.err, got, c.mustNotMatch)
		}
	}
}

func TestMapCallToolErrorToFriendly_EmbedsServerToolNames(t *testing.T) {
	got := mapCallToolErrorToFriendly("playwright", "browser_open", mcpdomain.ErrToolNotFound)
	if !strings.Contains(got, "playwright") || !strings.Contains(got, "browser_open") {
		t.Errorf("missing server/tool names: %q", got)
	}
}

// ── MCPTools factory ─────────────────────────────────────────────────

func TestMCPTools_ReturnsAllInOrder(t *testing.T) {
	// Pass nils for LLM deps — TestMCPTools_ReturnsAllInOrder doesn't
	// exercise marketplace search rerank, just identity. Marketplace
	// search tool is omitted from the list when LLM deps are nil
	// (consistent with harness behaviour). install + uninstall require
	// only svc so they always show.
	//
	// 传 nil LLM 依赖——只查 identity，不跑 marketplace search 重排。
	// LLM 依赖 nil 时 marketplace search 工具不入列（与 harness 一致）。
	// install + uninstall 只需 svc 故始终在。
	tools := MCPTools(nil, nil, nil, nil)
	if len(tools) != 4 {
		t.Fatalf("len = %d, want 4 (search_mcp_tools / call_mcp_tool / install_mcp_server / uninstall_mcp_server; marketplace search omitted with nil LLM deps)", len(tools))
	}
	wantNames := []string{"search_mcp_tools", "call_mcp_tool", "install_mcp_server", "uninstall_mcp_server"}
	for i, want := range wantNames {
		if tools[i].Name() != want {
			t.Errorf("tools[%d] = %q, want %q", i, tools[i].Name(), want)
		}
	}
}
