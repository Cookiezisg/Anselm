package workflow

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	workflowapp "github.com/sunweilin/anselm/backend/internal/app/workflow"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
	workflowdomain "github.com/sunweilin/anselm/backend/internal/domain/workflow"
)

// decodeWorkflowVersion accepts the public integer shape and the exact decimal string variant
// emitted by some hosted models. Other representations stay invalid so a malformed version cannot
// silently select an unintended snapshot.
func decodeWorkflowVersion(raw json.RawMessage) (int, error) {
	raw = bytes.TrimSpace(raw)
	var version int
	if err := json.Unmarshal(raw, &version); err == nil {
		return version, nil
	}
	var encoded string
	if err := json.Unmarshal(raw, &encoded); err != nil {
		return 0, fmt.Errorf("version must be a positive integer or an exact integer string, got %s", string(raw))
	}
	version, err := strconv.Atoi(strings.TrimSpace(encoded))
	if err != nil {
		return 0, fmt.Errorf("version must be a positive integer or an exact integer string, got %q", encoded)
	}
	return version, nil
}

// --- create_workflow -------------------------------------------------------

type CreateWorkflow struct{ svc *workflowapp.Service }

func (t *CreateWorkflow) Name() string { return "create_workflow" }

func (t *CreateWorkflow) Description() string {
	return "Build a new workflow graph from ops; v1 takes effect immediately (no separate accept step). The new workflow starts deactivated — activate it once its graph is sound. Provide name, description, tags, changeReason, and an ops array that builds at least a trigger node. The three metadata slots are always required: pass an empty string or [] only when the user supplied no value; otherwise pass each value verbatim at the TOP LEVEL. Never omit user-provided metadata and never put changeReason inside ops. Hosted-model compatibility: tags may arrive as an exact JSON-encoded array string, but never as comma-separated prose. Always prefer the canonical op array and nested add_node node {id, kind, ref}; the execution boundary also accepts one exact graph snapshot with nodes/edges arrays and the observed trigger shorthand {nodeId, kind:\"trigger\", triggerId}, normalizing either deterministically without creating a duplicate trigger.\n\n" + opsDoc
}

