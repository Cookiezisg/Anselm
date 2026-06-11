package control

import (
	"context"
	"encoding/json"
	"fmt"

	controlapp "github.com/sunweilin/forgify/backend/internal/app/control"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// --- search_control --------------------------------------------------------

type SearchControl struct{ svc *controlapp.Service }

func (t *SearchControl) Name() string { return "search_control" }

func (t *SearchControl) Description() string {
	return "Find control logics by case-insensitive substring over name / description. Returns id + name + description; empty query lists all. Use get_control for the full branch set."
}

func (t *SearchControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"query": {"type": "string", "description": "Substring to match; omit or empty to list all."}
		}
	}`)
}

func (t *SearchControl) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_control: bad args: %w", err)
	}
	ctls, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_control: %w", err)
	}
	type slim struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	out := make([]slim, 0, len(ctls))
	for _, c := range ctls {
		out = append(out, slim{ID: c.ID, Name: c.Name, Description: c.Description})
	}
	return toolapp.ToJSON(map[string]any{"count": len(out), "controls": out}), nil
}

// --- get_control -----------------------------------------------------------

type GetControl struct{ svc *controlapp.Service }

func (t *GetControl) Name() string { return "get_control" }

func (t *GetControl) Description() string {
	return "Get one control logic with its active version (the ordered branch set: port / when / emit per branch)."
}

func (t *GetControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["controlId"],
		"properties": {"controlId": {"type": "string"}}
	}`)
}

func (t *GetControl) ValidateInput(args json.RawMessage) error {
	var a struct {
		ControlID string `json:"controlId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_control: bad args: %w", err)
	}
	if a.ControlID == "" {
		return ErrControlIDRequired
	}
	return nil
}

func (t *GetControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ControlID string `json:"controlId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_control: bad args: %w", err)
	}
	c, err := t.svc.Get(ctx, args.ControlID)
	if err != nil {
		return "", fmt.Errorf("get_control: %w", err)
	}
	return toolapp.ToJSON(c), nil
}
