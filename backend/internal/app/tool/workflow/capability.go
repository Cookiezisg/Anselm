package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// --- capability_check_workflow ---------------------------------------------

type CapabilityCheckWorkflow struct{ svc *workflowapp.Service }

func (t *CapabilityCheckWorkflow) Name() string { return "capability_check_workflow" }

func (t *CapabilityCheckWorkflow) Description() string {
	return "Validate a workflow's active graph: structural soundness plus, when the capability catalog is wired, whether every referenced entity (trigger / function / handler / mcp / agent / control / approval) exists, has an active version, and exposes the ports/methods the graph uses. Pass exactly one of workflowId (the exact wf_... ID) or workflowName (the exact workflow name); if the user gives a name, use workflowName directly and never guess an ID or call with {}. The observed hosted-model file_path alias is accepted only when it is one unambiguous single-segment workflow name. Returns a report with `problems` (blocking — fix before activating) and `warnings` (advisory — won't block). Warnings include node-input reads of an undeclared output: if a node's input reads `producer.field` and that producer (function / handler-method / agent) declares outputs that don't include `field`, it likely fails at runtime — declare the output or guard with has(producer.field). It does NOT fully validate DATAFLOW: declared outputs aren't runtime-enforced (so warnings are advisory, not certain), and reads from schema-less producers (mcp / trigger), conditional-branch fields, or the runtime-only `.text` key are not checked — so a clean report still needs one trigger_workflow to confirm the data wiring."
}

func (t *CapabilityCheckWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"workflowId": {"type": "string", "description": "Exact workflow entity ID (wf_...). Use this OR workflowName."},
			"workflowName": {"type": "string", "description": "Exact user-facing workflow name. Use this OR workflowId; do not use a filesystem path."}
		}
	}`)
}

func (t *CapabilityCheckWorkflow) ValidateInput(args json.RawMessage) error {
	_, err := decodeWorkflowTarget(args, "capability_check_workflow")
	return err
}

func (t *CapabilityCheckWorkflow) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	return normalizeWorkflowTargetArguments(args)
}

func (t *CapabilityCheckWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	target, err := decodeWorkflowTarget([]byte(argsJSON), "capability_check_workflow")
	if err != nil {
		return "", err
	}
	var w *workflowdomain.Workflow
	if target.WorkflowID != "" {
		w, err = t.svc.Get(ctx, target.WorkflowID)
	} else {
		w, err = t.svc.GetByName(ctx, target.WorkflowName)
	}
	if err != nil {
		return "", fmt.Errorf("capability_check_workflow: %w", err)
	}
	rep, err := t.svc.CapabilityCheckByID(ctx, w.ID)
	if err != nil {
		return "", fmt.Errorf("capability_check_workflow: %w", err)
	}
	// Keep the report shape stable for the model and every UI projection: an empty list means
	// "nothing found", while null makes a successful check look unresolved in generated tables.
	problems := rep.Problems
	if problems == nil {
		problems = []string{}
	}
	warnings := rep.Warnings
	if warnings == nil {
		warnings = []string{}
	}
	return toolapp.ToJSON(map[string]any{
		"id":                w.ID,
		"name":              w.Name,
		"ok":                rep.OK(),
		"structurallyValid": rep.StructurallyValid,
		"resolved":          rep.Resolved,
		"problems":          problems,
		"warnings":          warnings,
	}), nil
}
