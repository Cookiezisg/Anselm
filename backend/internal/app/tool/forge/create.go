// create.go — create_forge system tool: LLM streams Python code that becomes
// a new forge. AST is dry-run validated before persistence so a syntactically
// invalid generation gives the LLM a clean retry signal without DB churn.
//
// SSE: emits forge events (entity-state). The forge ID is pre-allocated up
// front so every snapshot during streaming carries the same identity that
// the final saved row will have. The Forge stays in-memory until the final
// save — failures discard the draft cleanly without DB writes.
//
// create.go — create_forge 系统工具：LLM 流式生成 Python 代码作为新 forge。
// 持久化前先 dry-run AST 校验——语法错的生成给 LLM 干净的重试信号，不污染 DB。
//
// SSE：发 forge 事件（entity-state）。forge ID 提前预分配，让流式每帧快照
// 与最终落库行身份一致。落库前 forge 仅在内存——失败时干净丢弃，不污染 DB。
package forge

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
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
	uid, _ := reqctxpkg.GetUserID(ctx)

	// Pre-allocate the forge ID and build an in-memory draft. Each streaming
	// chunk updates draft.Code and publishes a forge snapshot — the forge
	// panel sees the entity grow in real time. Nothing is written to the DB
	// until the final svc.Create call below.
	//
	// 预分配 forge ID 并构造内存 draft。每个流 chunk 更新 draft.Code 并推
	// forge 快照——forge 面板看到 entity 实时生长。落库只在下方 svc.Create 时发生。
	forgeID := forgeapp.NewForgeID()
	now := time.Now().UTC()
	draft := &forgedomain.Forge{
		ID:           forgeID,
		UserID:       uid,
		Name:         args.Name,
		Description:  args.Description,
		Code:         "",
		Parameters:   "[]",
		ReturnSchema: "{}",
		Tags:         "[]",
		VersionCount: 0,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: draft})

	code, err := streamCode(ctx,
		buildCreatePrompt(args.Name, args.Description, args.Instruction),
		t.picker, t.keys, t.factory,
		func(accumulated string) {
			draft.Code = accumulated
			draft.UpdatedAt = time.Now().UTC()
			t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: draft})
		},
	)
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
		ID:   forgeID,
		Name: args.Name, Description: args.Description, Code: code,
	})
	if err != nil {
		return "", fmt.Errorf("create_forge: save: %w", err)
	}

	// Final snapshot reflects the persisted entity (parameters / return schema
	// parsed, version_count=1, etc.).
	//
	// 最终快照反映落库后的 entity（parameters / return schema 已解析、version_count=1 等）。
	t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: forge})

	var params any
	if err := json.Unmarshal([]byte(forge.Parameters), &params); err != nil {
		return "", fmt.Errorf("create_forge: corrupted parameters after save for forge %q: %w", forge.ID, err)
	}
	b, _ := json.Marshal(map[string]any{
		"forge_id": forge.ID, "name": forge.Name, "parameters": params,
	})
	return string(b), nil
}
