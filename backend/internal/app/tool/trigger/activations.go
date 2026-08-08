package trigger

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	triggerapp "github.com/sunweilin/anselm/backend/internal/app/trigger"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
)

// --- search_activations ----------------------------------------------------

type SearchActivations struct{ svc *triggerapp.Service }

func (t *SearchActivations) Name() string { return "search_activations" }

func (t *SearchActivations) Description() string {
	return "Inspect a trigger's action log — one entry per time it acted, FIRED OR NOT. This answers \"why didn't it fire?\": for a sensor that probed but didn't fire, the entry keeps the return value it saw and a detail (e.g. condition evaluated false / invoke failed). Each activation's firingCount is the number of workflows fanned out by THAT activation (a per-entry fan-out width), NOT a cumulative counter and NOT the number of fires in the trigger's history: 0 means no workflow received that activation; a fired entry can still be 0 when no workflow listens. When payload.manual=true, report it as a manual fire that bypassed the sensor condition — it is NOT evidence that the sensor condition or threshold evaluated true. firedOnly narrows to entries that actually fired. For hosted-model compatibility, exact JSON strings \"true\"/\"false\" and exact decimal integer strings such as \"3\" are accepted for these scalar filters; floats, arbitrary strings, arrays, and other shapes remain invalid."
}

func (t *SearchActivations) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {
			"triggerId": {"type": "string"},
			"firedOnly": {"type": "boolean", "description": "Only entries that fired; does not change the per-entry meaning of firingCount. Exact strings \"true\"/\"false\" are accepted for hosted-model compatibility."},
			"cursor": {"type": "string", "description": "Cursor returned as nextCursor by a previous search_activations call."},
			"limit": {"type": "integer", "description": "Maximum number of activation entries to return. An exact decimal string such as \"3\" is also accepted for hosted-model compatibility; other strings are invalid."}
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

type searchActivationsArgs struct {
	TriggerID string
	FiredOnly bool
	Cursor    string
	Limit     int
}

// UnmarshalJSON keeps the public schema strongly typed while accepting only the exact scalar
// strings emitted by some hosted models. A rejected first call creates a visible red card and an
// avoidable retry; floats, arbitrary strings, arrays, and other shapes remain invalid.
func (a *searchActivationsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		TriggerID string          `json:"triggerId"`
		FiredOnly json.RawMessage `json:"firedOnly"`
		Cursor    string          `json:"cursor"`
		Limit     json.RawMessage `json:"limit"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	firedOnly, err := decodeSearchActivationsBool(raw.FiredOnly)
	if err != nil {
		return fmt.Errorf("firedOnly: %w", err)
	}
	limit, err := decodeSearchActivationsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchActivationsArgs{TriggerID: raw.TriggerID, FiredOnly: firedOnly, Cursor: raw.Cursor, Limit: limit}
	return nil
}

func decodeSearchActivationsBool(raw json.RawMessage) (bool, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return false, nil
	}
	var value bool
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil || (text != "true" && text != "false") {
		return false, fmt.Errorf("must be boolean or the exact string \"true\"/\"false\", got %s", string(raw))
	}
	return text == "true", nil
}

func decodeSearchActivationsInt(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || bytes.Equal(raw, []byte("null")) {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer or an exact decimal integer string, got %q", text)
	}
	return value, nil
}

func (t *SearchActivations) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchActivationsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_activations: bad args: %w", err)
	}
	acts, next, err := t.svc.SearchActivations(ctx, triggerdomain.ActivationFilter{
		TriggerID: args.TriggerID, FiredOnly: args.FiredOnly, Cursor: args.Cursor, Limit: args.Limit,
	})
	if err != nil {
		return "", fmt.Errorf("search_activations: %w", err)
	}
	return toolapp.ToJSON(map[string]any{
		"count":       len(acts),
		"activations": acts,
		"nextCursor":  next,
		"fieldSemantics": map[string]string{
			"firingCount":    "per-activation workflow fan-out count; not cumulative across the trigger history",
			"payload.manual": "manual fire marker; bypasses a sensor condition and is not evidence that the condition evaluated true",
		},
	}), nil
}

// --- get_activation --------------------------------------------------------

type GetActivation struct{ svc *triggerapp.Service }

func (t *GetActivation) Name() string { return "get_activation" }

func (t *GetActivation) Description() string {
	return "Open exactly one activation audit record. Required: pass the exact opaque activationId copied byte-for-byte from fire_trigger, search_activations, or an activation tool card; never omit it, send an empty object, or substitute a triggerId. The result is the source of truth for id, triggerId, kind, fired, returnValue, payload, error, detail, firingCount, and createdAt; report those exact fields without inventing or replacing values."
}

func (t *GetActivation) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"additionalProperties": false,
		"required": ["activationId"],
		"properties": {
			"activationId": {
				"type": "string",
				"description": "Required exact opaque activation id beginning with tra_; copy it byte-for-byte from the prior tool result or card. Never omit this field and never send triggerId."
			}
		}
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

// --- search_firings --------------------------------------------------------

type SearchFirings struct{ svc *triggerapp.Service }

func (t *SearchFirings) Name() string { return "search_firings" }

func (t *SearchFirings) Description() string {
	return "Inspect a trigger's firing inbox — one row per workflow it fanned out to when it fired, each with the run-or-not disposition: started (a flowrun was created), pending (awaiting the scheduler), or skipped / superseded / shed (it fired but NO flowrun ran — by an overlap policy or a resource cap). This answers \"my trigger fired but the workflow didn't run — why?\", which search_activations (which only shows whether it FIRED) cannot. This tool requires the exact opaque triggerId copied byte-for-byte from a prior trigger result or tool card; it is NOT a name/pattern search and never accepts a pattern argument or the placeholder \"the requested item\". If only a name is known, call search_triggers first, then pass its returned id here. Filter by status; cursor-paged. For hosted-model compatibility, an exact decimal integer string such as \"3\" is accepted for limit; floats, arbitrary strings, and arrays remain invalid."
}

func (t *SearchFirings) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["triggerId"],
		"properties": {
			"triggerId": {"type": "string", "description": "Required exact opaque trigger id copied byte-for-byte from search_triggers or a trigger tool card. This is not a name, pattern, or placeholder; do not send pattern."},
			"status": {"type": "string", "enum": ["pending", "started", "skipped", "superseded", "shed"], "description": "Narrow to one disposition (e.g. shed = dropped by a resource cap; superseded = a newer firing replaced this waiting one under buffer_one)."},
			"cursor": {"type": "string"},
			"limit": {"type": "integer", "description": "Maximum number of firing rows. An exact decimal string such as \"3\" is also accepted for hosted-model compatibility; other strings are invalid."}
		}
	}`)
}

