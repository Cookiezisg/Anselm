// edit.go — edit_handler system tool: applies ops to active version → pending.

package handler

import (
	"context"
	"encoding/json"
	"fmt"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
)

type EditHandler struct {
	svc *handlerapp.Service
}

func (t *EditHandler) Name() string { return "edit_handler" }

func (t *EditHandler) Description() string {
	return "Edit an existing handler by applying method-level ops on top of its active " +
		"version. Creates a new pending version (user must accept). Errors if a pending " +
		"already exists — caller must accept / reject first. Use update_method op for " +
		"in-place method body changes (JSON Merge Patch)."
}

func (t *EditHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id": {"type": "string"},
			"ops": {"type": "array", "items": {"type": "object"}},
			"changeReason": {"type": "string"}
		},
		"required": ["id", "ops"]
	}`)
}

func (t *EditHandler) IsReadOnly() bool        { return false }
func (t *EditHandler) NeedsReadFirst() bool    { return false }
func (t *EditHandler) RequiresWorkspace() bool { return false }

func (t *EditHandler) ValidateInput(json.RawMessage) error { return nil }
func (t *EditHandler) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *EditHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID           string          `json:"id"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_handler: bad args: %w", err)
	}
	if args.ID == "" {
		return "", fmt.Errorf("edit_handler: id required")
	}
	ops, err := handlerapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("edit_handler: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage": "applying ops", "count": len(ops), "handlerId": args.ID,
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	v, err := t.svc.Edit(ctx, handlerapp.EditInput{
		ID:              args.ID,
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("edit_handler: %w", err)
	}

	out := map[string]any{"pendingId": v.ID, "opsApplied": len(ops)}
	b, _ := json.Marshal(out)
	return string(b), nil
}
