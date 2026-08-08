package approval

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	approvalapp "github.com/sunweilin/anselm/backend/internal/app/approval"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// --- create_approval -------------------------------------------------------

type CreateApproval struct{ svc *approvalapp.Service }

func (t *CreateApproval) Name() string { return "create_approval" }

func (t *CreateApproval) Description() string {
	return "Create an approval-form entity that a workflow approval node references: a markdown prompt `template` (with `{{ input.* }}` interpolation over the inputs the workflow node feeds, e.g. `批准对 {{ input.user }} 的退款 {{ input.amount }} 元?`) which renders into a human-readable decision point, plus decision rules. `template` is REQUIRED — a button with no explanation is meaningless. `inputs` is an array of `{name,type,description}` fields; for hosted-model compatibility, an exact JSON-encoded array string or exact field-name object JSON string is also accepted, while malformed shapes are rejected. `allowReason` is a boolean; exact strings \"true\"/\"false\" are also accepted for hosted-model compatibility. `timeout` (a duration like `30d` / `2h`; empty = never times out) and `timeoutBehavior` (reject|approve|fail; required when timeout is set) govern what happens if nobody responds. At the tool boundary, an exact integer seconds string/number such as \"7200\" is normalized to 2h for hosted-model compatibility. The node has fixed yes/no exits the graph wires to downstream nodes. Its downstream result is {decision: \"yes\"|\"no\", reason} ONLY — an approval does NOT pass its input through, so a downstream node needing the original data (e.g. the amount) must read it from an upstream node, not from the approval node."
}

func (t *CreateApproval) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "template"],
		"properties": {
			"name": {"type": "string", "description": "Unique name within the workspace."},
			"description": {"type": "string", "description": "One line on what this approval decides."},
			"inputs": {"type": "array", "description": "Declared inputs the workflow node feeds (template reads input.*): each {name, type, description}. Hosted-model compatibility also accepts an exact JSON-encoded array string or exact field-name object JSON string; malformed shapes are rejected.", "items": {"type": "object"}},
			"template": {"type": "string", "description": "Markdown prompt with {{ input.* }} interpolation; shown to the user so they know what they're approving."},
			"allowReason": {"type": "boolean", "description": "Allow an optional free-text note when deciding. Exact strings \"true\"/\"false\" are accepted only for hosted-model compatibility."},
			"timeout": {"type": "string", "description": "Duration like 30d / 2h; empty = never times out. Hosted-model compatibility also accepts an exact integer seconds string or integer number and normalizes it."},
			"timeoutBehavior": {"type": "string", "enum": ["reject", "approve", "fail"], "description": "What happens on timeout; required when timeout is set."},
			"changeReason": {"type": "string"}
		}
	}`)
}

func (t *CreateApproval) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name            string          `json:"name"`
		Template        string          `json:"template"`
		Inputs          json.RawMessage `json:"inputs"`
		AllowReason     json.RawMessage `json:"allowReason"`
		Timeout         json.RawMessage `json:"timeout"`
		TimeoutBehavior string          `json:"timeoutBehavior"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_approval: bad args: %w", err)
	}
	if strings.TrimSpace(a.Name) == "" {
		return ErrNameRequired
	}
	if strings.TrimSpace(a.Template) == "" {
		return ErrTemplateRequired
	}
	if _, err := decodeApprovalInputs(a.Inputs); err != nil {
		return fmt.Errorf("create_approval: %w", err)
	}
	if _, err := decodeApprovalBool(a.AllowReason); err != nil {
		return fmt.Errorf("create_approval: allowReason: %w", err)
	}
	timeout, err := decodeApprovalTimeout(a.Timeout)
	if err != nil {
		return fmt.Errorf("create_approval: timeout: %w", err)
	}
	if err := approvaldomain.ValidateForm(a.Template, timeout, a.TimeoutBehavior); err != nil {
		return fmt.Errorf("create_approval: %w", err)
	}
	return nil
}