func (t *SearchFirings) ValidateInput(args json.RawMessage) error {
	var a struct {
		TriggerID string `json:"triggerId"`
		Pattern   string `json:"pattern"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("search_firings: bad args: %w", err)
	}
	if a.TriggerID == "" {
		if a.Pattern != "" {
			return fmt.Errorf("search_firings: exact triggerId is required; pattern is not accepted (call search_triggers first, then copy its id)")
		}
		return ErrTriggerIDRequired
	}
	return nil
}

type searchFiringsArgs struct {
	TriggerID string
	Status    string
	Cursor    string
	Limit     int
}

func (a *searchFiringsArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		TriggerID string          `json:"triggerId"`
		Status    string          `json:"status"`
		Cursor    string          `json:"cursor"`
		Limit     json.RawMessage `json:"limit"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	limit, err := decodeSearchActivationsInt(raw.Limit)
	if err != nil {
		return fmt.Errorf("limit: %w", err)
	}
	*a = searchFiringsArgs{TriggerID: raw.TriggerID, Status: raw.Status, Cursor: raw.Cursor, Limit: limit}
	return nil
}

func (t *SearchFirings) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchFiringsArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("search_firings: bad args: %w", err)
	}
	firings, next, err := t.svc.SearchFirings(ctx, triggerdomain.FiringFilter{
		TriggerID: args.TriggerID, Status: args.Status, Cursor: args.Cursor, Limit: args.Limit,
	})
	if err != nil {
		return "", fmt.Errorf("search_firings: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"count": len(firings), "firings": firings, "nextCursor": next}), nil
}
