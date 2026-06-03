package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

type SearchAgents struct{ svc *agentapp.Service }

func (t *SearchAgents) Name() string { return "search_agents" }
func (t *SearchAgents) Description() string {
	return "Find agents in the user's library by name/description substring (empty=list all). Returns id, name, description, activeVersionId. Inspect with get_agent before editing."
}
func (t *SearchAgents) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer"}}}`)
}
func (t *SearchAgents) IsReadOnly() bool                    { return true }
func (t *SearchAgents) NeedsReadFirst() bool                { return false }
func (t *SearchAgents) RequiresWorkspace() bool             { return false }
func (t *SearchAgents) ValidateInput(json.RawMessage) error { return nil }
func (t *SearchAgents) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *SearchAgents) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
		Limit int    `json:"limit"`
	}
	_ = json.Unmarshal([]byte(argsJSON), &args)
	limit := args.Limit
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	agents, _, err := t.svc.List(ctx, limit, "")
	if err != nil {
		return "", fmt.Errorf("search_agents: %w", err)
	}
	type row struct {
		ID              string `json:"id"`
		Name            string `json:"name"`
		Description     string `json:"description"`
		ActiveVersionID string `json:"activeVersionId,omitempty"`
	}
	q := args.Query
	out := make([]row, 0, len(agents))
	for _, a := range agents {
		if q != "" && !containsSub(a.Name, q) && !containsSub(a.Description, q) {
			continue
		}
		out = append(out, row{ID: a.ID, Name: a.Name, Description: a.Description, ActiveVersionID: a.ActiveVersionID})
	}
	b, _ := json.Marshal(map[string]any{"count": len(out), "agents": out})
	return string(b), nil
}
