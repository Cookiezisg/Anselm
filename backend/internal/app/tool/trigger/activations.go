package trigger

import (
	"context"
	"encoding/json"
	"fmt"

	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	triggerapp "github.com/sunweilin/foryx/backend/internal/app/trigger"
	triggerdomain "github.com/sunweilin/foryx/backend/internal/domain/trigger"
)

// --- search_activations ----------------------------------------------------

type SearchActivations struct{ svc *triggerapp.Service }

func (t *SearchActivations) Name() string { return "search_activations" }

func (t *SearchActivations) Description() string {
	return "Inspect a trigger's action log — one entry per time it acted, FIRED OR NOT. This answers \"why didn't it fire?\": for a sensor that probed but didn't fire, the entry keeps the return value it saw and a detail (e.g. condition evaluated false / invoke failed). firedOnly narrows to the entries that actually fired."
}

func (t *SearchActivations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {
			"triggerId": {"type": "string"},
			"firedOnly": {"type": "boolean", "description": "Only entries that fired."},
			"cursor": {"type": "string"},
			"limit": {"type": "integer"}
		}
	}`)
}

func (t *SearchActivations) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_activations: bad args: %w", err)
	}
	if a.TriggerID == "" {
		return ErrTriggerIDRequired
	}
	return nil
}

func (t *SearchActivations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID string `json:"triggerId"`
		FiredOnly bool   `json:"firedOnly"`
		Cursor    string `json:"cursor"`
		Limit     int    `json:"limit"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_activations: bad args: %w", err)
	}
	acts, next, err := t.svc.SearchActivations(ctx, triggerdomain.ActivationFilter{
		TriggerID: args.TriggerID, FiredOnly: args.FiredOnly, Cursor: args.Cursor, Limit: args.Limit,
	})
	if err != nil {
		return "", fmt.Errorf("search_activations: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"count": len(acts), "activations": acts, "nextCursor": next}), nil
}

// --- get_activation --------------------------------------------------------

type GetActivation struct{ svc *triggerapp.Service }

func (t *GetActivation) Name() string { return "get_activation" }

func (t *GetActivation) Description() string {
	return "Get one activation log entry by id: whether it fired, the sensor return value it observed, the fired payload, any error/detail, and how many workflows it fanned out to."
}

func (t *GetActivation) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["activationId"],
		"properties": {"activationId": {"type": "string"}}
	}`)
}

func (t *GetActivation) ValidateInput(args json.RawMessage) error {
	var a struct {
		ActivationID string `json:"activationId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("get_activation: bad args: %w", err)
	}
	if a.ActivationID == "" {
		return ErrActivationIDRequired
	}
	return nil
}

func (t *GetActivation) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ActivationID string `json:"activationId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("get_activation: bad args: %w", err)
	}
	act, err := t.svc.GetActivation(ctx, args.ActivationID)
	if err != nil {
		return "", fmt.Errorf("get_activation: %w", err)
	}
	return toolapp.ToJSON(act), nil
}
