// Package installprogress wraps a sandbox install operation
// (EnsureRuntime / EnsureEnv / similar) with an eventlog progress
// block when the call originates inside a chat tool flow, and a
// no-op callback otherwise. Callers stay focused on the install
// itself; the eventlog plumbing is contained here so MCP install,
// Bash auto-route, future Forge env install, etc. all share one
// consistent rendering pattern instead of copy-pasting the
// StartBlock / DeltaBlock / StopBlock dance.
//
// Channel selection rule (matches Forgify event-log protocol):
//   - ctx carries conversationId AND parent block ID (i.e. inside
//     a chat tool_call) → emit progress block under that parent.
//     Frontend chat panel renders it nested under the tool item.
//   - ctx has no conversation context → callback is a no-op. The
//     caller can rely on synchronous HTTP blocking for non-chat
//     surfaces (testend / REST) — install progress streaming for
//     those uses goes via the global notifications channel as
//     entity-state snapshots, not via this helper.
//
// Notifications (e.g. sandbox_env entity state changes) are NOT
// emitted by this helper — every service publishes its own entity
// notifications independently per the project's "always publish on
// state change" rule. This helper only handles the in-conversation
// progress stream.
//
// Package installprogress 把 sandbox install 操作包成 chat 内 progress
// block 推送（仅当来自 chat tool flow 时）；非 chat 上下文下回调是
// no-op。统一 MCP install / Bash auto-route / 未来 Forge env install 等
// 触发点的渲染 pattern，避免每处 copy-paste 那段 StartBlock/DeltaBlock/
// StopBlock 板腔。
//
// 通道选择规则（对齐事件日志协议）：
//   - ctx 带 conversationId 与 parent block ID（即 chat tool_call 内）
//     → 在该 parent 下发 progress block，前端 chat 面板嵌套渲染。
//   - ctx 无对话上下文 → 回调 no-op；非 chat 来源（testend / REST）依赖
//     HTTP 同步阻塞，install 进度走全局 notifications 实体快照，不走这。
//
// notifications 不由本 helper 发——各 service 按"状态变化必发"规则各自发。
package installprogress

import (
	"context"
	"fmt"
	"strings"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Run wraps fn with a progress block when ctx is a chat-flow context.
// fn receives a sandbox.ProgressFunc to call as install progresses;
// each callback line is appended as a delta on the progress block.
// When fn returns, the block is closed with completed/error status
// reflecting err. When ctx is NOT a chat flow context, the callback
// is a no-op and no eventlog activity is emitted — fn still runs and
// its return value is forwarded as-is.
//
// fn errors propagate untouched. The block status is derived from
// err (StatusCompleted on nil, StatusError otherwise); the helper
// adds no error wrapping.
//
// Run 在 chat-flow ctx 下用 progress block 包 fn。fn 收到一个
// sandbox.ProgressFunc 用来汇报进度——每次回调作 delta 追加到 block。
// fn 返回时 block 按 err 关停（nil → completed，非 nil → error）。
// 非 chat-flow ctx 下回调 no-op、不发任何 eventlog 事件，fn 照跑。
//
// fn 的 err 原样返回；helper 不加 wrapping。
func Run[T any](
	ctx context.Context,
	attrs map[string]any,
	fn func(progress sandboxdomain.ProgressFunc) (T, error),
) (T, error) {
	progressCb := newProgressCallback(ctx, attrs)
	out, err := fn(progressCb.cb)
	progressCb.close(ctx, err)
	return out, err
}

// progressCallback holds the eventlog block ID (or empty string for
// non-chat-flow no-op) plus the emitter ref, so close() can finalize
// the block with the correct status.
//
// progressCallback 持 eventlog block ID（空表示非 chat-flow 下 no-op）+
// emitter 引用，让 close() 用正确 status 终结 block。
type progressCallback struct {
	em      eventlogpkg.Emitter
	blockID string
}

func newProgressCallback(ctx context.Context, attrs map[string]any) *progressCallback {
	if !inChatFlow(ctx) {
		return &progressCallback{}
	}
	em := eventlogpkg.From(ctx)
	if em == nil {
		return &progressCallback{}
	}
	blockID := em.StartBlock(ctx, eventlogdomain.BlockTypeProgress, attrs)
	return &progressCallback{em: em, blockID: blockID}
}

func (p *progressCallback) cb(stage, message string, percent int) {
	if p.blockID == "" {
		return // no-op when not in chat flow
	}
	// DeltaBlock signature: (ctx, blockID, delta). Use Background ctx
	// because progressCallback doesn't carry the original — emitter
	// only uses ctx for logging, not control.
	//
	// DeltaBlock 签名：(ctx, blockID, delta)。用 Background——
	// progressCallback 不持原 ctx，emitter 只用 ctx 做 log 不影响功能。
	p.em.DeltaBlock(context.Background(), p.blockID, formatProgressLine(stage, message, percent))
}

func (p *progressCallback) close(ctx context.Context, err error) {
	if p.blockID == "" {
		return
	}
	status := eventlogdomain.StatusCompleted
	if err != nil {
		status = eventlogdomain.StatusError
	}
	p.em.StopBlock(ctx, p.blockID, status, err)
}

// inChatFlow reports whether ctx carries both a conversationId AND a
// parent block (set by the chat runner when invoking a tool). Both
// are required: conversationId alone (e.g. on background autoTitle)
// doesn't justify a progress block — there's no parent tool_call to
// nest under.
//
// inChatFlow 报告 ctx 是否同时带 conversationId 和 parent block（chat
// runner 调工具前会塞）。两者都需要：仅有 conversationId（如后台
// autoTitle）不够——没有父 tool_call 可挂。
func inChatFlow(ctx context.Context) bool {
	if convID, ok := reqctxpkg.GetConversationID(ctx); !ok || convID == "" {
		return false
	}
	if parent, ok := reqctxpkg.GetParentBlockID(ctx); !ok || parent == "" {
		return false
	}
	return true
}

// formatProgressLine renders a sandbox.ProgressFunc invocation as a
// single text line for the eventlog progress block delta. Format:
// "[stage] message (NN%)\n" — pieces omitted when empty / negative.
//
// formatProgressLine 把 sandbox.ProgressFunc 的一次回调渲染成 progress
// block 的一行 delta。格式："[stage] message (NN%)\n"——为空 / 负值的
// 字段省略。
func formatProgressLine(stage, message string, percent int) string {
	var sb strings.Builder
	if stage != "" {
		sb.WriteString("[")
		sb.WriteString(stage)
		sb.WriteString("] ")
	}
	sb.WriteString(message)
	if percent >= 0 {
		fmt.Fprintf(&sb, " (%d%%)", percent)
	}
	sb.WriteString("\n")
	return sb.String()
}
