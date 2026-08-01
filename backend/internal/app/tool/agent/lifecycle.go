package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"

	agentapp "github.com/sunweilin/anselm/backend/internal/app/agent"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// --- revert_agent ----------------------------------------------------------

type RevertAgent struct{ svc *agentapp.Service }

// revertAgentArgs keeps the public schema's integer version while accepting the exact
// integer-string encoding emitted by some hosted models. No other coercion is allowed.
//
// revertAgentArgs 保持公开 schema 的 integer，同时兼容部分托管模型发出的整数串编码；不做其他隐式转换。
type revertAgentArgs struct {
	AgentID string
	Version int
}

func (a *revertAgentArgs) UnmarshalJSON(data []byte) error {
	var raw struct {
		AgentID string          `json:"agentId"`
		Version json.RawMessage `json:"version"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	version, err := decodeRevertAgentVersion(raw.Version)
	if err != nil {
		return fmt.Errorf("version: %w", err)
	}
	*a = revertAgentArgs{AgentID: raw.AgentID, Version: version}
	return nil
}

func decodeRevertAgentVersion(raw json.RawMessage) (int, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return 0, nil
	}
	var value int
	if err := json.Unmarshal(raw, &value); err == nil {
		return value, nil
	}
	var text string
	if err := json.Unmarshal(raw, &text); err != nil {
		return 0, fmt.Errorf("must be integer, got %s", string(raw))
	}
	value, err := strconv.Atoi(strings.TrimSpace(text))
	if err != nil {
		return 0, fmt.Errorf("must be integer, got %q", text)
	}
	return value, nil
}

func (t *RevertAgent) Name() string { return "revert_agent" }

func (t *RevertAgent) Description() string {
	return "Revert an agent's active version to an existing older version number (does not renumber). The required JSON keys are exactly agentId (the ag_ id) and version (an integer; an integer string is also accepted). Use when a recent edit made it worse — the version history is the undo. Note: name, description and tags are NOT versioned (they live on the agent), so a revert restores only the versioned config (prompt/tools/knowledge/skill/inputs/outputs/model) and leaves name/description/tags unchanged — use update_agent_meta to also change those."
}

func (t *RevertAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","required":["agentId","version"],"properties":{"agentId":{"type":"string","description":"Required. The exact ag_ agent id."},"version":{"type":"integer","description":"Required target version number to make active. Send a JSON integer, not a name."}}}`)
}

func (t *RevertAgent) ValidateInput(args json.RawMessage) error {
	var a revertAgentArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("revert_agent: bad args: %w", err)
	}
	if strings.TrimSpace(a.AgentID) == "" || a.Version < 1 {
		return ErrRevertArgsRequired
	}
	return nil
}

func (t *RevertAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a revertAgentArgs
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("revert_agent: bad args: %w", err)
	}
	v, err := t.svc.Revert(ctx, a.AgentID, a.Version)
	if err != nil {
		return "", fmt.Errorf("revert_agent: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"agentId": a.AgentID, "versionId": v.ID, "version": v.Version}), nil
}

// --- delete_agent ----------------------------------------------------------

type DeleteAgent struct {
	svc  *agentapp.Service
	deps toolapp.DependentCounter
}

func (t *DeleteAgent) Name() string { return "delete_agent" }

func (t *DeleteAgent) Description() string {
	return "Delete an agent (soft-delete). Its execution history is retained and every relation edge touching it is removed. The JSON result is authoritative: removedRelationEdges is the exact pre-delete edge snapshot; dependents, when present, are only incoming equip/link references that may now fail. Never infer or invent edge types, counts, or IDs that are not present in the result. If relationAudit is unavailable, say the exact edge audit was unavailable."
}

func (t *DeleteAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","required":["agentId"],"properties":{"agentId":{"type":"string"}}}`)
}

func (t *DeleteAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		AgentID string `json:"agentId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("delete_agent: bad args: %w", err)
	}
	if strings.TrimSpace(a.AgentID) == "" {
		return ErrAgentIDRequired
	}
	return nil
}

func (t *DeleteAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		AgentID string `json:"agentId"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("delete_agent: bad args: %w", err)
	}
	deps := toolapp.DependentRefs(ctx, t.deps, relationdomain.EntityKindAgent, a.AgentID)
	edges, auditOK := toolapp.RelationEdgeRefs(ctx, t.deps, relationdomain.EntityKindAgent, a.AgentID)
	if err := t.svc.Delete(ctx, a.AgentID); err != nil {
		return "", fmt.Errorf("delete_agent: %w", err)
	}
	out := map[string]any{
		"agentId":          a.AgentID,
		"deleted":          true,
		"executionHistory": "retained",
	}
	if auditOK {
		out["removedRelationEdges"] = edges
		out["removedRelationCount"] = len(edges)
	} else {
		out["relationAudit"] = "unavailable"
	}
	return toolapp.ToJSON(toolapp.AnnotateDependents(out, deps)), nil
}

