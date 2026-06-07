package mcp

import (
	"encoding/json"
	"testing"
)

// TestDynamicTool_Naming: a server tool is exposed as mcp__<server>__<tool> (':' is illegal
// in LLM tool names) and passes the server's inputSchema through as Parameters verbatim.
//
// TestDynamicTool_Naming：server 工具暴露为 mcp__<server>__<tool>（LLM tool 名不许冒号），
// Parameters 原样透传 server 的 inputSchema。
func TestDynamicTool_Naming(t *testing.T) {
	dt := &dynamicTool{serverName: "github", toolName: "create_issue", schema: json.RawMessage(`{"type":"object"}`)}
	if got := dt.Name(); got != "mcp__github__create_issue" {
		t.Fatalf("want mcp__github__create_issue, got %q", got)
	}
	if string(dt.Parameters()) != `{"type":"object"}` {
		t.Fatalf("Parameters must pass inputSchema through verbatim, got %s", dt.Parameters())
	}
}

func TestInstallServer_ValidateInput(t *testing.T) {
	tool := &InstallServer{}
	if err := tool.ValidateInput(json.RawMessage(`{}`)); err == nil {
		t.Fatal("expected error for missing name")
	}
	if err := tool.ValidateInput(json.RawMessage(`{"name":"io.github.x/y"}`)); err != nil {
		t.Fatalf("valid name should pass: %v", err)
	}
}

func TestReconnectMCP_RequiresName(t *testing.T) {
	if err := (&ReconnectMCP{}).ValidateInput(json.RawMessage(`{}`)); err == nil {
		t.Fatal("expected error for missing name")
	}
	if err := (&UninstallServer{}).ValidateInput(json.RawMessage(`{"name":"github"}`)); err != nil {
		t.Fatalf("valid name should pass: %v", err)
	}
}
