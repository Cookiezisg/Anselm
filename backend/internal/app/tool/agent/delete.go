package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

type DeleteAgent struct{ svc *agentapp.Service }

func (t *DeleteAgent) Name() string { return "delete_agent" }
func (t *DeleteAgent) Description() string {
	return "Soft-delete an agent. Workflows referencing it become needs_attention."
}
func (t *DeleteAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{"id":{"type":"string"}},"required":["id"]}`)
}
func (t *DeleteAgent) IsReadOnly() bool        { return false }
func (t *DeleteAgent) NeedsReadFirst() bool    { return false }
func (t *DeleteAgent) RequiresWorkspace() bool { return false }
func (t *DeleteAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil || a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *DeleteAgent) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *DeleteAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_agent: %w", err)
	}
	if err := t.svc.Delete(ctx, args.ID); err != nil {
		return "", fmt.Errorf("delete_agent: %w", err)
	}
	b, _ := json.Marshal(map[string]any{"deleted": true, "id": args.ID})
	return string(b), nil
}
