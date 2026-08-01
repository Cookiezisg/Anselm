package control

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	controlapp "github.com/sunweilin/anselm/backend/internal/app/control"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// --- create_control --------------------------------------------------------

type CreateControl struct{ svc *controlapp.Service }

func (t *CreateControl) Name() string { return "create_control" }

func (t *CreateControl) Description() string {
	return "Create a control-logic entity: an ordered list of routing branches that a workflow control node references. The workflow node referencing it feeds it `input` (via that node's input mapping, which is CEL over upstream node results); the branches then read `input.*` ONLY — `payload`/`ctx` are NOT in scope here. Each branch has a `port` (the exit name the graph wires to a downstream node — use the key `port`, NEVER `name`), a `when` (a boolean CEL guard over `input.*`, e.g. `input.temperature > 30`; branches are evaluated top-to-bottom and the FIRST whose when is true wins), and an optional `emit` (a field→CEL map over `input.*` that builds this branch's downstream payload; omit to pass `input` through unchanged). The LAST branch MUST be `when: \"true\"` as the catch-all. CEL reads `input.*` only — no side effects, no now(). A port may wire back to an upstream node to form a loop; use emit to carry loop state (e.g. `input.attempt + 1`). Use this exact branch shape: {\"port\":\"pass\",\"when\":\"input.score >= 0.8\",\"emit\":{\"decision\":\"input.score\"}}. `branches` must be a JSON array of branch objects; for hosted-model compatibility, an exact JSON-encoded array string is also accepted, while malformed strings, objects, and non-array values are rejected."
}

func (t *CreateControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "branches"],
		"properties": {
			"name": {"type": "string", "description": "Unique name within the workspace."},
			"description": {"type": "string", "description": "One line on what this routing logic decides."},
			"inputs": {"type": "array", "description": "Declared inputs the workflow node feeds (when/emit read input.*): each {name, type, description}.", "items": {"type": "object"}},
			"branches": {
				"type": "array",
				"description": "Ordered branch objects using the exact keys port (not name), when, and optional emit; first true when wins; the last branch must be when:\"true\". Example: {\"port\":\"pass\",\"when\":\"input.score >= 0.8\",\"emit\":{\"decision\":\"input.score\"}}. For hosted-model compatibility, an exact JSON-encoded array string is also accepted; malformed strings, objects, and non-array values are rejected.",
				"items": {
					"type": "object",
					"required": ["port", "when"],
					"properties": {
						"port": {"type": "string", "description": "Named outcome the workflow routes on (an edge's fromPort matches it)."},
						"when": {"type": "string", "description": "Boolean CEL guard over input.*, e.g. input.score >= 0.9."},
						"emit": {"type": "object", "description": "Optional field->CEL map building this branch's output, e.g. {\"attempt\": \"input.attempt + 1\"}.", "additionalProperties": {"type": "string"}}
					}
				}
			},
			"changeReason": {"type": "string"}
		}
	}`)
}

func (t *CreateControl) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name     string          `json:"name"`
		Branches json.RawMessage `json:"branches"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_control: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	branches, err := decodeControlBranches(a.Branches)
	if err != nil {
		return fmt.Errorf("create_control: %w", err)
	}
	if len(branches) == 0 {
		return ErrBranchesRequired
	}
	return nil
}

func (t *CreateControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name         string            `json:"name"`
		Description  string            `json:"description"`
		Inputs       []schemapkg.Field `json:"inputs"`
		Branches     json.RawMessage   `json:"branches"`
		ChangeReason string            `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_control: bad args: %w", err)
	}
	branches, err := decodeControlBranches(args.Branches)
	if err != nil {
		return "", fmt.Errorf("create_control: bad args: %w", err)
	}
	c, v, err := t.svc.Create(ctx, controlapp.CreateInput{
		Name: args.Name, Description: args.Description, Inputs: args.Inputs,
		Branches: toBranches(branches), ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("create_control: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": c.ID, "name": c.Name, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- edit_control ----------------------------------------------------------

type EditControl struct{ svc *controlapp.Service }

func (t *EditControl) Name() string { return "edit_control" }

func (t *EditControl) Description() string {
	return "Replace a control logic's branches with a new ordered set, writing a new version that takes effect immediately (revert can switch back). Pass the COMPLETE branch list (not a delta) — same branch shape and catch-all rule as create_control. Each branch uses `port` (NEVER `name`), `when`, and optional `emit`; for example {\"port\":\"pass\",\"when\":\"input.score >= 0.8\",\"emit\":{\"decision\":\"input.score\"}}. `branches` must be a JSON array; for hosted-model compatibility, an exact JSON-encoded array string is also accepted, while malformed strings, objects, and non-array values are rejected. `changeReason` is REQUIRED and must be a non-empty audit explanation in every call; do not omit it or send an empty string."
}

func (t *EditControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["controlId", "branches", "changeReason"],
		"properties": {
			"controlId": {"type": "string"},
			"inputs": {"type": "array", "description": "Declared inputs (when/emit read input.*): each {name, type, description}.", "items": {"type": "object"}},
			"branches": {
				"type": "array",
				"description": "The complete new ordered branch list using keys port (not name), when, and optional emit; last must be when:\"true\". Example: {\"port\":\"pass\",\"when\":\"input.score >= 0.8\",\"emit\":{\"decision\":\"input.score\"}}. For hosted-model compatibility, an exact JSON-encoded array string is also accepted; malformed strings, objects, and non-array values are rejected.",
				"items": {
					"type": "object",
					"required": ["port", "when"],
					"properties": {
						"port": {"type": "string"},
						"when": {"type": "string"},
						"emit": {"type": "object", "additionalProperties": {"type": "string"}}
					}
				}
			},
			"changeReason": {"type": "string", "description": "REQUIRED non-empty audit explanation for this new immutable version."}
		}
	}`)
}

