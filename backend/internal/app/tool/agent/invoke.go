package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
)

type InvokeAgent struct{ svc *agentapp.Service }

func (t *InvokeAgent) Name() string { return "invoke_agent" }

func (t *InvokeAgent) Description() string {
	return "Run an agent with input; returns {ok, output, status, steps, tokensIn, tokensOut, executionId}. Real run (consumes tokens, records an execution). Mirrors run_function for agents."
}

func (t *InvokeAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"agentId": {"type": "string"},
			"version": {"type": "string", "description": "Omit for active version"},
			"input":   {"type": "object", "description": "Data fed to the agent"}
		},
		"required": ["agentId"]
	}`)
}

func (t *InvokeAgent) IsReadOnly() bool        { return false }
func (t *InvokeAgent) NeedsReadFirst() bool    { return false }
func (t *InvokeAgent) RequiresWorkspace() bool { return false }

func (t *InvokeAgent) ValidateInput(json.RawMessage) error { return nil }
func (t *InvokeAgent) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *InvokeAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		AgentID string         `json:"agentId"`
		Version string         `json:"version"`
		Input   map[string]any `json:"input"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("invoke_agent: bad args: %w", err)
	}
	if args.AgentID == "" {
		return "", fmt.Errorf("invoke_agent: agentId required")
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage":   "invoking",
		"agentId": args.AgentID,
	})

	res, err := t.svc.InvokeAgent(ctx, agentapp.InvokeInput{
		AgentID:     args.AgentID,
		VersionID:   args.Version,
		Input:       args.Input,
		TriggeredBy: agentdomain.TriggeredByChat,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		return "", fmt.Errorf("invoke_agent: %w", err)
	}
	em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	b, _ := json.Marshal(res)
	return string(b), nil
}
