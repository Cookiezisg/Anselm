package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

type RevertAgent struct{ svc *agentapp.Service }

func (t *RevertAgent) Name() string { return "revert_agent" }
func (t *RevertAgent) Description() string {
	return "Revert an agent's active version to a previously-accepted version number. List versions via get_agent."
}
func (t *RevertAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id":            {"type": "string"},
			"targetVersion": {"type": "integer", "description": "Version number to revert to (must be already accepted)"}
		},
		"required": ["id", "targetVersion"]
	}`)
}
func (t *RevertAgent) IsReadOnly() bool        { return false }
func (t *RevertAgent) NeedsReadFirst() bool    { return false }
func (t *RevertAgent) RequiresWorkspace() bool { return false }
func (t *RevertAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil || a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *RevertAgent) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *RevertAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID            string `json:"id"`
		TargetVersion int    `json:"targetVersion"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("revert_agent: %w", err)
	}
	v, err := t.svc.Revert(ctx, args.ID, args.TargetVersion)
	if err != nil {
		return "", fmt.Errorf("revert_agent: %w", err)
	}
	out := map[string]any{"agentId": args.ID, "versionId": v.ID, "targetVersion": v.Version}
	b, _ := json.Marshal(out)
	return string(b), nil
}
