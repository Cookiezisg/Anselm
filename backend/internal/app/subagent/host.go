package subagent

import (
	"context"

	"go.uber.org/zap"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// subagentHost is one Spawn's loop.Host — a hybrid: like agentHost its history is just the task
// prompt and its tools are a fixed whitelist, but like chatHost its WriteFinalize persists the
// turn (a sub-message tagged SubagentID) and pushes message_stop, on a detached context. It does
// NOT implement AutoActivator / ReminderProvider / StepRecorder (static tools, no live todo, no
// durable replay).
//
// subagentHost 是一次 Spawn 的 loop.Host——混血：像 agentHost 其历史就是任务 prompt、工具是固定白
// 名单，但像 chatHost 其 WriteFinalize 落盘回合（带 SubagentID 的 sub-message）+ 推 message_stop、
// 在 detached context 上。不实现 AutoActivator / ReminderProvider / StepRecorder（静态工具、无 live
// todo、无持久重放）。
type subagentHost struct {
	svc            *Service
	conversationID string
	subMsg         *messagesdomain.Message // mutated + persisted by WriteFinalize
	userPrompt     string
	systemPrompt   string
	tools          []toolapp.Tool

	// Consumption chokepoint, tool_result half (WRK-082 批B'): renderer expands MediaRefs the
	// subagent's tools emit, caps gates by the resolved model's modalities. nil renderer → the
	// loop's type-assert still fires but expansion returns nothing (honest degrade).
	// 消费咽喉 tool_result 半(批B'):renderer 展开 subagent 工具产出的 MediaRef,caps 按解析模型
	// 模态门控。renderer nil → loop 断言仍中但展开返空(诚实降级)。
	renderer AttachmentRenderer
	caps     attachmentapp.Capabilities
}

var _ loopapp.Host = (*subagentHost)(nil)
var _ loopapp.MediaExpander = (*subagentHost)(nil)

// LoadHistory seeds the loop with just the task prompt (an isolated run — no parent thread).
//
// LoadHistory 只用任务 prompt 起始（隔离运行——无父线程）。
func (h *subagentHost) LoadHistory(_ context.Context) ([]llminfra.LLMMessage, error) {
	return []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: h.userPrompt}}, nil
}

// Tools returns the type-filtered static whitelist (no lazy / search_tools dance — a subagent is
// focused and short-lived).
//
// Tools 返回按类型过滤的静态白名单（无 lazy / search_tools 周旋——subagent 聚焦短命）。
func (h *subagentHost) Tools(_ context.Context) []toolapp.Tool { return h.tools }

// ExpandToolMedia implements loop.MediaExpander (WRK-082 批B' 消费咽喉·tool_result 半) — same
// contract as chatHost: MediaRef receipts in tool results render into native parts so the
// subagent's model sees the media its tools just produced, gated by its resolved model's caps.
//
// ExpandToolMedia 实现 loop.MediaExpander(批B' 消费咽喉·tool_result 半)——与 chatHost 同契约:
// tool result 里的 MediaRef receipt 渲成原生 part,subagent 的模型当轮看见工具刚产的媒体,按其
// 解析模型的能力门控。
func (h *subagentHost) ExpandToolMedia(ctx context.Context, ids []string) []llminfra.ContentPart {
	if h.renderer == nil || len(ids) == 0 {
		return nil
	}
	parts, err := h.renderer.ToolResultContentParts(ctx, ids, h.caps)
	if err != nil {
		h.svc.log.Warn("subagent: tool media expansion failed (textual receipts kept)", zap.Error(err))
		return nil
	}
	return parts
}

// WriteFinalize lands the subagent's turn as a sub-message (SubagentID already set) with its
// blocks, and pushes message_stop. Detached (background + re-seeded workspace/conversation) for
// the same orphan-avoidance reason as chat: a cancelled subagent must still reach a terminal
// state. The final answer (result.LastMessage) is returned by Spawn and becomes the spawning
// tool_call's tool_result — that, not this sub-message, is what the parent's LLM sees.
//
// WriteFinalize 把 subagent 回合作为 sub-message（SubagentID 已设）连同 blocks 落盘、推 message_stop。
// detached（background + 重埋 workspace/conversation），与 chat 同样防孤儿：被取消的 subagent 仍须
// 抵达终态。最终答案（result.LastMessage）由 Spawn 返回、成为派它的 tool_call 的 tool_result——父的
// LLM 看的是那个、而非这条 sub-message。
func (h *subagentHost) WriteFinalize(ctx context.Context, blocks []messagesdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	wsID, _ := reqctxpkg.GetWorkspaceID(ctx)
	dctx := reqctxpkg.Detached(wsID)
	dctx = reqctxpkg.SetConversationID(dctx, h.conversationID)

	h.subMsg.Status = status
	h.subMsg.StopReason = stopReason
	h.subMsg.ErrorCode = errCode
	h.subMsg.ErrorMessage = errMsg
	h.subMsg.InputTokens = in
	h.subMsg.OutputTokens = out

	if err := h.svc.deps.Messages.FinalizeMessage(dctx, h.subMsg, blocks); err != nil {
		h.svc.log.Warn("subagentapp.WriteFinalize: persist failed",
			zap.String("subMessageId", h.subMsg.ID), zap.Error(err))
	}
	h.svc.notifySearchMessage(dctx, h.conversationID, h.subMsg.ID)
	h.svc.emitMessageStop(dctx, h.conversationID, h.subMsg)
}
