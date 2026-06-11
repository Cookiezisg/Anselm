package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
)

// --- search_agent_executions -----------------------------------------------

type SearchAgentExecutions struct{ svc *agentapp.Service }

func (t *SearchAgentExecutions) Name() string { return "search_agent_executions" }

func (t *SearchAgentExecutions) Description() string {
	return "Search an agent's execution history (runs): filter by agentId / status / triggeredBy / conversationId / flowrunId, cursor-paged, with an ok-vs-failed rollup. Use get_agent_execution for one run's full input/output."
}

func (t *SearchAgentExecutions) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"agentId": {"type": "string"},
			"status": {"type": "string", "enum": ["ok", "failed", "cancelled", "timeout"]},
			"triggeredBy": {"type": "string", "enum": ["chat", "workflow", "manual"]},
			"conversationId": {"type": "string"},
			"flowrunId": {"type": "string"},
			"limit": {"type": "integer"},
			"cursor": {"type": "string"}
		}
	}`)
}

func (t *SearchAgentExecutions) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchAgentExecutions) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		AgentID        string `json:"agentId"`
		Status         string `json:"status"`
		TriggeredBy    string `json:"triggeredBy"`
		ConversationID string `json:"conversationId"`
		FlowrunID      string `json:"flowrunId"`
		Limit          int    `json:"limit"`
		Cursor         string `json:"cursor"`
	}
	if strings.TrimSpace(argsJSON) != "" {
		if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
			return "", fmt.Errorf("search_agent_executions: bad args: %w", err)
		}
	}
	res, err := t.svc.SearchExecutions(ctx, agentdomain.ExecutionFilter{
		AgentID:        a.AgentID,
		Status:         a.Status,
		TriggeredBy:    a.TriggeredBy,
		ConversationID: a.ConversationID,
		FlowrunID:      a.FlowrunID,
		Limit:          a.Limit,
		Cursor:         a.Cursor,
	})
	if err != nil {
		return "", fmt.Errorf("search_agent_executions: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

// --- get_agent_execution ---------------------------------------------------

type GetAgentExecution struct{ svc *agentapp.Service }

func (t *GetAgentExecution) Name() string { return "get_agent_execution" }

func (t *GetAgentExecution) Description() string {
	return "Get one agent execution's full record by id: input, output, status, error message, timing, and the model that ran."
}

func (t *GetAgentExecution) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","required":["executionId"],"properties":{"executionId":{"type":"string"}}}`)
}

func (t *GetAgentExecution) ValidateInput(args json.RawMessage) error {
	var a struct {
		ExecutionID string `json:"executionId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_agent_execution: bad args: %w", err)
	}
	if strings.TrimSpace(a.ExecutionID) == "" {
		return ErrExecutionIDRequired
	}
	return nil
}

func (t *GetAgentExecution) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		ExecutionID string `json:"executionId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("get_agent_execution: bad args: %w", err)
	}
	e, err := t.svc.GetExecutionDetail(ctx, a.ExecutionID)
	if err != nil {
		return "", fmt.Errorf("get_agent_execution: %w", err)
	}
	return toolapp.ToJSON(e), nil
}
