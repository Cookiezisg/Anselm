package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
)

// ListFailedSteps lists node failures from a flowrun's journal (highest-generation state).
// A step re-run successfully at a higher generation no longer appears. (M6 failures API)
type ListFailedSteps struct {
	repo flowrundomain.Repository
}

func (t *ListFailedSteps) Name() string { return "list_failed_steps" }
func (t *ListFailedSteps) Description() string {
	return `List the node failures from a flowrun's journal. Returns each failed step with nodeId, iterationKey, generation, and error message. Steps that were successfully re-run via :replay no longer appear. Use this to diagnose which nodes failed before using replay_flowrun.`
}
func (t *ListFailedSteps) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"flowrunId": {"type": "string", "description": "FlowRun ID to inspect"}
		},
		"required": ["flowrunId"]
	}`)
}
func (t *ListFailedSteps) IsReadOnly() bool        { return true }
func (t *ListFailedSteps) NeedsReadFirst() bool    { return false }
func (t *ListFailedSteps) RequiresWorkspace() bool { return false }
func (t *ListFailedSteps) ValidateInput(args json.RawMessage) error {
	var a struct{ FlowrunID string `json:"flowrunId"` }
	if err := json.Unmarshal(args, &a); err != nil {
		return err
	}
	if a.FlowrunID == "" {
		return fmt.Errorf("flowrunId is required")
	}
	return nil
}
func (t *ListFailedSteps) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *ListFailedSteps) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct{ FlowrunID string `json:"flowrunId"` }
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("list_failed_steps: bad args: %w", err)
	}
	nodes, _, err := t.repo.ListNodes(ctx, flowrundomain.NodeFilter{
		FlowrunID: args.FlowrunID,
		Status:    flowrundomain.NodeStatusFailed,
	})
	if err != nil {
		return "", fmt.Errorf("list_failed_steps: %w", err)
	}
	type failRow struct {
		NodeID  string `json:"nodeId"`
		Type    string `json:"nodeType"`
		Attempt int    `json:"attempts"`
		Error   string `json:"error,omitempty"`
	}
	rows := make([]failRow, 0, len(nodes))
	for _, n := range nodes {
		rows = append(rows, failRow{
			NodeID:  n.NodeID,
			Type:    n.NodeType,
			Attempt: n.Attempts,
			Error:   n.ErrorMessage,
		})
	}
	out := map[string]any{
		"flowrunId": args.FlowrunID,
		"count":     len(rows),
		"failures":  rows,
	}
	if len(rows) == 0 {
		out["message"] = "No failed steps found — the run may have succeeded or failures are hidden by a successful :replay."
	} else {
		out["next_step"] = "Use replay_flowrun with this flowrunId to re-run from the last failed step without re-executing already-completed steps."
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}

// ReplayFlowRun re-runs a failed flowrun starting from where it crashed.
// Completed steps are copy-hit from the journal; only the failed step and
// subsequent nodes are re-executed. (M6 :replay API)
type ReplayFlowRun struct {
	sched SchedulerReplayer
}

// SchedulerReplayer is the port for the :replay action.
type SchedulerReplayer interface {
	ReplayRun(ctx context.Context, flowrunID string) error
}

func (t *ReplayFlowRun) Name() string { return "replay_flowrun" }
func (t *ReplayFlowRun) Description() string {
	return `Re-run a failed flowrun from the crash point. Completed steps are NOT re-executed — only the failed step and any subsequent nodes run again. The run must be in 'failed' status; use list_failed_steps first to confirm which nodes failed.`
}
func (t *ReplayFlowRun) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"flowrunId": {"type": "string", "description": "FlowRun ID to replay (must be in failed status)"}
		},
		"required": ["flowrunId"]
	}`)
}
func (t *ReplayFlowRun) IsReadOnly() bool        { return false }
func (t *ReplayFlowRun) NeedsReadFirst() bool    { return true }
func (t *ReplayFlowRun) RequiresWorkspace() bool { return false }
func (t *ReplayFlowRun) ValidateInput(args json.RawMessage) error {
	var a struct{ FlowrunID string `json:"flowrunId"` }
	if err := json.Unmarshal(args, &a); err != nil {
		return err
	}
	if a.FlowrunID == "" {
		return fmt.Errorf("flowrunId is required")
	}
	return nil
}
func (t *ReplayFlowRun) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *ReplayFlowRun) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct{ FlowrunID string `json:"flowrunId"` }
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("replay_flowrun: bad args: %w", err)
	}
	if err := t.sched.ReplayRun(ctx, args.FlowrunID); err != nil {
		return "", fmt.Errorf("replay_flowrun: %w", err)
	}
	out := map[string]any{
		"flowrunId": args.FlowrunID,
		"resumed":   true,
		"message":   "Replay started. The run is now re-executing from the failed step. Use get_workflow_execution or search_workflow_executions to monitor progress.",
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
