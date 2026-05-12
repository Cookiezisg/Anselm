// edit.go — edit_workflow system tool: applies ops on top of current
// pending (or active if no pending) under iterate-same-pending semantic
// (D-redo-11). Workflow has no env install so unlike function / handler
// edit, there's no env-fix loop — just ops apply + validate + save.
//
// edit.go —— edit_workflow:iterate-same-pending(D-redo-11);workflow 无
// env 装,只跑 ops apply + validate + save。

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

type EditWorkflow struct {
	svc   *workflowapp.Service
	forge forgepkg.Publisher
}

func (t *EditWorkflow) Name() string { return "edit_workflow" }

func (t *EditWorkflow) Description() string {
	return "Edit an existing workflow by applying a sequence of ops. " +
		"Iterate-same-pending semantic — repeated edits while a pending " +
		"exists rewrite the same pending row (no ErrPendingConflict). " +
		"User must accept_pending or reject_pending the result. Use " +
		"update_node patch:{...} for in-place field changes (RFC 7396 " +
		"JSON Merge Patch)."
}

func (t *EditWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id": {"type": "string", "description": "Workflow ID (wf_xxx)"},
			"ops": {
				"type": "array",
				"description": "Sequence of ops to apply on top of current pending (or active if no pending)",
				"items": {"type": "object"}
			},
			"changeReason": {"type": "string", "description": "One-line reason"}
		},
		"required": ["id", "ops"]
	}`)
}

func (t *EditWorkflow) IsReadOnly() bool        { return false }
func (t *EditWorkflow) NeedsReadFirst() bool    { return false }
func (t *EditWorkflow) RequiresWorkspace() bool { return false }

func (t *EditWorkflow) ValidateInput(json.RawMessage) error { return nil }
func (t *EditWorkflow) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *EditWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID           string          `json:"id"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_workflow: bad args: %w", err)
	}
	if args.ID == "" {
		return "", fmt.Errorf("edit_workflow: id required")
	}
	ops, err := workflowapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("edit_workflow: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage":      "applying ops",
		"count":      len(ops),
		"workflowId": args.ID,
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	scope := eventlogdomain.Scope{Kind: eventlogdomain.KindWorkflow, ID: args.ID}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	t.forge.PublishStarted(ctx, scope, forgedomain.OperationEdit, convID, toolCallID)

	v, err := t.svc.Edit(ctx, workflowapp.EditInput{
		ID:              args.ID,
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		t.forge.PublishCompleted(ctx, scope, forgedomain.CompletedFailed, "", "", 0, err)
		return "", fmt.Errorf("edit_workflow: %w", err)
	}
	t.forge.PublishCompleted(ctx, scope, forgedomain.CompletedOK, v.ID, "", 1, nil)

	out := map[string]any{
		"pendingId":  v.ID,
		"opsApplied": len(ops),
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
