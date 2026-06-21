package trigger

import (
	"context"
	"encoding/json"
	"fmt"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
)

// --- fire_trigger ----------------------------------------------------------

type FireTrigger struct{ svc *triggerapp.Service }

func (t *FireTrigger) Name() string { return "fire_trigger" }

func (t *FireTrigger) Description() string {
	return "Manually fire a trigger right now to exercise its fan-out plumbing (mainly for testing): it fans out to whatever workflows currently listen to it and records an activation — if no active workflow listens, the activation is recorded with zero fan-out. This is the REAL firing path (through the firing inbox), so a listening workflow's concurrency/overlap policy (serial/skip/buffer_one/replace) DOES apply — fire twice in quick succession to exercise it; trigger_workflow, by contrast, bypasses the policy and always starts a run immediately. It carries NO custom payload (the synthetic fire payload is just {\"manual\":true}), so a listening workflow that reads trigger fields gets nothing usable from it — to run a workflow WITH your own test data, use trigger_workflow (which feeds a payload you supply straight to the entry trigger node)."
}

func (t *FireTrigger) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {"triggerId": {"type": "string"}}
	}`)
}

func (t *FireTrigger) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("fire_trigger: bad args: %w", err)
	}
	if a.TriggerID == "" {
		return ErrTriggerIDRequired
	}
	return nil
}

func (t *FireTrigger) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		TriggerID string `json:"triggerId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("fire_trigger: bad args: %w", err)
	}
	actID, err := t.svc.FireManual(ctx, args.TriggerID)
	if err != nil {
		return "", fmt.Errorf("fire_trigger: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"fired": true, "triggerId": args.TriggerID, "activationId": actID}), nil
}
