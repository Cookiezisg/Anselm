package agent

import (
	"context"
	"encoding/json"
	"fmt"

	agentapp "github.com/sunweilin/forgify/backend/internal/app/agent"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
)

type CreateAgent struct{ svc *agentapp.Service }

func (t *CreateAgent) Name() string { return "create_agent" }
func (t *CreateAgent) Description() string {
	return `Create a new agent (configured LLM worker). v1 auto-accepts.

FIELD SHAPES:
  outputSchema: {"kind":"free_text"} | {"kind":"enum","enums":["a","b","c"]} | {"kind":"json_schema","schema":{...JSON Schema...}}
  tools: [{"ref":"fn_xxx"},{"ref":"hd_xxx.method"},{"ref":"mcp:server/tool"}]
         NEVER include "ag_" refs — agents cannot call other agents.
  knowledge: ["doc_xxx","doc_yyy"]  (document IDs; attached as knowledge base)
  skill: "skill-name"  (optional; max 1 skill)

WHEN TO CREATE AN AGENT (not a function):
  - Classification / routing / intent detection / extraction → agent with outputSchema=enum
  - Multi-step reasoning over data → agent with tools
  - Knowledge-base Q&A → agent with knowledge docs

IMPOSSIBLE CAPABILITY RULE: Only write capabilities the agent can actually fulfill with its tools.
If it needs external data, attach a forge function/handler as a tool or use knowledge docs.

Test it with invoke_agent before referencing it in a workflow.
Keep description to one short line — it appears in the capability menu.`
}
func (t *CreateAgent) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"name":         {"type": "string"},
			"description":  {"type": "string", "description": "One short line for the capability menu"},
			"prompt":       {"type": "string"},
			"skill":        {"type": "string", "description": "Optional single skill name to pre-activate"},
			"knowledge":    {"type": "array", "items": {"type":"string"}, "description": "Document IDs"},
			"tools":        {"type": "array", "items": {"type":"object"}, "description": "[{ref:'fn_xxx'|'hd_xxx.method'|'mcp:server/tool'}]; no ag_ refs"},
			"outputSchema": {"type": "object", "description": "{kind:'free_text'|'enum'|'json_schema', enums?:[...], schema?:{...}}"},
			"modelOverride":{"type": "object", "description": "Optional model override {apiKeyId, modelId, options?}; omit to use the default agent model", "properties": {"apiKeyId":{"type":"string"},"modelId":{"type":"string"}}},
			"changeReason": {"type": "string"}
		},
		"required": ["name", "prompt"]
	}`)
}
func (t *CreateAgent) IsReadOnly() bool        { return false }
func (t *CreateAgent) NeedsReadFirst() bool    { return false }
func (t *CreateAgent) RequiresWorkspace() bool { return false }
func (t *CreateAgent) ValidateInput(args json.RawMessage) error {
	var a struct {
		Name   string `json:"name"`
		Prompt string `json:"prompt"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return err
	}
	if a.Name == "" {
		return fmt.Errorf("name is required")
	}
	if a.Prompt == "" {
		return fmt.Errorf("prompt is required")
	}
	return nil
}
func (t *CreateAgent) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t *CreateAgent) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name          string                    `json:"name"`
		Description   string                    `json:"description"`
		Tags          []string                  `json:"tags"`
		Prompt        string                    `json:"prompt"`
		Skill         string                    `json:"skill"`
		Knowledge     []string                  `json:"knowledge"`
		Tools         []agentdomain.ToolRef     `json:"tools"`
		OutputSchema  *agentdomain.OutputSchema `json:"outputSchema"`
		ModelOverride *modeldomain.ModelRef     `json:"modelOverride"`
		ChangeReason  string                    `json:"changeReason"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_agent: %w", err)
	}
	a, v, err := t.svc.Create(ctx, agentapp.CreateInput{
		Name: args.Name, Description: args.Description, Tags: args.Tags,
		Prompt: args.Prompt, Skill: args.Skill, Knowledge: args.Knowledge,
		Tools: args.Tools, OutputSchema: args.OutputSchema,
		ModelOverride: args.ModelOverride, ChangeReason: args.ChangeReason,
	})
	if err != nil {
		return "", fmt.Errorf("create_agent: %w", err)
	}
	out := map[string]any{
		"id": a.ID, "name": a.Name,
		"versionId": v.ID, "activeVersionId": a.ActiveVersionID,
		"next_step": "Agent created. Test it with invoke_agent, or reference " + a.ID + " in a workflow agent node (config.agentRef) / tool node (config.callable=" + a.ID + ").",
	}
	b, _ := json.Marshal(out)
	return string(b), nil
}
