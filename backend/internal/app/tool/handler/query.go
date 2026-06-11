package handler

import (
	"context"
	"encoding/json"
	"fmt"

	handlerapp "github.com/sunweilin/forgify/backend/internal/app/handler"
)

// --- search_handler --------------------------------------------------------

type SearchHandler struct{ svc *handlerapp.Service }

func (t *SearchHandler) Name() string { return "search_handler" }

func (t *SearchHandler) Description() string {
	return "Find handlers by case-insensitive substring over name / description / tags. Returns id + name + description; empty query lists all. Use get_handler for the full class interface + config state."
}

func (t *SearchHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {"query": {"type": "string", "description": "Substring to match; omit to list all."}}
	}`)
}

func (t *SearchHandler) ValidateInput(json.RawMessage) error { return nil }

func (t *SearchHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Query string `json:"query"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_handler: bad args: %w", err)
	}
	hs, err := t.svc.Search(ctx, args.Query)
	if err != nil {
		return "", fmt.Errorf("search_handler: %w", err)
	}
	type slim struct {
		ID          string `json:"id"`
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	out := make([]slim, 0, len(hs))
	for _, h := range hs {
		out = append(out, slim{ID: h.ID, Name: h.Name, Description: h.Description})
	}
	return toJSON(map[string]any{"count": len(out), "handlers": out}), nil
}

// --- get_handler -----------------------------------------------------------

type GetHandler struct{ svc *handlerapp.Service }

func (t *GetHandler) Name() string { return "get_handler" }

func (t *GetHandler) Description() string {
	return "Get one handler with its active version (class parts + methods + init-args schema), config state (configured/missing keys), and runtime state (running/stopped/crashed)."
}

func (t *GetHandler) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["handlerId"],
		"properties": {"handlerId": {"type": "string"}}
	}`)
}

func (t *GetHandler) ValidateInput(args json.RawMessage) error {
	var a struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_handler: bad args: %w", err)
	}
	if a.HandlerID == "" {
		return fmt.Errorf("get_handler: handlerId is required")
	}
	return nil
}

func (t *GetHandler) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		HandlerID string `json:"handlerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_handler: bad args: %w", err)
	}
	h, err := t.svc.Get(ctx, args.HandlerID)
	if err != nil {
		return "", fmt.Errorf("get_handler: %w", err)
	}
	return toJSON(h), nil
}
