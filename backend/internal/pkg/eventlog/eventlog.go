// Package eventlog provides ergonomic helpers around the eventlog
// Bridge: an Emitter that auto-mints message/block IDs, auto-reads
// conversationID + parent linkage from ctx, and exposes a small ctx-
// scoped API for service / tool code to call without boilerplate.
//
// Package eventlog 提供 eventlog Bridge 的易用 helper：Emitter 自动生成
// message/block ID、从 ctx 自动读 conversationID + 父链、对 service / tool
// 暴露简洁的 ctx-scoped API，让调用方无样板代码。
//
// Typical usage:
//
//	em := eventlog.From(ctx)
//	blockID := em.StartBlock(ctx, eventlogdomain.BlockTypeText, nil)
//	em.DeltaBlock(ctx, blockID, "hello")
//	em.StopBlock(ctx, blockID, eventlogdomain.StatusCompleted, nil)
//
// Parent linkage flows through ctx: tool framework calls WithParent(ctx,
// toolCallBlockID) before invoking Tool.Execute, so any StartBlock the
// tool issues is auto-parented under that tool_call.
package eventlog

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go.uber.org/zap"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Emitter is the high-level emit API used by service / tool code.
//
// All methods read conversationID from ctx via reqctx.RequireConversationID;
// callers MUST stamp it before any emit (typically the chat handler does
// this once at request entry). Missing conversationID is a wiring bug:
// methods log + return without emitting (do not panic — too disruptive
// for streaming code paths; the bridge would fail anyway).
//
// Parent linkage:
//   - StartMessage uses an explicit parentBlockID arg (top-level => "")
//   - StartBlock reads the current parent from reqctx.GetParentBlockID;
//     if missing, falls back to the in-flight messageID
//   - WithParent / WithMessage helpers narrow the scope as you descend
//
// Emitter 是 service / tool 代码用的高层 emit API。
//
// 所有方法经 reqctx.RequireConversationID 从 ctx 读 conversationID；
// 调用方必须在 emit 前注入（通常 chat handler 入口注入一次）。缺失
// 视为接线 bug：方法记录日志 + 返回而不 emit（不 panic——streaming 路径
// 太破坏；bridge 也会拒）。
//
// 父链：
//   - StartMessage 用显式 parentBlockID 参数（顶层 = ""）
//   - StartBlock 经 reqctx.GetParentBlockID 读当前 parent；缺失则回退
//     到当前 in-flight messageID
//   - WithParent / WithMessage helper 让父链随调用栈下降
type Emitter interface {
	// StartMessage opens a new message under parentBlockID (empty for
	// top-level). Returns the freshly minted msg_<16hex> ID.
	//
	// StartMessage 在 parentBlockID 下开新 message（顶层传 ""）。返
	// 新铸的 msg_<16hex> ID。
	StartMessage(ctx context.Context, role string, parentBlockID string, attrs map[string]any) string

	// StopMessage closes msgID with the given terminal status + token
	// counts (pass 0 for unknown).
	//
	// StopMessage 用给定终态 + token 数关闭 msgID（未知传 0）。
	StopMessage(ctx context.Context, msgID, status, stopReason, errCode, errMsg string, inputTokens, outputTokens int)

	// StartBlock opens a new block of blockType under the current parent
	// (read from reqctx — typically the in-flight message ID, or a
	// tool_call block ID if we're inside a tool's Execute). Returns the
	// freshly minted blk_<16hex> ID.
	//
	// StartBlock 在当前 parent（经 reqctx 读——通常是 in-flight message
	// ID，或在工具 Execute 内则是 tool_call block ID）下开 blockType 类
	// 型 block。返新铸 blk_<16hex> ID。
	StartBlock(ctx context.Context, blockType string, attrs map[string]any) string

	// StartBlockUnder opens a new block under a caller-specified parent.
	// Used when the framework needs to override the ctx-derived parent
	// (e.g. tool framework wraps Tool.Execute with a fresh parent).
	//
	// StartBlockUnder 在调用方指定的 parent 下开 block。框架需 override
	// ctx 派生 parent 时用（例：tool framework 包装 Tool.Execute）。
	StartBlockUnder(ctx context.Context, parentID, messageID, blockType string, attrs map[string]any) string

	// EmitMessageStart publishes a message_start with caller-supplied id.
	// Use when the message ID is already minted upstream (chat Service
	// pre-mints msgID before launching loop.Run so the user sees the
	// slot ID before any LLM token arrives).
	//
	// EmitMessageStart 用调用方提供的 id 推 message_start。msgID 上游已
	// 铸时用（chat Service 启 loop.Run 前预铸，让用户在 LLM 第一个 token
	// 到达前就看到 slot ID）。
	EmitMessageStart(ctx context.Context, id, role, parentBlockID string, attrs map[string]any)

	// EmitBlockStart publishes a block_start with caller-supplied id.
	// Use when the block ID is already minted upstream (e.g. tool_call
	// blocks reuse the LLM's tool-call ID; streamLLM mints text/reasoning
	// block IDs at first token arrival so subsequent deltas reference them).
	//
	// EmitBlockStart 用调用方提供的 id 推 block_start。blockID 上游已铸
	// 时用（例：tool_call 直接复用 LLM tool-call ID；streamLLM 在第一
	// 个 token 到达时铸 text/reasoning block ID 让后续 delta 能引用）。
	EmitBlockStart(ctx context.Context, id, parentID, messageID, blockType string, attrs map[string]any)

	// DeltaBlock appends delta to blockID's content.
	//
	// DeltaBlock 给 blockID 的 content 追加 delta。
	DeltaBlock(ctx context.Context, blockID, delta string)

	// StopBlock closes blockID with the given status + optional error.
	//
	// StopBlock 用给定 status + 可选 error 关闭 blockID。
	StopBlock(ctx context.Context, blockID, status string, err error)
}

