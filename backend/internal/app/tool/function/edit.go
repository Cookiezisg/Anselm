// edit.go — edit_function system tool: applies a sequence of ops on top of
// the current active version, creating a new pending version. Refuses if a
// pending already exists (UI must accept / reject first).
//
// edit.go —— edit_function 系统工具:在活跃版本基础上应用 ops 创建新 pending。
// 已有 pending 时拒绝(UI 必须先 accept/reject)。

package function

import (
	"context"
	"encoding/json"
	"fmt"

	functionapp "github.com/sunweilin/forgify/backend/internal/app/function"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
)

type EditFunction struct {
	svc *functionapp.Service
}

func (t *EditFunction) Name() string { return "edit_function" }

func (t *EditFunction) Description() string {
	return "Edit an existing function by applying a sequence of ops on top of its " +
		"current active version. Creates a new pending version awaiting user accept. " +
		"Errors if a pending already exists — caller must accept / reject the existing " +
		"pending first."
}

func (t *EditFunction) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id": {"type": "string", "description": "Function ID to edit"},
			"ops": {
				"type": "array",
				"description": "Sequence of ops to apply (see create_function).",
				"items": {"type": "object"}
			},
			"changeReason": {"type": "string", "description": "One-line reason for this edit"}
		},
		"required": ["id", "ops"]
	}`)
}

func (t *EditFunction) IsReadOnly() bool        { return false }
func (t *EditFunction) NeedsReadFirst() bool    { return false }
func (t *EditFunction) RequiresWorkspace() bool { return false }

func (t *EditFunction) ValidateInput(json.RawMessage) error { return nil }
func (t *EditFunction) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *EditFunction) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID           string          `json:"id"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_function: bad args: %w", err)
	}
	if args.ID == "" {
		return "", fmt.Errorf("edit_function: id required")
	}
	ops, err := functionapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("edit_function: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage":      "applying ops",
		"count":      len(ops),
		"functionId": args.ID,
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	v, err := t.svc.Edit(ctx, functionapp.EditInput{
		ID:              args.ID,
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("edit_function: %w", err)
	}

	out := map[string]any{
		"pendingId":  v.ID,
		"opsApplied": len(ops),
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