func (t *EditControl) ValidateInput(args json.RawMessage) error {
	var a struct {
		ControlID    string          `json:"controlId"`
		Branches     json.RawMessage `json:"branches"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_control: bad args: %w", err)
	}
	if a.ControlID == "" {
		return ErrControlIDRequired
	}
	if strings.TrimSpace(a.ChangeReason) == "" {
		return ErrChangeReasonRequired
	}
	branches, err := decodeControlBranches(a.Branches)
	if err != nil {
		return fmt.Errorf("edit_control: %w", err)
	}
	if len(branches) == 0 {
		return ErrBranchesRequired
	}
	return nil
}

func (t *EditControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ControlID    string            `json:"controlId"`
		Inputs       []schemapkg.Field `json:"inputs"`
		Branches     json.RawMessage   `json:"branches"`
		ChangeReason string            `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_control: bad args: %w", err)
	}
	if strings.TrimSpace(args.ChangeReason) == "" {
		return "", fmt.Errorf("edit_control: %w", ErrChangeReasonRequired)
	}
	branches, err := decodeControlBranches(args.Branches)
	if err != nil {
		return "", fmt.Errorf("edit_control: bad args: %w", err)
	}
	v, err := t.svc.Edit(ctx, controlapp.EditInput{
		ID: args.ControlID, Inputs: args.Inputs, Branches: toBranches(branches), ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("edit_control: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.ControlID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- revert_control --------------------------------------------------------

type RevertControl struct{ svc *controlapp.Service }

func (t *RevertControl) Name() string { return "revert_control" }

func (t *RevertControl) Description() string {
	return "Switch a control logic's active version to an existing version by its number. This only moves the active pointer — newer versions are kept in history and can be switched back to. The version must be a positive integer; for hosted-model compatibility, an exact decimal integer string is also accepted, while floats, booleans, arrays, and malformed strings are rejected. Note: name, description and tags are NOT versioned (they live on the control), so a revert restores only the versioned branches and leaves name/description/tags unchanged — use edit_control set_meta to also change those."
}

func (t *RevertControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["controlId", "version"],
		"properties": {
			"controlId": {"type": "string"},
			"version": {"type": "integer", "description": "The positive version number to make active. For hosted-model compatibility, an exact decimal integer string is also accepted; floats, booleans, arrays, and malformed strings are rejected."}
		}
	}`)
}

func (t *RevertControl) ValidateInput(args json.RawMessage) error {
	var a struct {
		ControlID string          `json:"controlId"`
		Version   json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("revert_control: bad args: %w", err)
	}
	if a.ControlID == "" {
		return ErrControlIDRequired
	}
	version, err := decodeControlVersion(a.Version)
	if err != nil {
		return fmt.Errorf("revert_control: %w", err)
	}
	if version <= 0 {
		return ErrVersionPositive
	}
	return nil
}

func (t *RevertControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ControlID string          `json:"controlId"`
		Version   json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("revert_control: bad args: %w", err)
	}
	version, err := decodeControlVersion(args.Version)
	if err != nil {
		return "", fmt.Errorf("revert_control: bad args: %w", err)
	}
	v, err := t.svc.Revert(ctx, args.ControlID, version)
	if err != nil {
		return "", fmt.Errorf("revert_control: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.ControlID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- delete_control --------------------------------------------------------

type DeleteControl struct {
	svc  *controlapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteControl) Name() string { return "delete_control" }

func (t *DeleteControl) Description() string {
	return "Delete a control logic and all its versions. Not reversible. This is a destructive action: set danger=\\\"dangerous\\\" and wait for the user's approval before calling it. Pass the REQUIRED controlId (never `{}`); check get_relations first so you can explain dependents. Workflows that reference it will fail their capability check until repointed. The result reports how many entities referenced it."
}

func (t *DeleteControl) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["controlId"],
		"properties": {"controlId": {"type": "string", "description": "REQUIRED existing control id, for example ctl_0123456789abcdef; never omit or send an empty object."}}
	}`)
}

func (t *DeleteControl) ValidateInput(args json.RawMessage) error {
	var a struct {
		ControlID string `json:"controlId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_control: bad args: %w", err)
	}
	if a.ControlID == "" {
		return ErrControlIDRequired
	}
	return nil
}

func (t *DeleteControl) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ControlID string `json:"controlId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_control: bad args: %w", err)
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindControl, args.ControlID)
	if err := t.svc.Delete(ctx, args.ControlID); err != nil {
		return "", fmt.Errorf("delete_control: %w", err)
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(map[string]any{"id": args.ControlID, "deleted": true}, deps)), nil
}