// New constructs an Emitter backed by bridge. log may be nil (zap.Nop).
// repo is optional — when non-nil, every block_start / block_delta /
// block_stop also dual-writes to the message_blocks_v2 table so the new
// SSE bridge has a persistent backing for history replay (Phase 2B).
// Pass nil for tests / legacy callers that don't need DB persistence.
// Message lifecycle (message_start / message_stop) does NOT dual-write
// — messages persist through the legacy chat repo until Phase 4 cutover.
//
// New 构造一个由 bridge 支撑的 Emitter。log 可为 nil（用 zap.Nop）。
// repo 可选——非 nil 时 block_start / block_delta / block_stop 同时
// 双写到 message_blocks_v2 表，给新 SSE bridge 留持久后备供历史回放
// （Phase 2B）。测试 / legacy 调用方不需 DB 持久化时传 nil。Message
// 生命周期（message_start / message_stop）不双写——messages 走 legacy
// chat repo 直至 Phase 4 cutover。
func New(bridge eventlogdomain.Bridge, repo chatdomain.Repository, log *zap.Logger) Emitter {
	if log == nil {
		log = zap.NewNop()
	}
	return &emitter{
		bridge: bridge,
		repo:   repo,
		log:    log.Named("eventlog.emitter"),
	}
}

type emitter struct {
	bridge eventlogdomain.Bridge
	repo   chatdomain.Repository // optional dual-write target; may be nil
	log    *zap.Logger
}

func (em *emitter) requireConv(ctx context.Context, op string) (string, bool) {
	convID, ok := reqctxpkg.GetConversationID(ctx)
	if !ok {
		em.log.Warn("emit skipped: no conversationID in ctx",
			zap.String("op", op))
		return "", false
	}
	return convID, true
}

