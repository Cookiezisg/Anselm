// create.go — create_workflow system tool: streams 1 progress delta per
// op via the eventlog Emitter, double-writes forge_started + forge_completed
// on the forge bus (C4 D-redo-4). Unlike create_function / handler there
// is NO env install — workflow validation is graph-shape only — so no
// env-fix loop (envfix). v1 auto-accepts on success.
//
// create.go —— create_workflow:每 op 推 progress delta,双写 forge bus
// (forge_started + forge_completed)。workflow 无 env 装,无 envfix loop。
// v1 自动 accept。

package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	forgepkg "github.com/sunweilin/forgify/backend/internal/pkg/forge"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type CreateWorkflow struct {
	svc   *workflowapp.Service
	forge forgepkg.Publisher
}

func (t *CreateWorkflow) Name() string { return "create_workflow" }

func (t *CreateWorkflow) Description() string {
	return "Create a new workflow by applying a sequence of ops. The ops must " +
		"build a valid DAG with at least one trigger node and reference only " +
		"existing capabilities (functions / handlers / mcp servers / skills). " +
		"V1 auto-accepts the created workflow as v1. Use set_meta first to give " +
		"it a name + description, then add_node / add_edge to build the graph."
}

func (t *CreateWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"ops": {
				"type": "array",
				"description": "Sequence of ops (set_meta / add_node / add_edge / set_variable / ...)",
				"items": {"type": "object"}
			},
			"changeReason": {"type": "string", "description": "One-line reason"}
		},
		"required": ["ops"]
	}`)
}

func (t *CreateWorkflow) IsReadOnly() bool        { return false }
func (t *CreateWorkflow) NeedsReadFirst() bool    { return false }
func (t *CreateWorkflow) RequiresWorkspace() bool { return false }

func (t *CreateWorkflow) ValidateInput(json.RawMessage) error { return nil }
func (t *CreateWorkflow) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *CreateWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_workflow: bad args: %w", err)
	}
	ops, err := workflowapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_workflow: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage": "applying ops",
		"count": len(ops),
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	w, v, err := t.svc.Create(ctx, workflowapp.CreateInput{
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		// We don't know the workflow ID (Create failed before persistence),
		// so we can't publish forge_started/completed for this failure path.
		// Caller sees the wrapped err via the tool_result.
		// Create 失败前无 workflow ID,无法发 forge 事件,err 经 tool_result 抛。
		return "", fmt.Errorf("create_workflow: %w", err)
	}

	scope := eventlogdomain.Scope{Kind: eventlogdomain.KindWorkflow, ID: w.ID}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	t.forge.PublishStarted(ctx, scope, forgedomain.OperationCreate, convID, toolCallID)
	t.forge.PublishCompleted(ctx, scope, forgedomain.CompletedOK, v.ID, "", 1, nil)

	versionN := 1
	if v.Version != nil {
		versionN = *v.Version
	}
	out := map[string]any{
		"id":         w.ID,
		"name":       w.Name,
		"versionId":  v.ID,
		"version":    versionN,
		"status":     v.Status,
		"opsApplied": len(ops),
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