// --- invoke_agent ----------------------------------------------------------

type InvokeAgent struct{ svc *agentapp.Service }

func (t *InvokeAgent) Name() string { return "invoke_agent" }

func (t *InvokeAgent) Description() string {
	return "Run an agent: it executes its ReAct loop over the given input and returns the final output (shaped by its outputSchema). Find one with search_agent first. The run is recorded — inspect it later with search_agent_executions / get_agent_execution (the latter carries the full transcript)."
}

func (t *InvokeAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","required":["agentId","input"],"properties":{"agentId":{"type":"string"},"input":{"type":"object","description":"The task/data for THIS run, as an object. Pass {} only if the agent's prompt is fully self-contained. This is where you say what the agent should do — there is no separate 'prompt' field."}}}`)
}

func (t *InvokeAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		AgentID string            `json:"agentId"`
		Input   toolapp.ObjectMap `json:"input"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("invoke_agent: bad args: %w", err)
	}
	if strings.TrimSpace(a.AgentID) == "" {
		return ErrAgentIDRequired
	}
	// Require input so a misnamed task (e.g. a "prompt" key) fails loudly instead of running the
	// agent with empty input and returning a misleading ok:true. {} is allowed for self-contained agents.
	//
	// 要求 input：任务键写错（如用了 "prompt"）就显式报错，而非空 input 跑出误导的 ok:true。self-contained agent 传 {}。
	if a.Input == nil {
		return ErrAgentInputRequired
	}
	return nil
}

func (t *InvokeAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var a struct {
		AgentID string            `json:"agentId"`
		Input   toolapp.ObjectMap `json:"input"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &a); err != nil {
		return "", fmt.Errorf("invoke_agent: bad args: %w", err)
	}
	res, err := t.svc.InvokeAgent(ctx, agentapp.InvokeInput{
		AgentID:     a.AgentID,
		Input:       a.Input,
		TriggeredBy: agentdomain.TriggeredByChat,
	})
	if err != nil {
		return "", fmt.Errorf("invoke_agent: %w", err)
	}
	return toolapp.ToJSON(res), nil
}

// --- update_agent_meta -----------------------------------------------------

type UpdateAgentMeta struct{ svc *agentapp.Service }

func (t *UpdateAgentMeta) Name() string { return "update_agent_meta" }

func (t *UpdateAgentMeta) Description() string {
	return "Rename or re-describe an agent: patches name/description/tags on the agent row only — NO new version. This is the right tool for a pure rename/redescribe; name/description/tags are NOT part of the versioned config (prompt/tools/knowledge/skill/io/model), so edit_agent cannot change them. Pass only the fields you want to change (omit the rest)."
}

func (t *UpdateAgentMeta) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"required": ["agentId"],
		"properties": {
			"agentId": {"type": "string"},
			"name": {"type": "string", "description": "New name (lowercase alphanumeric + dashes/underscores, 1-64 chars)."},
			"description": {"type": "string"},
			"tags": {"type": "array", "items": {"type": "string"}}
		}
	}`)
}

func (t *UpdateAgentMeta) ValidateInput(args json.RawMessage) error {
	var a struct {
		AgentID string `json:"agentId"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("update_agent_meta: bad args: %w", err)
	}
	if a.AgentID == "" {
		return ErrAgentIDRequired
	}
	return nil
}

func (t *UpdateAgentMeta) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		AgentID     string    `json:"agentId"`
		Name        *string   `json:"name"`
		Description *string   `json:"description"`
		Tags        *[]string `json:"tags"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("update_agent_meta: bad args: %w", err)
	}
	ag, err := t.svc.UpdateMeta(ctx, agentapp.UpdateMetaInput{ID: args.AgentID, Name: args.Name, Description: args.Description, Tags: args.Tags})
	if err != nil {
		return "", fmt.Errorf("update_agent_meta: %w", err)
	}
	return toolapp.ToJSON(map[string]any{"id": ag.ID, "name": ag.Name, "description": ag.Description, "tags": ag.Tags}), nil
}