// publish forwards e to the Bridge and returns the assigned seq. ok=false
// signals a failed publish (logged); callers may still proceed (DB writes
// keyed off blockID, not seq, are still safe — only block_start cares
// about seq for the message_blocks_v2 row).
//
// publish 把 e 转给 Bridge 并返分配的 seq。ok=false 表示发布失败（已记
// 日志）；调用方仍可继续（基于 blockID 的 DB 写入与 seq 无关——只有
// block_start 用 seq 给 message_blocks_v2 行）。
func (em *emitter) publish(ctx context.Context, convID string, e eventlogdomain.Event) (int64, bool) {
	env, err := em.bridge.Publish(ctx, convID, e)
	if err != nil {
		em.log.Warn("emit failed",
			zap.String("type", e.EventType()),
			zap.String("conversationId", convID),
			zap.Error(err))
		return 0, false
	}
	return env.Seq, true
}

func (em *emitter) StartMessage(ctx context.Context, role, parentBlockID string, attrs map[string]any) string {
	convID, ok := em.requireConv(ctx, "StartMessage")
	if !ok {
		return ""
	}
	msgID := idgenpkg.New("msg")
	em.publish(ctx, convID, eventlogdomain.MessageStart{
		ConversationID: convID,
		ID:             msgID,
		ParentBlockID:  parentBlockID,
		Role:           role,
		Attrs:          attrs,
	})
	return msgID
}

// saveBlockRow writes a block_start row to message_blocks. The
// parent_block_id column is empty when the block is top-level under
// the message (parent==messageID); otherwise it carries parentID. Attrs
// JSON-marshalled. Best-effort: failures log + continue (Bridge already
// shipped the SSE event; DB miss only affects history replay).
//
// saveBlockRow 把 block_start 写到 message_blocks。block 直挂 message
// 顶层（parent==messageID）时 parent_block_id 列为空；否则填 parentID。
// Attrs JSON 化。Best-effort：失败 log + 继续（Bridge 已发 SSE 事件；DB
// 失误只影响历史回放）。
func (em *emitter) saveBlockRow(ctx context.Context, convID, id, parentID, messageID, blockType string, attrs map[string]any, seq int64) {
	if em.repo == nil || seq == 0 {
		return
	}
	parentBlock := ""
	if parentID != messageID {
		parentBlock = parentID
	}
	attrsJSON := ""
	if len(attrs) > 0 {
		if b, err := json.Marshal(attrs); err == nil {
			attrsJSON = string(b)
		}
	}
	now := time.Now().UTC()
	if err := em.repo.SaveBlock(ctx, &chatdomain.Block{
		ID:             id,
		ConversationID: convID,
		MessageID:      messageID,
		ParentBlockID:  parentBlock,
		Seq:            seq,
		Type:           blockType,
		Attrs:          attrsJSON,
		Status:         eventlogdomain.StatusStreaming,
		CreatedAt:      now,
		UpdatedAt:      now,
	}); err != nil {
		em.log.Warn("blockV2 dual-write failed (block_start)",
			zap.String("blockId", id), zap.Error(err))
	}
}

func (em *emitter) StopMessage(ctx context.Context, msgID, status, stopReason, errCode, errMsg string, inputTokens, outputTokens int) {
	convID, ok := em.requireConv(ctx, "StopMessage")
	if !ok {
		return
	}
	em.publish(ctx, convID, eventlogdomain.MessageStop{
		ConversationID: convID,
		ID:             msgID,
		Status:         status,
		StopReason:     stopReason,
		ErrorCode:      errCode,
		ErrorMessage:   errMsg,
		InputTokens:    inputTokens,
		OutputTokens:   outputTokens,
	})
	// No DB dual-write for messages — they persist via legacy chat repo
	// (Phase 4 cutover unifies). 不双写 messages — 走 legacy chat repo。
}

