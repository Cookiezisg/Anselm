package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	workflowapp "github.com/sunweilin/forgify/backend/internal/app/workflow"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	forgepkg "github.com/sunweilin/forgify/backend/internal/pkg/forge"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

type CreateWorkflow struct {
	svc   *workflowapp.Service
	forge forgepkg.Publisher
}

func (t *CreateWorkflow) Name() string { return "create_workflow" }

func (t *CreateWorkflow) Description() string {
	return `Create a new workflow by applying a sequence of ops. v1 auto-accepts.

OPS (exact field names — use these, no synonyms):
  {"op":"set_meta", "name":"...", "description":"...", "tags":[...]}
  {"op":"add_node", "node":{"id":"n1", "type":"<nodeType>", "config":{...}}}
  {"op":"add_edge", "edge":{"id":"e1", "from":"<nodeId>", "to":"<nodeId>", "fromPort":"<port>"}}
  {"op":"set_variable", "variable":{"name":"...", "type":"string|number|integer|boolean|object|array", "default":...}}

NODE TYPES + CONFIG SHAPES (pin these exactly — wrong field names fail silently):
  trigger:   {"triggerType": "manual"|"cron"|"webhook"|"fsnotify"|"polling", "schedule":"0 * * * *"}  (cron field is "schedule", not "cron" or "expression")
  function:  {"functionId": "fn_xxx", "args": {"param": "<CEL expr or literal>"}}
  handler:   {"handlerName": "MyHandler", "method": "run", "args": {...}}
  agent:     {"prompt": "...", "maxTurns": 10, "enabledTools": ["fn_xxx"]}
  case:      {"branches": [{"when": "<boolean CEL>", "to": "<nodeId>", "emit": {"key": "<CEL>"}}, ..., {"when": "true", "to": "<fallback nodeId>"}]}
  approval:  {"prompt": "...", "timeoutSec": 3600, "timeoutBehavior": "reject"|"approve"|"fail"}
  condition: {"branches": [{"when": "<CEL bool>", "to": "<nodeId>"}]}
  mcp:       {"serverName": "server", "tool": "tool_name", "args": {...}}
  llm:       {"prompt": "...", "model": null}
  skill:     {"skillName": "skill"}
  http:      {"url": "https://...", "method": "POST", "body": {...}}
  wait:      {"durationMs": 60000}
  variable:  {"operation": "set", "name": "x", "value": "<CEL>"}
  loop:      {"items": "<CEL array expr>", "body": {"nodes":[...], "edges":[...]}}
  parallel:  {}

GRAPH RULES:
  - At least one trigger node required. DAG ends when no outgoing edges remain — NO "end"/"output"/"finish" nodes.
  - Edges connect node IDs directly. fromPort only on branching nodes.

BRANCHING NODES (require fromPort on each outgoing edge):
  - case/condition → fromPort: matches the "to" of the winning branch
  - approval → fromPort: "yes" | "no"
  - loop → fromPort: "iterate" | "done"

ALWAYS call capability_check_workflow after creating to verify refs and structure.
Keep set_meta.description to one short line — it appears in the capability menu.`
}

func (t *CreateWorkflow) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"ops": {
				"type": "array",
				"description": "Sequence of ops. Each op is one of: set_meta / add_node / add_edge / set_variable / update_node / update_edge / delete_node / delete_edge / unset_variable. See tool description for exact shapes.",
				"items": {"type": "object"}
			},
			"changeReason": {"type": "string", "description": "One-line reason for this workflow creation"}
		},
		"required": ["ops"]
	}`)
}

func (t *CreateWorkflow) IsReadOnly() bool        { return false }
func (t *CreateWorkflow) NeedsReadFirst() bool    { return false }
func (t *CreateWorkflow) RequiresWorkspace() bool { return false }

func (t *CreateWorkflow) ValidateInput(json.RawMessage) error { return nil }
func (t *CreateWorkflow) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

func (t *CreateWorkflow) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Ops          json.RawMessage `json:"ops"`
		ChangeReason string          `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_workflow: bad args: %w", err)
	}
	ops, err := workflowapp.ParseOps(args.Ops)
	if err != nil {
		return "", fmt.Errorf("create_workflow: %w", err)
	}

	em := eventlogpkg.From(ctx)
	progID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, map[string]any{
		"stage": "applying ops",
		"count": len(ops),
	})
	defer em.StopBlock(ctx, progID, eventlogdomain.StatusCompleted, nil)

	w, v, err := t.svc.Create(ctx, workflowapp.CreateInput{
		Ops:             ops,
		ChangeReason:    args.ChangeReason,
		ProgressBlockID: progID,
	})
	if err != nil {
		em.StopBlock(ctx, progID, eventlogdomain.StatusError, err)
		// We don't know the workflow ID (Create failed before persistence),
		// so we can't publish forge_started/completed for this failure path.
		// Caller sees the wrapped err via the tool_result.
		// Create 失败前无 workflow ID,无法发 forge 事件,err 经 tool_result 抛。
		return "", fmt.Errorf("create_workflow: %w", err)
	}

	scope := eventlogdomain.Scope{Kind: eventlogdomain.KindWorkflow, ID: w.ID}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	t.forge.PublishStarted(ctx, scope, forgedomain.OperationCreate, convID, toolCallID)
	t.forge.PublishCompleted(ctx, scope, forgedomain.CompletedOK, v.ID, "", 1, nil)

	versionN := 1
	if v.Version != nil {
		versionN = *v.Version
	}
	out := map[string]any{
		"id":         w.ID,
		"name":       w.Name,
		"versionId":  v.ID,
		"version":    versionN,
		"status":     v.Status,
		"opsApplied": len(ops),
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
