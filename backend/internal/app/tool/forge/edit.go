// edit.go — edit_forge system tool: proposes a change to an existing forge.
// All edits go through pending review (user must accept/reject before changes
// take effect). Two paths:
//
//   - With Instruction: LLM regenerates code, ForgeCodeStreaming SSE streams
//     deltas, ForgePendingCreated fires when saved.
//   - Without Instruction (metadata-only): no LLM call, no streaming;
//     ForgeMetadataUpdated fires so UI can distinguish from code-regen.
//
// edit.go — edit_forge 系统工具：对现有 forge 提出变更。所有编辑走 pending 审核
// （用户 accept/reject 后才生效）。两条路径：
//
//   - 含 Instruction：LLM 重生代码，ForgeCodeStreaming SSE 推 deltas，
//     ForgePendingCreated 在保存时触发。
//   - 不含 Instruction（仅改元数据）：不调 LLM，不推流；
//     ForgeMetadataUpdated 触发让 UI 区分这种"非代码"路径。
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

// EditForge implements the edit_forge system tool.
//
// EditForge 实现 edit_forge 系统工具。
type EditForge struct {
	svc     *forgeapp.Service
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
	bridge  eventsdomain.Bridge
}

// ── Identity ──────────────────────────────────────────────────────────────────

func (t *EditForge) Name() string { return "edit_forge" }

func (t *EditForge) Description() string {
	return "Propose a change to an existing forge. You can update the code (via instruction), " +
		"name, description, or tags. All changes become a pending proposal that the user must confirm."
}

func (t *EditForge) Parameters() json.RawMessage {
	return json.RawMessage(`{
		"type": "object",
		"properties": {
			"forge_id":    {"type": "string", "description": "Forge to edit"},
			"instruction": {"type": "string", "description": "Code modification instruction (omit to only update metadata)"},
			"name":        {"type": "string", "description": "New forge name"},
			"description": {"type": "string", "description": "New description"}
		},
		"required": ["forge_id"]
	}`)
}

// ── Static metadata ───────────────────────────────────────────────────────────

func (t *EditForge) IsReadOnly() bool        { return false }
func (t *EditForge) NeedsReadFirst() bool    { return false }
func (t *EditForge) RequiresWorkspace() bool { return false }

// ── Args-dependent hooks ──────────────────────────────────────────────────────

func (t *EditForge) IsConcurrencySafe(json.RawMessage) bool { return false }

func (t *EditForge) ValidateInput(json.RawMessage) error { return nil }

func (t *EditForge) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

func (t *EditForge) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		ForgeID     string `json:"forge_id"`
		Instruction string `json:"instruction"`
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("edit_forge: bad args: %w", err)
	}
	convID, _ := reqctxpkg.GetConversationID(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)

	snap := forgeapp.PendingSnapshot{
		Name: args.Name, Description: args.Description, Instruction: args.Instruction,
	}

	// Code-regen path: only when instruction is provided.
	// 代码重生路径：仅当 instruction 非空。
	if args.Instruction != "" {
		current, err := t.svc.Get(ctx, args.ForgeID)
		if err != nil {
			return "", fmt.Errorf("edit_forge: get forge: %w", err)
		}
		newCode, err := streamCode(ctx, convID, args.ForgeID, "edit",
			buildEditPrompt(current.Code, args.Instruction),
			t.picker, t.keys, t.factory, t.bridge)
		if err != nil {
			return "", fmt.Errorf("edit_forge: generate code: %w", err)
		}
		// Dry-run AST before committing pending. Same rationale as CreateForge.
		// 提交 pending 前 dry-run AST。理由同 CreateForge。
		if err := t.svc.ParseCode(newCode); err != nil {
			return "", fmt.Errorf("edit_forge: generated code failed AST parse, please regenerate: %w", err)
		}
		snap.Code = newCode
	}

	pending, err := t.svc.CreatePending(ctx, args.ForgeID, snap)
	if err != nil {
		return "", fmt.Errorf("edit_forge: create pending: %w", err)
	}

	// Pick event by path: with code → ForgePendingCreated; metadata-only →
	// ForgeMetadataUpdated. Lets UI distinguish "code panel updates" vs
	// "metadata changed silently" without inferring from missing streams.
	//
	// 按路径选事件：含代码 → ForgePendingCreated；仅元数据 → ForgeMetadataUpdated。
	// 让 UI 区分"代码面板更新" vs "静默元数据变更"，无需从缺失的流推断。
	if args.Instruction != "" {
		t.bridge.Publish(ctx, convID, eventsdomain.ForgePendingCreated{
			ConversationID: convID, MessageID: msgID, ToolCallID: toolCallID,
			ForgeID: args.ForgeID, PendingID: pending.ID, Instruction: args.Instruction,
		})
	} else {
		t.bridge.Publish(ctx, convID, eventsdomain.ForgeMetadataUpdated{
			ConversationID: convID, MessageID: msgID, ToolCallID: toolCallID,
			ForgeID: args.ForgeID, PendingID: pending.ID,
		})
	}

	b, _ := json.Marshal(map[string]string{"pending_id": pending.ID, "forge_id": args.ForgeID})
	return string(b), nil
}
