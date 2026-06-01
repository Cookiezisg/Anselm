package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// CapabilityCheckWorkflow is an LLM tool that validates a workflow's active version:
// checks entity refs (functionId / handlerName / serverName exist), graph structure
// (no dangling edges, no unreachable nodes), and returns issues with next_step guidance
// so the LLM can fix them in a follow-up edit.
//
// CapabilityCheckWorkflow 让 LLM 在 create/edit 后校验 workflow（真查 ref + lint），
// 返带 next_step 的错误列表让 LLM 自修。
type CapabilityCheckWorkflow struct {
	svc *workflowapp.Service
}

func (t *CapabilityCheckWorkflow) Name() string { return "capability_check_workflow" }

func (t *CapabilityCheckWorkflow) Description() string {
	return `Validate a workflow's active version BEFORE accepting: checks all entity references (functionId / handlerName / serverName / skillName actually exist), graph structure (no dangling edges, cycles, unreachable nodes), and config shapes.

Returns {ok:true} on success, or {ok:false, issues:[{severity, nodeId, message, next_step}]} on failure.

ALWAYS call this after create_workflow or edit_workflow and before asking the user to accept. Fix all issues first — the LLM can re-edit and re-check.`
}

func (t *CapabilityCheckWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id": {"type": "string", "description": "Workflow ID to check"}
		},
		"required": ["id"]
	}`)
}

func (t *CapabilityCheckWorkflow) IsReadOnly() bool        { return true }
func (t *CapabilityCheckWorkflow) NeedsReadFirst() bool    { return false }
func (t *CapabilityCheckWorkflow) RequiresWorkspace() bool { return false }
func (t *CapabilityCheckWorkflow) ValidateInput(args json.RawMessage) error {
	var a struct{ ID string `json:"id"` }
	if err := json.Unmarshal(args, &a); err != nil {
		return err
	}
	if a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *CapabilityCheckWorkflow) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *CapabilityCheckWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("capability_check_workflow: bad args: %w", err)
	}

	report, err := t.svc.CapabilityCheck(ctx, args.ID)
	if err != nil {
		return "", fmt.Errorf("capability_check_workflow: %w", err)
	}

	// Enrich issues with next_step guidance so the LLM can self-correct.
	type issueOut struct {
		Severity string `json:"severity"`
		NodeID   string `json:"nodeId,omitempty"`
		Message  string `json:"message"`
		NextStep string `json:"next_step"`
	}
	issues := make([]issueOut, 0, len(report.Issues))
	for _, iss := range report.Issues {
		nextStep := deriveNextStep(iss.Message)
		issues = append(issues, issueOut{
			Severity: iss.Severity,
			NodeID:   iss.NodeID,
			Message:  iss.Message,
			NextStep: nextStep,
		})
	}

	out := map[string]any{
		"ok":     report.OK,
		"issues": issues,
	}
	if report.OK {
		out["message"] = "Workflow is valid — all entity refs exist and graph is well-formed."
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}

// deriveNextStep provides actionable guidance for the LLM based on the issue message.
func deriveNextStep(msg string) string {
	// Common patterns from ValidateGraph errors.
	switch {
	case contains(msg, "not found", "ErrCapabilityNotFound"):
		return "The referenced entity does not exist. Use search_function/search_handler/search_mcp_tools to find the correct ID, or create the entity first, then edit_workflow to fix the reference."
	case contains(msg, "missing functionId", "missing handlerName", "missing serverName", "missing skillName"):
		return "The node config is missing a required reference field. Use edit_workflow to add the correct functionId/handlerName/serverName/skillName."
	case contains(msg, "no trigger node"):
		return "Add a trigger node (type: trigger) connected to the workflow entry point."
	case contains(msg, "cycle", "circular"):
		return "Remove the back-edge that creates a non-structured cycle, or restructure using a case node back-edge loop."
	case contains(msg, "no active version"):
		return "Accept a pending version first via the UI, then re-check."
	case contains(msg, "missing required"):
		return "The node config is missing a required field. Use edit_workflow to add it."
	default:
		return "Use edit_workflow to fix the issue described above, then call capability_check_workflow again."
	}
}

func contains(s string, subs ...string) bool {
	for _, sub := range subs {
		if len(sub) > 0 {
			for i := 0; i <= len(s)-len(sub); i++ {
				if s[i:i+len(sub)] == sub {
					return true
				}
			}
		}
	}
	return false
}
