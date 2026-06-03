package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

type GetAgent struct{ svc *agentapp.Service }

func (t *GetAgent) Name() string { return "get_agent" }
func (t *GetAgent) Description() string {
	return "Get full agent details: prompt, skill, knowledge, tools, outputSchema, active version and pending version if any. Use before editing."
}
func (t *GetAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{"id":{"type":"string"}},"required":["id"]}`)
}
func (t *GetAgent) IsReadOnly() bool        { return true }
func (t *GetAgent) NeedsReadFirst() bool    { return false }
func (t *GetAgent) RequiresWorkspace() bool { return false }
func (t *GetAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil || a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *GetAgent) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *GetAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_agent: %w", err)
	}
	a, err := t.svc.Get(ctx, args.ID)
	if err != nil {
		return "", fmt.Errorf("get_agent: %w", err)
	}
	b, _ := json.Marshal(a)
	return string(b), nil
}