func (t *CreateApproval) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name            string          `json:"name"`
		Description     string          `json:"description"`
		Inputs          json.RawMessage `json:"inputs"`
		Template        string          `json:"template"`
		AllowReason     json.RawMessage `json:"allowReason"`
		Timeout         json.RawMessage `json:"timeout"`
		TimeoutBehavior string          `json:"timeoutBehavior"`
		ChangeReason    string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_approval: bad args: %w", err)
	}
	inputs, err := decodeApprovalInputs(args.Inputs)
	if err != nil {
		return "", fmt.Errorf("create_approval: bad args: inputs: %w", err)
	}
	allowReason, err := decodeApprovalBool(args.AllowReason)
	if err != nil {
		return "", fmt.Errorf("create_approval: bad args: allowReason: %w", err)
	}
	timeout, err := decodeApprovalTimeout(args.Timeout)
	if err != nil {
		return "", fmt.Errorf("create_approval: bad args: timeout: %w", err)
	}
	f, v, err := t.svc.Create(ctx, approvalapp.CreateInput{
		Name: args.Name, Description: args.Description, Inputs: inputs, Template: args.Template,
		AllowReason: allowReason, Timeout: timeout, TimeoutBehavior: args.TimeoutBehavior,
		ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("create_approval: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": f.ID, "name": f.Name, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- edit_approval ---------------------------------------------------------

type EditApproval struct{ svc *approvalapp.Service }

func (t *EditApproval) Name() string { return "edit_approval" }

func (t *EditApproval) Description() string {
	return "Replace an approval form with a complete new version, writing it active immediately (revert can switch back). Required full replacement fields: approvalId, inputs, template, allowReason, timeout, timeoutBehavior, changeReason; do not send a delta. Inputs and allowReason accept the public schema plus exact hosted-model JSON string variants; timeout also accepts an exact integer seconds string or integer number and normalizes it. Malformed or missing fields are rejected before mutation. changeReason is a non-empty audit explanation."
}

func (t *EditApproval) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["approvalId", "inputs", "template", "allowReason", "timeout", "timeoutBehavior", "changeReason"],
		"properties": {
			"approvalId": {"type": "string"},
			"inputs": {"type": "array", "description": "Declared inputs (template reads input.*): each {name, type, description}. Hosted-model compatibility also accepts an exact JSON-encoded array string or exact field-name object JSON string; malformed shapes are rejected.", "items": {"type": "object"}},
			"template": {"type": "string", "description": "Markdown prompt with {{ input.* }} interpolation."},
			"allowReason": {"type": "boolean", "description": "Native boolean; exact strings \"true\"/\"false\" are accepted only for hosted-model compatibility."},
			"timeout": {"type": "string", "description": "Duration like 30d / 2h; empty = never. Hosted-model compatibility also accepts an exact integer seconds string or integer number and normalizes it."},
			"timeoutBehavior": {"type": "string", "enum": ["reject", "approve", "fail"]},
			"changeReason": {"type": "string"}
		}
	}`)
}

func (t *EditApproval) ValidateInput(args json.RawMessage) error {
	if err := requireCompleteEditApprovalArgs(args); err != nil {
		return err
	}
	var a struct {
		ApprovalID      string          `json:"approvalId"`
		Template        string          `json:"template"`
		Inputs          json.RawMessage `json:"inputs"`
		AllowReason     json.RawMessage `json:"allowReason"`
		Timeout         json.RawMessage `json:"timeout"`
		TimeoutBehavior string          `json:"timeoutBehavior"`
		ChangeReason    string          `json:"changeReason"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_approval: bad args: %w", err)
	}
	if a.ApprovalID == "" {
		return ErrApprovalIDRequired
	}
	if strings.TrimSpace(a.Template) == "" {
		return ErrTemplateRequired
	}
	if strings.TrimSpace(a.ChangeReason) == "" {
		return fmt.Errorf("edit_approval: changeReason is required for a complete replacement")
	}
	if _, err := decodeApprovalInputs(a.Inputs); err != nil {
		return fmt.Errorf("edit_approval: %w", err)
	}
	if _, err := decodeApprovalBool(a.AllowReason); err != nil {
		return fmt.Errorf("edit_approval: allowReason: %w", err)
	}
	timeout, err := decodeApprovalTimeout(a.Timeout)
	if err != nil {
		return fmt.Errorf("edit_approval: timeout: %w", err)
	}
	if err := approvaldomain.ValidateForm(a.Template, timeout, a.TimeoutBehavior); err != nil {
		return fmt.Errorf("edit_approval: %w", err)
	}
	return nil
}