func (t *CreateWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["name", "description", "tags", "changeReason", "ops"],
		"properties": {
			"name": {"type": "string", "description": "Unique workflow name."},
			"description": {"type": "string", "description": "Workflow description. Pass an empty string when the user supplied none; otherwise pass the supplied value verbatim at this top level."},
			"tags": {"type": "array", "description": "Complete workflow tag list. Pass [] when the user supplied none; otherwise pass the complete list verbatim at this top level. Hosted-model compatibility accepts an exact JSON-encoded array string too; never use comma-separated prose.", "items": {"type": "string"}},
			"ops": {"type": "array", "description": "Graph-edit op array. Prefer the canonical nested body: add_node uses node.{id,kind,ref,input,retry,pos,notes}; add_edge uses edge.{id,from,fromPort,to}. The execution boundary also accepts one exact graph snapshot with top-level nodes/edges arrays and the observed trigger shorthand nodeId/kind=trigger/triggerId; do not mix compatibility forms with canonical fields.", "items": {"type": "object", "required": ["op"], "properties": {
				"op": {"type": "string", "enum": ["set_meta", "add_node", "update_node", "delete_node", "add_edge", "update_edge", "delete_edge"]},
				"node": {"type": "object", "description": "Canonical add_node body.", "required": ["id", "kind", "ref"], "properties": {"id": {"type": "string"}, "kind": {"type": "string", "enum": ["trigger", "action", "agent", "control", "approval"]}, "ref": {"type": "string"}, "input": {"type": "object"}, "retry": {"type": "object"}, "pos": {"type": "object"}, "notes": {"type": "string"}}},
				"edge": {"type": "object", "description": "Canonical add_edge body.", "required": ["id", "from", "to"], "properties": {"id": {"type": "string"}, "from": {"type": "string"}, "fromPort": {"type": "string"}, "to": {"type": "string"}}},
				"nodeId": {"type": "string", "description": "Hosted compatibility only for add_node; prefer node.id and never send with node or id."},
				"triggerId": {"type": "string", "description": "Hosted compatibility only for add_node with kind=trigger; prefer node.ref and never send with node or ref."}
			}}},
			"changeReason": {"type": "string", "description": "One-line audit reason. Pass an empty string when the user supplied none; otherwise pass it verbatim at this top level, never inside ops."}
		}
	}`)
}

func (t *CreateWorkflow) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name string          `json:"name"`
		Ops  json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("create_workflow: bad args: %w", err)
	}
	if a.Name == "" {
		return ErrNameRequired
	}
	if !hasWorkflowOps(a.Ops) {
		return ErrOpsRequired
	}
	normalized, err := decodeWorkflowOps(a.Ops)
	if err != nil {
		return fmt.Errorf("create_workflow: bad args: %w", err)
	}
	var ops []json.RawMessage
	if err := json.Unmarshal(normalized, &ops); err != nil || len(ops) == 0 {
		return ErrOpsRequired
	}
	if err := requireCreateWorkflowMetadata(args); err != nil {
		return err
	}
	return nil
}

func (t *CreateWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name         string          `json:"name"`
		Description  string          `json:"description"`
		Tags         json.RawMessage `json:"tags"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_workflow: bad args: %w", err)
	}
	tags, err := decodeWorkflowTags(args.Tags)
	if err != nil {
		return "", fmt.Errorf("create_workflow: bad args: %w", err)
	}
	normalizedOps, err := decodeWorkflowOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_workflow: %w", err)
	}
	ops, err := workflowdomain.ParseOps(normalizedOps)
	if err != nil {
		return "", fmt.Errorf("create_workflow: %w", err)
	}
	w, v, err := t.svc.Create(ctx, workflowapp.CreateInput{
		Name: args.Name, Description: args.Description, Tags: tags, Ops: ops, ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("create_workflow: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": w.ID, "versionId": v.ID, "version": v.Version, "active": w.Active, "lifecycleState": w.LifecycleState}), nil
}

// --- edit_workflow ---------------------------------------------------------

type EditWorkflow struct{ svc *workflowapp.Service }

func (t *EditWorkflow) Name() string { return "edit_workflow" }

func (t *EditWorkflow) Description() string {
	return "Edit a workflow graph: apply ops on top of its active graph, producing a new version that takes effect immediately. IMPORTANT: this is NOT the filesystem Edit tool. Never send file_path, old_string, or new_string. This tool requires the workflowId plus one non-empty ops array; metadata changes belong inside a set_meta op. If the workflowId does not exist, make this one valid call and report the returned error; do not create or retry. Same op shapes as create_workflow; the execution boundary also accepts the one observed exact alias type:<known operation> when a hosted model emits it instead of op. Use revert_workflow to switch the active version to an older one.\n\n" + opsDoc
}

