package control

import (
	"context"
	"encoding/json"
	"fmt"

	controlapp "github.com/sunweilin/foryx/backend/internal/app/control"
	searchapp "github.com/sunweilin/foryx/backend/internal/app/search"
	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// --- search_control --------------------------------------------------------

type SearchControl struct {
	svc     *controlapp.Service
	content *searchapp.Service // nil → legacy substring only. nil → 仅原子串路径。
}

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
	if body, ok := toolapp.ContentSearch(ctx, t.content, searchdomain.TypeControl, args.Query, "controls"); ok {
		return body, nil
	}
	ctls, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_control: %w", err)
	}
	out := make([]searchdomain.EntitySlim, 0, len(ctls))
	for _, c := range ctls {
		out = append(out, searchdomain.EntitySlim{ID: c.ID, Name: c.Name, Description: c.Description})
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
