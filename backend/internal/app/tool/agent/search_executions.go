package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
)

type SearchAgentExecutions struct{ svc *agentapp.Service }

func (t *SearchAgentExecutions) Name() string { return "search_agent_executions" }

func (t *SearchAgentExecutions) Description() string {
	return "Search the agent execution log; filters: agentId, versionId, status, conversationId, flowrunId, since/until (ISO8601). " +
		"Returns 200-byte previews + status/latency aggregates. get_agent_execution for one full row."
}

func (t *SearchAgentExecutions) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"agentId":        {"type": "string", "description": "Filter to one agent"},
			"versionId":      {"type": "string", "description": "Filter to one version"},
			"status":         {"type": "string", "enum": ["ok","failed","cancelled","timeout"]},
			"conversationId": {"type": "string"},
			"flowrunId":      {"type": "string"},
			"since":          {"type": "string", "description": "ISO8601 lower bound on startedAt"},
			"until":          {"type": "string", "description": "ISO8601 upper bound on startedAt"},
			"limit":          {"type": "integer", "description": "Max rows (1-200, default 50)"},
			"cursor":         {"type": "string", "description": "Opaque pagination token from prior call"}
		}
	}`)
}

func (t *SearchAgentExecutions) IsReadOnly() bool        { return true }
func (t *SearchAgentExecutions) NeedsReadFirst() bool    { return false }
func (t *SearchAgentExecutions) RequiresWorkspace() bool { return false }

func (t *SearchAgentExecutions) ValidateInput(json.RawMessage) error { return nil }
func (t *SearchAgentExecutions) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *SearchAgentExecutions) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		AgentID        string `json:"agentId"`
		VersionID      string `json:"versionId"`
		Status         string `json:"status"`
		ConversationID string `json:"conversationId"`
		FlowrunID      string `json:"flowrunId"`
		Since          string `json:"since"`
		Until          string `json:"until"`
		Limit          int    `json:"limit"`
		Cursor         string `json:"cursor"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_agent_executions: bad args: %w", err)
	}
	filter := agentdomain.ExecutionFilter{
		AgentID:        args.AgentID,
		VersionID:      args.VersionID,
		Status:         args.Status,
		ConversationID: args.ConversationID,
		FlowrunID:      args.FlowrunID,
		Limit:          args.Limit,
		Cursor:         args.Cursor,
	}
	if args.Since != "" {
		ts, err := time.Parse(time.RFC3339, args.Since)
		if err != nil {
			return "", fmt.Errorf("search_agent_executions: since not RFC3339: %w", err)
		}
		filter.Since = &ts
	}
	if args.Until != "" {
		ts, err := time.Parse(time.RFC3339, args.Until)
		if err != nil {
			return "", fmt.Errorf("search_agent_executions: until not RFC3339: %w", err)
		}
		filter.Until = &ts
	}
	res, err := t.svc.SearchExecutions(ctx, filter)
	if err != nil {
		return "", fmt.Errorf("search_agent_executions: %w", err)
	}

	type previewRow struct {
		ID             string `json:"id"`
		Status         string `json:"status"`
		StartedAt      string `json:"startedAt"`
		ElapsedMs      int64  `json:"elapsedMs"`
		AgentID        string `json:"agentId"`
		VersionID      string `json:"versionId"`
		InputPreview   string `json:"inputPreview"`
		OutputPreview  string `json:"outputPreview"`
		ErrorMessage   string `json:"errorMessage,omitempty"`
		ConversationID string `json:"conversationId,omitempty"`
	}
	previews := make([]previewRow, 0, len(res.Executions))
	for _, e := range res.Executions {
		previews = append(previews, previewRow{
			ID: e.ID, Status: e.Status, StartedAt: e.StartedAt.Format(time.RFC3339),
			ElapsedMs: e.ElapsedMs, AgentID: e.AgentID, VersionID: e.VersionID,
			InputPreview:   truncateJSON(e.Input, 200),
			OutputPreview:  truncateJSON(e.Output, 200),
			ErrorMessage:   e.ErrorMessage,
			ConversationID: e.ConversationID,
		})
	}

	out := map[string]any{
		"count":      res.Count,
		"executions": previews,
		"hasMore":    res.HasMore,
		"nextCursor": res.NextCursor,
		"aggregates": res.Aggregates,
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}

// truncateJSON marshals v to compact JSON and truncates to max bytes (mirrors functionapp tool helper).
func truncateJSON(v any, max int) string {
	if v == nil {
		return ""
	}
	b, err := json.Marshal(v)
	if err != nil {
		return ""
	}
	if len(b) <= max {
		return string(b)
	}
	return string(b[:max]) + "…"
}