func (em *emitter) StartBlock(ctx context.Context, blockType string, attrs map[string]any) string {
	convID, ok := em.requireConv(ctx, "StartBlock")
	if !ok {
		return ""
	}
	parentID, _ := reqctxpkg.GetParentBlockID(ctx)
	if parentID == "" {
		// Fallback: parent is the in-flight assistant message.
		// Top-level blocks (text / reasoning / tool_call directly under
		// the assistant message) follow this path.
		//
		// 回退：父 = in-flight assistant message。
		// 顶层 block（直接挂 assistant message 下的 text / reasoning /
		// tool_call）走这条。
		parentID, _ = reqctxpkg.GetMessageID(ctx)
	}
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	if parentID == "" || msgID == "" {
		em.log.Warn("emit skipped: missing parent or message in ctx",
			zap.String("op", "StartBlock"),
			zap.String("blockType", blockType))
		return ""
	}
	blockID := idgenpkg.New("blk")
	seq, ok := em.publish(ctx, convID, eventlogdomain.BlockStart{
		ConversationID: convID,
		ID:             blockID,
		ParentID:       parentID,
		MessageID:      msgID,
		BlockType:      blockType,
		Attrs:          attrs,
	})
	if ok {
		em.saveBlockRow(ctx, convID, blockID, parentID, msgID, blockType, attrs, seq)
	}
	return blockID
}

func (em *emitter) StartBlockUnder(ctx context.Context, parentID, messageID, blockType string, attrs map[string]any) string {
	convID, ok := em.requireConv(ctx, "StartBlockUnder")
	if !ok {
		return ""
	}
	if parentID == "" || messageID == "" {
		em.log.Warn("emit skipped: empty parent or message",
			zap.String("op", "StartBlockUnder"))
		return ""
	}
	blockID := idgenpkg.New("blk")
	seq, ok := em.publish(ctx, convID, eventlogdomain.BlockStart{
		ConversationID: convID,
		ID:             blockID,
		ParentID:       parentID,
		MessageID:      messageID,
		BlockType:      blockType,
		Attrs:          attrs,
	})
	if ok {
		em.saveBlockRow(ctx, convID, blockID, parentID, messageID, blockType, attrs, seq)
	}
	return blockID
}

func (em *emitter) EmitMessageStart(ctx context.Context, id, role, parentBlockID string, attrs map[string]any) {
	convID, ok := em.requireConv(ctx, "EmitMessageStart")
	if !ok {
		return
	}
	if id == "" || role == "" {
		em.log.Warn("emit skipped: empty id or role",
			zap.String("op", "EmitMessageStart"))
		return
	}
	em.publish(ctx, convID, eventlogdomain.MessageStart{
		ConversationID: convID,
		ID:             id,
		ParentBlockID:  parentBlockID,
		Role:           role,
		Attrs:          attrs,
	})
}

func (em *emitter) EmitBlockStart(ctx context.Context, id, parentID, messageID, blockType string, attrs map[string]any) {
	convID, ok := em.requireConv(ctx, "EmitBlockStart")
	if !ok {
		return
	}
	if id == "" || parentID == "" || messageID == "" {
		em.log.Warn("emit skipped: empty id / parent / message",
			zap.String("op", "EmitBlockStart"),
			zap.String("blockType", blockType))
		return
	}
	seq, ok := em.publish(ctx, convID, eventlogdomain.BlockStart{
		ConversationID: convID,
		ID:             id,
		ParentID:       parentID,
		MessageID:      messageID,
		BlockType:      blockType,
		Attrs:          attrs,
	})
	if ok {
		em.saveBlockRow(ctx, convID, id, parentID, messageID, blockType, attrs, seq)
	}
}

func (em *emitter) DeltaBlock(ctx context.Context, blockID, delta string) {
	convID, ok := em.requireConv(ctx, "DeltaBlock")
	if !ok {
		return
	}
	if blockID == "" {
		return // upstream skipped (e.g. StartBlock returned "" due to missing ctx)
	}
	em.publish(ctx, convID, eventlogdomain.BlockDelta{
		ConversationID: convID,
		ID:             blockID,
		Delta:          delta,
	})
	// DB dual-write: append delta to content. Best-effort.
	// DB 双写：把 delta 追到 content。Best-effort。
	if em.repo != nil {
		if err := em.repo.AppendDelta(ctx, blockID, delta); err != nil {
			em.log.Warn("blockV2 dual-write failed (delta)",
				zap.String("blockId", blockID), zap.Error(err))
		}
	}
}

