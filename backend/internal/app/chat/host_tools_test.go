package chat

import (
	"context"
	"encoding/json"
	"testing"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// namedTool is a minimal Tool stub identified only by Name(); the on-demand
// gating tests care about which names are offered, not behavior.
//
// namedTool 是仅靠 Name() 区分的最小 Tool stub；按需加载测试只关心offer了哪些名字。
type namedTool struct{ name string }

func (t namedTool) Name() string                        { return t.name }
func (t namedTool) Description() string                 { return "stub" }
func (t namedTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t namedTool) IsReadOnly() bool                    { return true }
func (t namedTool) NeedsReadFirst() bool                { return false }
func (t namedTool) RequiresWorkspace() bool             { return false }
func (t namedTool) ValidateInput(json.RawMessage) error { return nil }
func (t namedTool) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t namedTool) Execute(context.Context, string) (string, error) { return "", nil }

func toolNames(tools []toolapp.Tool) map[string]bool {
	m := make(map[string]bool, len(tools))
	for _, t := range tools {
		m[t.Name()] = true
	}
	return m
}

func newToolsetHost() *chatHost {
	ts := toolapp.Toolset{
		Resident: []toolapp.Tool{namedTool{"activate_tools"}, namedTool{"Read"}},
		Lazy: map[string][]toolapp.Tool{
			"function": {namedTool{"create_function"}},
			"handler":  {namedTool{"edit_handler"}},
		},
	}
	return &chatHost{svc: &Service{toolset: ts}}
}

func TestChatHostTools_NoActivatedGroups_OnlyResident(t *testing.T) {
	h := newToolsetHost()
	state := &agentstatepkg.AgentState{}
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	names := toolNames(h.Tools(ctx))
	if !names["Read"] || !names["activate_tools"] {
		t.Errorf("resident tools missing: %v", names)
	}
	if names["create_function"] || names["edit_handler"] {
		t.Errorf("lazy tools leaked before activation: %v", names)
	}
}

func TestChatHostTools_AfterActivateFunction_IncludesFunctionGroupOnly(t *testing.T) {
	h := newToolsetHost()
	state := &agentstatepkg.AgentState{}
	state.ActivateGroup("function")
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	names := toolNames(h.Tools(ctx))
	if !names["create_function"] {
		t.Errorf("create_function not offered after ActivateGroup(function): %v", names)
	}
	if names["edit_handler"] {
		t.Errorf("edit_handler offered despite handler group NOT activated: %v", names)
	}
	if !names["Read"] {
		t.Errorf("resident Read dropped: %v", names)
	}
}

func TestChatHostTools_NoAgentState_OnlyResident(t *testing.T) {
	h := newToolsetHost()
	names := toolNames(h.Tools(context.Background()))
	if !names["Read"] || !names["activate_tools"] {
		t.Errorf("resident tools missing without AgentState: %v", names)
	}
	if names["create_function"] || names["edit_handler"] {
		t.Errorf("lazy tools leaked without AgentState: %v", names)
	}
}
