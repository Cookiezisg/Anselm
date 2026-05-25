package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	schedulerapp "github.com/sunweilin/forgify/backend/internal/app/scheduler"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// WorkflowStarter is the scheduler entry point trigger_workflow needs; the real
// impl is schedulerapp.Service. Narrow port so the tool stays unit-testable.
//
// WorkflowStarter 是 trigger_workflow 需要的 scheduler 入口（真身 schedulerapp.Service）。
// 收窄成 port 便于单测。
type WorkflowStarter interface {
	StartRunWithOptions(ctx context.Context, workflowID, triggerKind string, input map[string]any, opts schedulerapp.StartRunOptions) (string, error)
}

// TriggerWorkflow starts a run of a workflow's active version (the orchestrator's
// execution entry; subagents never get this tool — D21).
//
// TriggerWorkflow 启动 workflow active 版本的一次运行（编排者的执行入口；
// 子代理永远拿不到此工具 — D21）。
type TriggerWorkflow struct {
	sched WorkflowStarter
}

func (t *TriggerWorkflow) Name() string { return "trigger_workflow" }

func (t *TriggerWorkflow) Description() string {
	return "Start a run of a workflow's active version. dryRun=true mocks side-effect " +
		"nodes (function/handler/mcp/http) so you can validate the DAG without real " +
		"effects. Returns the flowrunId; inspect node results via search_workflow_executions / get_workflow_execution."
}

func (t *TriggerWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"workflowId": {"type": "string", "description": "Workflow ID (wf_xxx)"},
			"dryRun": {"type": "boolean", "description": "Mock side-effect nodes; validate the DAG without real effects. Default false."},
			"input": {"type": "object", "description": "Trigger input handed to the workflow's trigger node. Optional."}
		},
		"required": ["workflowId"]
	}`)
}

func (t *TriggerWorkflow) IsReadOnly() bool        { return false }
func (t *TriggerWorkflow) NeedsReadFirst() bool    { return false }
func (t *TriggerWorkflow) RequiresWorkspace() bool { return false }

func (t *TriggerWorkflow) ValidateInput(json.RawMessage) error { return nil }
func (t *TriggerWorkflow) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *TriggerWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		WorkflowID string         `json:"workflowId"`
		DryRun     bool           `json:"dryRun"`
		Input      map[string]any `json:"input"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("trigger_workflow: bad args: %w", err)
	}
	if args.WorkflowID == "" {
		return "", fmt.Errorf("trigger_workflow: workflowId required")
	}
	runID, err := t.sched.StartRunWithOptions(ctx, args.WorkflowID, "manual", args.Input,
		schedulerapp.StartRunOptions{DryRun: args.DryRun})
	if err != nil {
		return "", fmt.Errorf("trigger_workflow: %w", err)
	}
	b, _ := json.Marshal(map[string]any{"flowrunId": runID, "dryRun": args.DryRun, "status": "started"})
	return string(b), nil
}