func (em *emitter) StopBlock(ctx context.Context, blockID, status string, err error) {
	convID, ok := em.requireConv(ctx, "StopBlock")
	if !ok {
		return
	}
	if blockID == "" {
		return
	}
	errStr := ""
	if err != nil {
		errStr = err.Error()
	}
	em.publish(ctx, convID, eventlogdomain.BlockStop{
		ConversationID: convID,
		ID:             blockID,
		Status:         status,
		Error:          errStr,
	})
	// DB dual-write: finalize status + error. Best-effort.
	// DB 双写：终态化 status + error。Best-effort。
	if em.repo != nil {
		if e := em.repo.FinalizeStop(ctx, blockID, status, errStr); e != nil {
			em.log.Warn("blockV2 dual-write failed (stop)",
				zap.String("blockId", blockID), zap.Error(e))
		}
	}
}

// ── ctx helpers ──────────────────────────────────────────────────────

type emitterKey struct{}

// With returns a copy of ctx carrying em. From recovers it.
//
// With 返回携带 em 的 ctx 拷贝。From 取回。
func With(ctx context.Context, em Emitter) context.Context {
	return context.WithValue(ctx, emitterKey{}, em)
}

// From returns the Emitter stored in ctx, or a no-op Emitter if absent.
// Returning a no-op (vs nil) lets callers always invoke methods without
// nil-checks; missing emitter logs a warning so wiring bugs surface.
//
// From 返 ctx 中的 Emitter，缺失则返 no-op。返 no-op（而非 nil）让调用方
// 无须 nil 检查；缺失时打 warning 让接线 bug 暴露。
func From(ctx context.Context) Emitter {
	em, ok := ctx.Value(emitterKey{}).(Emitter)
	if !ok || em == nil {
		return noopEmitter{}
	}
	return em
}

// MustFrom returns the Emitter stored in ctx, or panics. Use only at
// places where missing emitter is unambiguously a wiring bug.
//
// MustFrom 返 ctx 中的 Emitter，缺失 panic。仅用于"缺 emitter 必然是
// 接线 bug"的位置。
func MustFrom(ctx context.Context) Emitter {
	em, ok := ctx.Value(emitterKey{}).(Emitter)
	if !ok || em == nil {
		panic(fmt.Sprintf("eventlog.MustFrom: no emitter in ctx"))
	}
	return em
}

// WithParent narrows the parent for nested emits. Tool framework wraps
// Tool.Execute with WithParent(ctx, toolCallBlockID) so any block the
// tool starts is auto-parented under tool_call.
//
// WithParent 缩小嵌套 emit 的父级。Tool framework 用
// WithParent(ctx, toolCallBlockID) 包 Tool.Execute，让工具开的任何 block
// 自动挂 tool_call 下。
func WithParent(ctx context.Context, blockID string) context.Context {
	return reqctxpkg.WithParentBlockID(ctx, blockID)
}

// ── no-op fallback ───────────────────────────────────────────────────

type noopEmitter struct{}

func (noopEmitter) StartMessage(context.Context, string, string, map[string]any) string {
	return ""
}
func (noopEmitter) StopMessage(context.Context, string, string, string, string, string, int, int) {
}
func (noopEmitter) StartBlock(context.Context, string, map[string]any) string { return "" }
func (noopEmitter) StartBlockUnder(context.Context, string, string, string, map[string]any) string {
	return ""
}
func (noopEmitter) EmitMessageStart(context.Context, string, string, string, map[string]any) {}
func (noopEmitter) EmitBlockStart(context.Context, string, string, string, string, map[string]any) {
}
func (noopEmitter) DeltaBlock(context.Context, string, string)        {}
func (noopEmitter) StopBlock(context.Context, string, string, error)  {}
