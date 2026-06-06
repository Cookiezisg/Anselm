package trigger

import (
	"context"
	"encoding/json"
	"fmt"

	triggerapp "github.com/sunweilin/forgify/backend/internal/app/trigger"
)

// --- search_triggers -------------------------------------------------------

type SearchTriggers struct{ svc *triggerapp.Service }

func (t *SearchTriggers) Name() string { return "search_triggers" }

func (t *SearchTriggers) Description() string {
	return "Find triggers by case-insensitive substring over name / description / kind. Returns id + name + kind + description + whether its listener is currently live (refCount of active workflows). Empty query lists all. Use get_trigger for full config."
}

func (t *SearchTriggers) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {"query": {"type": "string", "description": "Substring to match; omit to list all."}}
	}`)
}

func (t *SearchTriggers) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchTriggers) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_triggers: bad args: %w", err)
	}
	ts, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_triggers: %w", err)
	}
	type slim struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Kind        string `json:"kind"`
		Description string `json:"description"`
		RefCount    int    `json:"refCount"`
		Listening   bool   `json:"listening"`
	}
	out := make([]slim, 0, len(ts))
	for _, tr := range ts {
		out = append(out, slim{ID: tr.ID, Name: tr.Name, Kind: tr.Kind, Description: tr.Description, RefCount: tr.RefCount, Listening: tr.Listening})
	}
	return toJSON(map[string]any{"count": len(out), "triggers": out}), nil
}

// --- get_trigger -----------------------------------------------------------

type GetTrigger struct{ svc *triggerapp.Service }

func (t *GetTrigger) Name() string { return "get_trigger" }

func (t *GetTrigger) Description() string {
	return "Get one trigger: kind, source config, and runtime state (how many active workflows listen to it / whether its listener is live)."
}

func (t *GetTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {"triggerId": {"type": "string"}}
	}`)
}

func (t *GetTrigger) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_trigger: bad args: %w", err)
	}
	if a.TriggerID == "" {
		return fmt.Errorf("get_trigger: triggerId is required")
	}
	return nil
}

func (t *GetTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_trigger: bad args: %w", err)
	}
	tr, err := t.svc.Get(ctx, args.TriggerID)
	if err != nil {
		return "", fmt.Errorf("get_trigger: %w", err)
	}
	return toJSON(tr), nil
}