func (t *EditWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["workflowId", "ops"],
		"properties": {
			"workflowId": {"type": "string", "description": "Exact workflow entity ID (wf_...), not a file path."},
			"ops": {"type": "array", "description": "Non-empty graph-edit op array. Prefer the canonical nested body: add_node uses node.{id,kind,ref,input,retry,pos,notes}; add_edge uses edge.{id,from,fromPort,to}. Do not use file_path, old_string, new_string, set_nodes, or set_edges.", "minItems": 1, "items": {"type": "object", "required": ["op"], "properties": {
				"op": {"type": "string", "enum": ["set_meta", "add_node", "update_node", "delete_node", "add_edge", "update_edge", "delete_edge"]},
				"name": {"type": "string", "description": "set_meta only."},
				"description": {"type": "string", "description": "set_meta only."},
				"tags": {"type": "array", "items": {"type": "string"}, "description": "set_meta only."},
				"concurrency": {"type": "string", "enum": ["serial", "skip", "buffer_one", "replace", "allow_all"], "description": "set_meta only."},
				"node": {"type": "object", "description": "Canonical add_node body.", "required": ["id", "kind", "ref"], "properties": {"id": {"type": "string"}, "kind": {"type": "string", "enum": ["trigger", "action", "agent", "control", "approval"]}, "ref": {"type": "string"}, "input": {"type": "object"}, "retry": {"type": "object"}, "pos": {"type": "object"}, "notes": {"type": "string"}}},
				"edge": {"type": "object", "description": "Canonical add_edge body.", "required": ["id", "from", "to"], "properties": {"id": {"type": "string"}, "from": {"type": "string"}, "fromPort": {"type": "string"}, "to": {"type": "string"}}},
				"id": {"type": "string", "description": "Node or edge id for update/delete operations."},
				"patch": {"type": "object", "description": "Top-level patch for update_node/update_edge."},
				"nodeId": {"type": "string", "description": "Hosted compatibility only for add_node; prefer node.id."},
				"triggerId": {"type": "string", "description": "Hosted compatibility only for add_node with kind=trigger; prefer node.ref."}
			}}},
			"changeReason": {"type": "string", "description": "One-line reason for this edit."}
		}
	}`)
}

func (t *EditWorkflow) ValidateInput(args json.RawMessage) error {
	var a struct {
		WorkflowID string          `json:"workflowId"`
		Ops        json.RawMessage `json:"ops"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("edit_workflow: bad args: %w", err)
	}
	if a.WorkflowID == "" {
		return ErrWorkflowIDRequired
	}
	if !hasWorkflowOps(a.Ops) {
		return ErrOpsRequired
	}
	normalized, err := decodeWorkflowOps(a.Ops)
	if err != nil {
		return fmt.Errorf("edit_workflow: bad args: %w", err)
	}
	var ops []json.RawMessage
	if err := json.Unmarshal(normalized, &ops); err != nil || len(ops) == 0 {
		return ErrOpsRequired
	}
	return nil
}

