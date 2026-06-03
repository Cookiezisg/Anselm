package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

type GetAgentExecution struct{ svc *agentapp.Service }

func (t *GetAgentExecution) Name() string { return "get_agent_execution" }

func (t *GetAgentExecution) Description() string {
	return "Get one full agent execution row (input, output, status, error, latency) plus machine hints. Find ids via search_agent_executions."
}

func (t *GetAgentExecution) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{"id":{"type":"string"}},"required":["id"]}`)
}

func (t *GetAgentExecution) IsReadOnly() bool        { return true }
func (t *GetAgentExecution) NeedsReadFirst() bool    { return false }
func (t *GetAgentExecution) RequiresWorkspace() bool { return false }

func (t *GetAgentExecution) ValidateInput(args json.RawMessage) error {
	var a struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(args, &a); err != nil || a.ID == "" {
		return fmt.Errorf("id is required")
	}
	return nil
}
func (t *GetAgentExecution) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *GetAgentExecution) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_agent_execution: %w", err)
	}
	detail, err := t.svc.GetExecutionDetail(ctx, args.ID)
	if err != nil {
		return "", fmt.Errorf("get_agent_execution: %w", err)
	}

	const limit = 256 * 1024 // 256KB, mirrors function get_execution buffer
	out := map[string]any{
		"id":             detail.ID,
		"status":         detail.Status,
		"triggeredBy":    detail.TriggeredBy,
		"agentId":        detail.AgentID,
		"versionId":      detail.VersionID,
		"startedAt":      detail.StartedAt.Format(time.RFC3339),
		"endedAt":        detail.EndedAt.Format(time.RFC3339),
		"elapsedMs":      detail.ElapsedMs,
		"input":          boundedJSON(detail.Input, limit),
		"output":         boundedJSON(detail.Output, limit),
		"errorMessage":   detail.ErrorMessage,
		"conversationId": detail.ConversationID,
		"flowrunId":      detail.FlowrunID,
		"hints":          detail.Hints,
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}

// boundedJSON renders a value as valid JSON when within limit, else a truncated string (mirrors functionapp tool helper).
func boundedJSON(v any, limit int) any {
	if v == nil {
		return json.RawMessage("null")
	}
	b, err := json.Marshal(v)
	if err != nil {
		return json.RawMessage("null")
	}
	if len(b) <= limit {
		return json.RawMessage(b)
	}
	return fmt.Sprintf("%s…[truncated, %d total bytes]", b[:limit], len(b))
}
