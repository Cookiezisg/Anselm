// edit.go — edit_forge system tool: proposes a change to an existing forge.
// All edits go through pending review (user must accept/reject before changes
// take effect). Two paths:
//
//   - With Instruction: LLM regenerates code, forge snapshots stream as the
//     pending entity's code grows; final svc.CreatePending persists.
//   - Without Instruction (metadata-only): no LLM call, no streaming;
//     a single forge snapshot fires after the metadata-only pending is saved.
//
// SSE: emits forge events (entity-state). The pending row's ID is
// pre-allocated up front so every snapshot during streaming carries the same
// identity as the eventually persisted row. Snapshots include the parent
// Forge with its computed .Pending field populated by the in-memory draft.
//
// edit.go — edit_forge 系统工具：对现有 forge 提出变更。所有编辑走 pending 审核
// （用户 accept/reject 后才生效）。两条路径：
//
//   - 含 Instruction：LLM 重生代码，pending entity 的 code 随每帧 forge 快照
//     生长；最终 svc.CreatePending 落库。
//   - 不含 Instruction（仅元数据）：不调 LLM，不推流；
//     metadata-only pending 落库后发一帧 forge 快照。
//
// SSE：发 forge 事件（entity-state）。pending 行 ID 预分配，让流式每帧快照与
// 最终落库行身份一致。快照携带父 Forge，.Pending 由内存 draft 填充。
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

	current, err := t.svc.Get(ctx, args.ForgeID)
	if err != nil {
		return "", fmt.Errorf("edit_forge: get forge: %w", err)
	}

	pendingID := forgeapp.NewVersionID()
	snap := forgeapp.PendingSnapshot{
		ID: pendingID,
		Name: args.Name, Description: args.Description,
		ChangeReason: args.Instruction,
	}

	// Code-regen path: only when instruction is provided.
	// 代码重生路径：仅当 instruction 非空。
	if args.Instruction != "" {
		// Build a draft pending in memory so streaming snapshots carry the
		// growing code as Forge.Pending.Code.
		//
		// 构造内存 draft pending，让流式快照通过 Forge.Pending.Code 携带生长中的代码。
		now := time.Now().UTC()
		draftPending := &forgedomain.ForgeVersion{
			ID:           pendingID,
			ForgeID:      current.ID,
			UserID:       current.UserID,
			Status:       forgedomain.VersionStatusPending,
			Name:         pickNonEmpty(args.Name, current.Name),
			Description:  pickNonEmpty(args.Description, current.Description),
			Code:         "",
			Parameters:   current.Parameters,
			ReturnSchema: current.ReturnSchema,
			Tags:         current.Tags,
			ChangeReason: args.Instruction,
			CreatedAt:    now,
			UpdatedAt:    now,
		}
		current.Pending = draftPending
		t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: current})

		newCode, err := streamCode(ctx,
			buildEditPrompt(current.Code, args.Instruction),
			t.picker, t.keys, t.factory,
			func(accumulated string) {
				draftPending.Code = accumulated
				draftPending.UpdatedAt = time.Now().UTC()
				t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: current})
			},
		)
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

	// Final snapshot reflects the persisted pending (real timestamps,
	// parsed parameters / return schema).
	//
	// 最终快照反映落库后的 pending（真实时间戳、解析过的 parameters / return schema）。
	current.Pending = pending
	current.UpdatedAt = time.Now().UTC()
	t.bridge.Publish(ctx, convID, eventsdomain.Forge{Forge: current})

	b, _ := json.Marshal(map[string]string{"pending_id": pending.ID, "forge_id": args.ForgeID})
	return string(b), nil
}

// pickNonEmpty returns a if non-empty, otherwise b.
// pickNonEmpty 非空返 a，否则返 b。
func pickNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}
