// create.go — create_forge system tool: LLM streams Python code that becomes
// a new forge. AST is dry-run validated before persistence so a syntactically
// invalid generation gives the LLM a clean retry signal without DB churn.
//
// create.go — create_forge 系统工具：LLM 流式生成 Python 代码作为新 forge。
// 持久化前先 dry-run AST 校验——语法错的生成给 LLM 干净的重试信号，不污染 DB。
package forge

import (
	"context"
	"encoding/json"
	"fmt"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// CreateForge implements the create_forge system tool.
//
// CreateForge 实现 create_forge 系统工具。
type CreateForge struct {
	svc     *forgeapp.Service
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
	bridge  eventsdomain.Bridge
}

// ── Identity ──────────────────────────────────────────────────────────────────

func (t *CreateForge) Name() string { return "create_forge" }

func (t *CreateForge) Description() string {
	return "Create a new Python forge in the user's library. " +
		"You provide a name, description, and natural-language instruction; " +
		"the system generates the code. The user will see the code appear in real time. " +
		"The new forge is saved immediately and is callable via run_forge."
}

func (t *CreateForge) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"name":        {"type": "string", "description": "Short unique forge name (snake_case)"},
			"description": {"type": "string", "description": "What this forge does"},
			"instruction": {"type": "string", "description": "Detailed code generation instruction"}
		},
		"required": ["name", "description", "instruction"]
	}`)
}

// ── Static metadata ───────────────────────────────────────────────────────────

func (t *CreateForge) IsReadOnly() bool        { return false }
func (t *CreateForge) NeedsReadFirst() bool    { return false }
func (t *CreateForge) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ──────────────────────────────────────────────────────

func (t *CreateForge) IsConcurrencySafe(json.RawMessage) bool { return false }

func (t *CreateForge) ValidateInput(json.RawMessage) error { return nil }

func (t *CreateForge) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

func (t *CreateForge) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Instruction string `json:"instruction"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("create_forge: bad args: %w", err)
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)

	code, err := streamCode(ctx, convID, "", "create",
		buildCreatePrompt(args.Name, args.Description, args.Instruction),
		t.picker, t.keys, t.factory, t.bridge)
	if err != nil {
		return "", fmt.Errorf("create_forge: generate code: %w", err)
	}

	// Dry-run AST parse before persisting. If the LLM produced syntactically
	// invalid Python, return early with a clear retry signal instead of
	// reaching svc.Create's storage layer.
	//
	// 持久化前 dry-run AST。LLM 生成语法错的 Python 直接早返，给 LLM 干净的
	// 重试信号，不进 svc.Create 的存储层。
	if err := t.svc.ParseCode(code); err != nil {
		return "", fmt.Errorf("create_forge: generated code failed AST parse, please regenerate: %w", err)
	}

	forge, err := t.svc.Create(ctx, forgeapp.CreateInput{
		Name: args.Name, Description: args.Description, Code: code,
	})
	if err != nil {
		return "", fmt.Errorf("create_forge: save: %w", err)
	}

	t.bridge.Publish(ctx, convID, eventsdomain.ForgeCreated{
		ConversationID: convID, MessageID: msgID, ToolCallID: toolCallID,
		ForgeID: forge.ID, ForgeName: forge.Name,
	})

	var params any
	if err := json.Unmarshal([]byte(forge.Parameters), &params); err != nil {
		return "", fmt.Errorf("create_forge: corrupted parameters after save for forge %q: %w", forge.ID, err)
	}
	b, _ := json.Marshal(map[string]any{
		"forge_id": forge.ID, "name": forge.Name, "parameters": params,
	})
	return string(b), nil
}