func (t *EditApproval) Execute(ctx context.Context, argsJSON string) (string, error) {
	if err := requireCompleteEditApprovalArgs([]byte(argsJSON)); err != nil {
		return "", err
	}
	var args struct {
		ApprovalID      string          `json:"approvalId"`
		Inputs          json.RawMessage `json:"inputs"`
		Template        string          `json:"template"`
		AllowReason     json.RawMessage `json:"allowReason"`
		Timeout         json.RawMessage `json:"timeout"`
		TimeoutBehavior string          `json:"timeoutBehavior"`
		ChangeReason    string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_approval: bad args: %w", err)
	}
	if strings.TrimSpace(args.ChangeReason) == "" {
		return "", fmt.Errorf("edit_approval: changeReason is required for a complete replacement")
	}
	inputs, err := decodeApprovalInputs(args.Inputs)
	if err != nil {
		return "", fmt.Errorf("edit_approval: bad args: inputs: %w", err)
	}
	allowReason, err := decodeApprovalBool(args.AllowReason)
	if err != nil {
		return "", fmt.Errorf("edit_approval: bad args: allowReason: %w", err)
	}
	timeout, err := decodeApprovalTimeout(args.Timeout)
	if err != nil {
		return "", fmt.Errorf("edit_approval: bad args: timeout: %w", err)
	}
	v, err := t.svc.Edit(ctx, approvalapp.EditInput{
		ID: args.ApprovalID, Inputs: inputs, Template: args.Template, AllowReason: allowReason,
		Timeout: timeout, TimeoutBehavior: args.TimeoutBehavior, ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("edit_approval: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.ApprovalID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- revert_approval -------------------------------------------------------

type RevertApproval struct{ svc *approvalapp.Service }

func (t *RevertApproval) Name() string { return "revert_approval" }

func (t *RevertApproval) Description() string {
	return "Switch an approval form's active version to an existing version by its number. Only moves the active pointer — newer versions are kept in history and can be switched back to. The version must be a positive integer; for hosted-model compatibility, an exact decimal integer string is also accepted, while floats, booleans, arrays, and malformed strings are rejected. Note: name, description and tags are NOT versioned (they live on the approval), so a revert restores only the versioned snapshot (template + decision rules) and leaves name/description/tags unchanged — use edit_approval set_meta to also change those."
}

func (t *RevertApproval) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["approvalId", "version"],
		"properties": {
			"approvalId": {"type": "string"},
			"version": {"type": "integer", "description": "The positive version number to make active. For hosted-model compatibility, an exact decimal integer string is also accepted; floats, booleans, arrays, and malformed strings are rejected."}
		}
	}`)
}

func (t *RevertApproval) ValidateInput(args json.RawMessage) error {
	var a struct {
		ApprovalID string          `json:"approvalId"`
		Version    json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("revert_approval: bad args: %w", err)
	}
	if a.ApprovalID == "" {
		return ErrApprovalIDRequired
	}
	version, err := decodeApprovalVersion(a.Version)
	if err != nil {
		return fmt.Errorf("revert_approval: %w", err)
	}
	if version <= 0 {
		return ErrVersionPositive
	}
	return nil
}

func (t *RevertApproval) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ApprovalID string          `json:"approvalId"`
		Version    json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("revert_approval: bad args: %w", err)
	}
	version, err := decodeApprovalVersion(args.Version)
	if err != nil {
		return "", fmt.Errorf("revert_approval: bad args: %w", err)
	}
	v, err := t.svc.Revert(ctx, args.ApprovalID, version)
	if err != nil {
		return "", fmt.Errorf("revert_approval: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.ApprovalID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- delete_approval -------------------------------------------------------

type DeleteApproval struct {
	svc  *approvalapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteApproval) Name() string { return "delete_approval" }

func (t *DeleteApproval) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func (t *DeleteApproval) Description() string {
	return "This call is always dangerous and requires explicit user approval; never downgrade its danger field. Soft-delete an approval form from normal reads and purge its relation edges. This is a destructive action: set danger=\"dangerous\" and wait for the user's approval before calling it. The approval primary row is NOT restorable through the active API. The immutable version history is retained for audit; this does NOT hard-delete the versions. Workflows that referenced it will fail their capability check until repointed. Check get_relations first so you can explain dependents; the result reports how many entities were affected."
}

func (t *DeleteApproval) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["approvalId"],
		"properties": {"approvalId": {"type": "string", "description": "REQUIRED existing approval id; never omit or send an empty object."}}
	}`)
}

func (t *DeleteApproval) ValidateInput(args json.RawMessage) error {
	var a struct {
		ApprovalID string `json:"approvalId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_approval: bad args: %w", err)
	}
	if a.ApprovalID == "" {
		return ErrApprovalIDRequired
	}
	return nil
}

func (t *DeleteApproval) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ApprovalID string `json:"approvalId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("delete_approval: bad args: %w", err)
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindApproval, args.ApprovalID)
	if err := t.svc.Delete(ctx, args.ApprovalID); err != nil {
		return "", fmt.Errorf("delete_approval: %w", err)
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(map[string]any{"id": args.ApprovalID, "deleted": true}, deps)), nil
}
