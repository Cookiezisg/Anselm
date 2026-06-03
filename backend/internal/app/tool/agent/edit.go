package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

type EditAgent struct{ svc *agentapp.Service }

func (t *EditAgent) Name() string { return "edit_agent" }
func (t *EditAgent) Description() string {
	return `Edit an agent — creates a pending version. Repeated edits rewrite the same pending (iterate-same-pending). The user accepts or rejects the pending via the UI.

tools field is REPLACE (not merge) — include ALL tools you want, not just changed ones.`
}
func (t *EditAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"id":           {"type": "string"},
			"prompt":       {"type": "string"},
			"skill":        {"type": "string"},
			"knowledge":    {"type": "array", "items": {"type":"string"}},
			"tools":        {"type": "array", "items": {"type":"object"}, "description": "REPLACE semantics — include all tools"},
			"outputSchema": {"type": "object"},
			"modelOverride":{"type": "object", "description": "Optional model override {apiKeyId, modelId, options?}; omit to keep current/default", "properties": {"apiKeyId":{"type":"string"},"modelId":{"type":"string"}}},
			"changeReason": {"type": "string"}
		},
		"required": ["id"]
	}`)
}
func (t *EditAgent) IsReadOnly() bool        { return false }
func (t *EditAgent) NeedsReadFirst() bool    { return true }
func (t *EditAgent) RequiresWorkspace() bool { return false }
func (t *EditAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil || a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *EditAgent) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *EditAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID            string                    `json:"id"`
		Prompt        *string                   `json:"prompt"`
		Skill         *string                   `json:"skill"`
		Knowledge     []string                  `json:"knowledge"`
		Tools         []agentdomain.ToolRef     `json:"tools"`
		OutputSchema  *agentdomain.OutputSchema `json:"outputSchema"`
		ModelOverride *modeldomain.ModelRef     `json:"modelOverride"`
		ChangeReason  string                    `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_agent: %w", err)
	}
	v, err := t.svc.Edit(ctx, agentapp.EditInput{
		ID: args.ID, Prompt: args.Prompt, Skill: args.Skill,
		Knowledge: args.Knowledge, Tools: args.Tools,
		OutputSchema: args.OutputSchema, ModelOverride: args.ModelOverride,
		ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("edit_agent: %w", err)
	}
	b, _ := json.Marshal(map[string]any{"pendingId": v.ID, "agentId": args.ID})
	return string(b), nil
}