func (t *EditWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		WorkflowID   string          `json:"workflowId"`
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_workflow: bad args: %w", err)
	}
	normalizedOps, err := decodeWorkflowOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("edit_workflow: %w", err)
	}
	ops, err := workflowdomain.ParseOps(normalizedOps)
	if err != nil {
		return "", fmt.Errorf("edit_workflow: %w", err)
	}
	v, err := t.svc.Edit(ctx, workflowapp.EditInput{ID: args.WorkflowID, Ops: ops, ChangeReason: args.ChangeReason})
	if err != nil {
		return "", fmt.Errorf("edit_workflow: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.WorkflowID, "versionId": v.ID, "version": v.Version}), nil
}

// --- revert_workflow -------------------------------------------------------

type RevertWorkflow struct{ svc *workflowapp.Service }

func (t *RevertWorkflow) Name() string { return "revert_workflow" }

func (t *RevertWorkflow) Description() string {
	return "Switch a workflow's active graph version to an existing version by its number. This only moves the active pointer — newer versions are kept in history and can be switched back to. The version must be a positive integer; for hosted-model compatibility, an exact decimal integer string is also accepted, while floats, booleans, arrays, and malformed strings are rejected. IMPORTANT: make one call containing BOTH the required workflowId and version keys; never omit either key, call get_workflow to verify, or retry. The tool result is authoritative: if the requested version does not exist, report that failure without another tool call."
}

func (t *RevertWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["workflowId", "version"],
		"properties": {
			"workflowId": {"type": "string", "description": "REQUIRED exact existing workflow entity ID (wf_...). Never omit or send an empty object."},
			"version": {"type": "integer", "description": "REQUIRED target version number. Send this key in the same call as workflowId. For hosted-model compatibility, an exact decimal integer string is also accepted; floats, booleans, arrays, and malformed strings are rejected."}
		}
	}`)
}

func (t *RevertWorkflow) ValidateInput(args json.RawMessage) error {
	var a struct {
		WorkflowID string          `json:"workflowId"`
		Version    json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("revert_workflow: bad args: %w", err)
	}
	if a.WorkflowID == "" {
		return ErrWorkflowIDRequired
	}
	version, err := decodeWorkflowVersion(a.Version)
	if err != nil {
		return fmt.Errorf("revert_workflow: %w", err)
	}
	if version <= 0 {
		return ErrVersionPositive
	}
	return nil
}

func (t *RevertWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		WorkflowID string          `json:"workflowId"`
		Version    json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("revert_workflow: bad args: %w", err)
	}
	version, err := decodeWorkflowVersion(args.Version)
	if err != nil {
		return "", fmt.Errorf("revert_workflow: bad args: %w", err)
	}
	v, err := t.svc.Revert(ctx, args.WorkflowID, version)
	if err != nil {
		return "", fmt.Errorf("revert_workflow: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": args.WorkflowID, "activeVersionId": v.ID, "version": v.Version}), nil
}

// --- delete_workflow -------------------------------------------------------

type DeleteWorkflow struct {
	svc  *workflowapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteWorkflow) Name() string { return "delete_workflow" }

func (t *DeleteWorkflow) MinimumDanger() toolapp.DangerLevel { return toolapp.DangerDangerous }

func (t *DeleteWorkflow) CallIdentity(args json.RawMessage) string {
	var fields struct {
		WorkflowID string `json:"workflowId"`
		AliasID    string `json:"id"`
	}
	if err := json.Unmarshal(args, &fields); err != nil {
		return ""
	}
	id := strings.TrimSpace(fields.WorkflowID)
	if id == "" {
		id = strings.TrimSpace(fields.AliasID)
	}
	if id == "" {
		return ""
	}
	return "workflow:" + id
}

func (t *DeleteWorkflow) Description() string {
	return "This call is always dangerous and requires explicit user approval; never downgrade its danger field. Soft-delete a workflow and stop its automation (listeners and in-flight runs). The workflow primary row is NOT restorable: there is no restore operation, so never tell the user it can be recovered. Immutable graph versions and flowrun history remain readable for audit. Pass the required workflowId key (not a generic id); the execution boundary may accept an exact hosted-model id alias only when workflowId is absent. Send no other keys: file_path, old_string, new_string, or other filesystem Edit fields are invalid here. The result reports how many other entities referenced it (and may now fail) — to check dependents BEFORE deleting, use get_relations."
}

func (t *DeleteWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["workflowId"],
		"additionalProperties": false,
		"properties": {"workflowId": {"type": "string", "description": "REQUIRED workflow entity ID (wf_...). Use this exact key; do not send a generic id key."}}
	}`)
}

func decodeDeleteWorkflowID(raw json.RawMessage) (string, error) {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return "", fmt.Errorf("delete_workflow: bad args: %w", err)
	}
	for key := range fields {
		if key != "workflowId" && key != "id" {
			return "", fmt.Errorf("delete_workflow: unknown field %q (only workflowId is accepted; id is a hosted-model alias)", key)
		}
	}
	var args struct {
		WorkflowID string `json:"workflowId"`
		AliasID    string `json:"id"`
	}
	if err := json.Unmarshal(raw, &args); err != nil {
		return "", fmt.Errorf("delete_workflow: bad args: %w", err)
	}
	workflowID := strings.TrimSpace(args.WorkflowID)
	aliasID := strings.TrimSpace(args.AliasID)
	if workflowID != "" && aliasID != "" && workflowID != aliasID {
		return "", fmt.Errorf("delete_workflow: workflowId and id must identify the same workflow")
	}
	if workflowID != "" {
		return workflowID, nil
	}
	if aliasID != "" {
		return aliasID, nil
	}
	return "", ErrWorkflowIDRequired
}

func (t *DeleteWorkflow) ValidateInput(args json.RawMessage) error {
	_, err := decodeDeleteWorkflowID(args)
	return err
}

func (t *DeleteWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	workflowID, err := decodeDeleteWorkflowID([]byte(argsJSON))
	if err != nil {
		return "", err
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindWorkflow, workflowID)
	if err := t.svc.Delete(ctx, workflowID); err != nil {
		return "", fmt.Errorf("delete_workflow: %w", err)
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(map[string]any{
		"id":              workflowID,
		"deleted":         true,
		"restorable":      false,
		"historyRetained": true,
	}, deps)), nil
}
