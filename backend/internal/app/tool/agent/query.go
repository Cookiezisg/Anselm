package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
)

// --- search_agent ----------------------------------------------------------

type SearchAgent struct{ svc *agentapp.Service }

func (t *SearchAgent) Name() string { return "search_agent" }

func (t *SearchAgent) Description() string {
	return "Find agents by case-insensitive substring over name / description / tags. Returns id + name + description; empty query lists all. Use get_agent for the full config (prompt / mounted skill / knowledge / tools)."
}

func (t *SearchAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{"query":{"type":"string","description":"Substring to match; omit or empty to list all."}}}`)
}

func (t *SearchAgent) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if strings.TrimSpace(argsJSON) != "" {
		if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
			return "", fmt.Errorf("search_agent: bad args: %w", err)
		}
	}
	ags, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_agent: %w", err)
	}
	type slim struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	out := make([]slim, 0, len(ags))
	for _, a := range ags {
		out = append(out, slim{ID: a.ID, Name: a.Name, Description: a.Description})
	}
	return toJSON(map[string]any{"agents": out, "count": len(out)}), nil
}

// --- get_agent -------------------------------------------------------------

type GetAgent struct{ svc *agentapp.Service }

func (t *GetAgent) Name() string { return "get_agent" }

func (t *GetAgent) Description() string {
	return "Get an agent's full configuration: prompt, mounted skill, knowledge document IDs, tool refs, outputSchema, and model override — via its active version. Read this before edit_agent (edit replaces the whole config)."
}

func (t *GetAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","required":["agentId"],"properties":{"agentId":{"type":"string"}}}`)
}

func (t *GetAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		AgentID string `json:"agentId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_agent: bad args: %w", err)
	}
	if strings.TrimSpace(a.AgentID) == "" {
		return ErrAgentIDRequired
	}
	return nil
}

func (t *GetAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		AgentID string `json:"agentId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("get_agent: bad args: %w", err)
	}
	ag, err := t.svc.Get(ctx, a.AgentID)
	if err != nil {
		return "", fmt.Errorf("get_agent: %w", err)
	}
	return toJSON(ag), nil
}
