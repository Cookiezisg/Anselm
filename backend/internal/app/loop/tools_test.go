// tools_test.go — exercises the framework permission integration: when
// AgentState has an active skill that pre-approves a tool, executeTool
// must skip per-tool CheckPermissions entirely and proceed straight to
// Execute. Without an active skill, the existing per-tool permission
// path remains the gate.
//
// tools_test.go ——验 framework 权限集成：AgentState 有 active skill 且
// 预授权 tool 时，executeTool 必须整个跳 per-tool CheckPermissions 直接
// Execute；无 active skill 时仍走 per-tool 门控。
package loop

import (
	"context"
	"encoding/json"
	"testing"

	"go.uber.org/zap/zaptest"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// alwaysDenyTool is a stub Tool whose CheckPermissions returns Deny so
// the test can prove that pre-approval bypasses CheckPermissions
// (otherwise the call would be denied).
//
// alwaysDenyTool 是 stub Tool；CheckPermissions 返 Deny 以证明预授权绕
// 过 CheckPermissions（否则会被拒）。
type alwaysDenyTool struct {
	name       string
	executed   bool
	permChecks int
}

func (t *alwaysDenyTool) Name() string                                 { return t.name }
func (t *alwaysDenyTool) Description() string                          { return "stub" }
func (t *alwaysDenyTool) Parameters() json.RawMessage                  { return json.RawMessage(`{"type":"object"}`) }
func (t *alwaysDenyTool) IsReadOnly() bool                             { return true }
func (t *alwaysDenyTool) NeedsReadFirst() bool                         { return false }
func (t *alwaysDenyTool) RequiresWorkspace() bool                      { return false }
func (t *alwaysDenyTool) ValidateInput(json.RawMessage) error          { return nil }
func (t *alwaysDenyTool) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	t.permChecks++
	return toolapp.PermissionDeny
}
func (t *alwaysDenyTool) Execute(_ context.Context, _ string) (string, error) {
	t.executed = true
	return "executed", nil
}

func TestExecuteTool_NoActiveSkill_HonorsCheckPermissions(t *testing.T) {
	stub := &alwaysDenyTool{name: "Bash"}
	log := zaptest.NewLogger(t)
	output, errMsg, ok := executeTool(context.Background(), stub, "Bash",
		json.RawMessage(`{"command":"git status"}`), log)

	if ok {
		t.Errorf("ok=true; expected false (CheckPermissions denied)")
	}
	if stub.executed {
		t.Errorf("Execute ran despite Deny")
	}
	if stub.permChecks != 1 {
		t.Errorf("permChecks = %d, want 1", stub.permChecks)
	}
	if errMsg != "permission denied" {
		t.Errorf("errMsg = %q, want %q", errMsg, "permission denied")
	}
	if output != "permission denied for this call" {
		t.Errorf("output = %q", output)
	}
}

func TestExecuteTool_ActiveSkillPreApproves_BypassesCheckPermissions(t *testing.T) {
	stub := &alwaysDenyTool{name: "Bash"}
	log := zaptest.NewLogger(t)

	state := &agentstatepkg.AgentState{}
	state.SetActiveSkill(&skilldomain.Skill{
		Name: "deploy",
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash(git *)"},
		},
	})
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	output, errMsg, ok := executeTool(ctx, stub, "Bash",
		json.RawMessage(`{"command":"git status"}`), log)

	if !ok {
		t.Errorf("ok=false; expected true (pre-approved by active skill)")
	}
	if !stub.executed {
		t.Errorf("Execute did not run despite pre-approval")
	}
	if stub.permChecks != 0 {
		t.Errorf("permChecks = %d, want 0 (pre-approval must skip CheckPermissions entirely)",
			stub.permChecks)
	}
	if errMsg != "" {
		t.Errorf("errMsg = %q, want empty", errMsg)
	}
	if output != "executed" {
		t.Errorf("output = %q, want 'executed'", output)
	}
}

func TestExecuteTool_ActiveSkillNoMatch_FallsBackToCheckPermissions(t *testing.T) {
	stub := &alwaysDenyTool{name: "Read"}
	log := zaptest.NewLogger(t)

	// Active skill exists, but allowed-tools doesn't list 'Read' — so
	// the pre-approval check returns false, and executeTool falls back
	// to t.CheckPermissions, which here denies.
	// 有 active skill，但 allowed-tools 不含 Read——预授权返 false，
	// 退回 t.CheckPermissions（此处 deny）。
	state := &agentstatepkg.AgentState{}
	state.SetActiveSkill(&skilldomain.Skill{
		Name: "deploy",
		Frontmatter: skilldomain.Frontmatter{
			AllowedTools: []string{"Bash"},
		},
	})
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	_, _, ok := executeTool(ctx, stub, "Read", json.RawMessage(`{}`), log)
	if ok {
		t.Errorf("ok=true; expected CheckPermissions still gates non-listed tool")
	}
	if stub.permChecks != 1 {
		t.Errorf("permChecks = %d, want 1 (fallback to CheckPermissions)", stub.permChecks)
	}
}
