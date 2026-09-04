package chat

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	modelprofiledomain "github.com/sunweilin/anselm/backend/internal/domain/modelprofile"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// chatHost is one generation's loop.Host: it loads the conversation history (history.go),
// supplies the per-step tool set, and persists + streams the terminal turn. It is the persisting
// counterpart of agentHost — same three-method shape, but WriteFinalize lands blocks in
// message_blocks and pushes message_stop (vs agent's no-op), and Tools returns resident +
// per-conversation discovered-lazy (vs agent's static whitelist). It also implements the optional
// AutoActivator (lazy-tool activation) and ReminderProvider (live todo list); it does NOT
// implement StepRecorder (durable replay is a workflow-agent concern).
//
// chatHost 是一次生成的 loop.Host：加载对话历史（history.go）、供每步工具集、落盘 + 推流终态回合。
// 它是 agentHost 的持久化对应物——同三方法形状，但 WriteFinalize 把 block 落 message_blocks 并推
// message_stop（vs agent 的 no-op），Tools 返回 resident + per-conversation discovered-lazy（vs
// agent 的静态白名单）。它还实现可选 AutoActivator（lazy 工具激活）与 ReminderProvider（live todo
// 清单）；**不**实现 StepRecorder（持久重放是 workflow-agent 的事）。
type chatHost struct {
	svc              *Service
	conversationID   string
	assistantMsgID   string                  // the in-flight assistant turn (streaming, finalized at end)
	assistantMsg     *messagesdomain.Message // mutated + persisted by WriteFinalize
	recordedBlockIDs map[string]struct{}     // blocks already appended before the terminal finalize
	caps             ContentCapabilities     // the resolved model's content capabilities (attachment gating)
	summary          string                  // conversation.Summary — compacted older history, prepended
	// summaryCoversUpToSeq is the compaction watermark: blocks with seq ≤ it are folded into
	// summary and dropped from LLM history. The source of truth (crash-safe: contextmgr writes
	// the summary+watermark before the archived flag, so a crash can't double-count).
	//
	// summaryCoversUpToSeq 是压缩水位线：seq ≤ 它的 block 已并入 summary、从 LLM 历史丢弃。真相源
	// （崩溃安全：contextmgr 先写 summary+水位再写 archived 标记，崩溃不会重复计数）。
	summaryCoversUpToSeq int64
	// runtimeProfile identifies an external route without prompt/key material.
	// Its RequestClass is filled per concrete rendered request.
	runtimeProfile modelprofiledomain.Identity

	// attachedDocIDs are the attachment ids referenced by the conversation's ATTACHED DOCUMENTS
	// (WRK-082 批F). A document reaches the model as text in the system prompt, and a system prompt
	// has no content parts — so a chart inside an @-mentioned document would arrive as the literal
	// string `![chart](anselm://media/att_…)` and the model would never see a pixel. These ids ride
	// to LoadHistory, which expands them onto the turn being answered.
	//
	// attachedDocIDs 是对话**附件文档**里引用的附件 id(批F)。文档以**文本**进 system prompt,而
	// system prompt 没有 content part——故一份 @ 进来的文档里的图表,到达模型时会是字面字符串
	// `![chart](anselm://media/att_…)`,模型一个像素也看不到。这些 id 传到 LoadHistory,由它展开到
	// **正在被回答的**那一轮上。
	attachedDocIDs          []string
	mediaSlots              []mediaHistorySlot
	audioEnrollmentReminder string
}

// Interface assertions: a compile error fires if chatHost drifts from the loop hook surface.
//
// 接口断言：chatHost 若偏离 loop 钩子面则编译失败。
var (
	_ loopapp.Host                  = (*chatHost)(nil)
	_ loopapp.AutoActivator         = (*chatHost)(nil)
	_ loopapp.ReminderProvider      = (*chatHost)(nil)
	_ loopapp.PromptCompactor       = (*chatHost)(nil)
	_ loopapp.ContextObserver       = (*chatHost)(nil)
	_ loopapp.RuntimeBudgetResolver = (*chatHost)(nil)
	_ loopapp.BlockRecorder         = (*chatHost)(nil)
	_ loopapp.MediaHistoryRefresher = (*chatHost)(nil)
)

// RuntimeInputBudget asks the learned-profile service for the exact rendered
// route. It is a soft proactive-edit trigger only; errors/unknowns leave the
// loop ungoverned until a real provider overflow teaches it otherwise.
func (h *chatHost) RuntimeInputBudget(ctx context.Context, route string) int {
	if h.svc.deps.RuntimeProfiles == nil {
		return 0
	}
	identity := h.runtimeIdentity(route)
	budget, ok, err := h.svc.deps.RuntimeProfiles.Budget(ctx, identity)
	if err != nil {
		h.svc.log.Warn("runtime model profile lookup failed", zap.Error(err))
		return 0
	}
	if !ok {
		return 0
	}
	return budget
}

// RefreshHistoryMedia re-renders the persisted user attachment turns in place. ReAct history is
// intentionally kept in memory between steps, so calling LoadHistory again would lose the live
// assistant/tool suffix. The slots captured by LoadHistory let us refresh only the durable user
// media while preserving that suffix and any in-turn media follow-up messages.
//
// RefreshHistoryMedia 原地重渲染持久 user 附件回合。ReAct 步之间历史刻意留在内存，重新调用 LoadHistory
// 会丢掉正在进行的 assistant/tool 后缀；LoadHistory 记录的 slot 让我们只刷新持久 user 媒体，同时保住
// 后缀及本回合的媒体 follow-up 消息。
func (h *chatHost) RefreshHistoryMedia(ctx context.Context, history []llminfra.LLMMessage) error {
	for _, slot := range h.mediaSlots {
		if slot.index < 0 || slot.index >= len(history) || history[slot.index].Role != llminfra.RoleUser {
			continue
		}
		if slot.anchor != historyText(history[slot.index]) {
			// Prompt compaction may have removed or reshaped this old user turn. It no longer carries
			// the lease that needs refreshing, so leave the compacted projection untouched.
			continue
		}
		if slot.message != nil {
			rendered, err := h.userMessage(ctx, slot.message)
			if err != nil {
				return fmt.Errorf("refresh user attachment media: %w", err)
			}
			history[slot.index] = rendered
		} else if slot.baseParts <= len(history[slot.index].Parts) {
			history[slot.index].Parts = append([]llminfra.ContentPart(nil), history[slot.index].Parts[:slot.baseParts]...)
		}
		if slot.attachedDocs {
			history[slot.index].Parts = append(history[slot.index].Parts, h.attachedDocParts(ctx)...)
		}
	}
	return nil
}

// CompactPrompt delegates semantic in-turn checkpointing to contextmgr when
// wired. Returning the original projection lets loop's deterministic emergency
// fallback take over in deployments without a semantic compactor.
func (h *chatHost) CompactPrompt(ctx context.Context, history []llminfra.LLMMessage, targetTokens int) ([]llminfra.LLMMessage, error) {
	compactor, ok := h.svc.deps.Compactor.(interface {
		CompactPrompt(context.Context, []llminfra.LLMMessage, int) ([]llminfra.LLMMessage, error)
	})
	if !ok {
		return history, nil
	}
	return compactor.CompactPrompt(ctx, history, targetTokens)
}

// ObserveContext stores per-sampling context facts separately from the
// assistant turn's aggregate token charge. No prompt content is retained.
func (h *chatHost) ObserveContext(ctx context.Context, o loopapp.ContextObservation) {
	if h.assistantMsg.Attrs == nil {
		h.assistantMsg.Attrs = make(map[string]any)
	}
	stats, _ := h.assistantMsg.Attrs["contextUsage"].(map[string]any)
	if stats == nil {
		stats = make(map[string]any)
	}
	if o.ActualInput > 0 {
		stats["lastPromptInputTokens"] = o.ActualInput
	}
	stats["inputBudgetTokens"] = o.InputBudget
	stats["predictedInputTokens"] = o.PredictedInput
	stats["route"] = o.Route
	stats["requestBytes"] = o.RequestBytes
	stats["systemBytes"] = o.SystemBytes
	stats["toolSchemaBytes"] = o.ToolSchemaBytes
	stats["historyBytes"] = o.HistoryBytes
	if o.Compacted {
		stats["compactions"] = intValue(stats["compactions"]) + 1
		stats["lastCompactionMode"] = o.CompactionMode
	}
	if o.ClearedToolBytes > 0 {
		stats["toolResultEdits"] = intValue(stats["toolResultEdits"]) + 1
	}
	if o.Recovery {
		stats["recoveries"] = intValue(stats["recoveries"]) + 1
	}
	if o.ContextOverflow {
		stats["contextOverflows"] = intValue(stats["contextOverflows"]) + 1
		stats["lastOverflowPredictedInputTokens"] = o.PredictedInput
		stats["lastOverflowRequestBytes"] = o.RequestBytes
	}
	h.assistantMsg.Attrs["contextUsage"] = stats

	if h.svc.deps.RuntimeProfiles == nil || (!o.Succeeded && !o.ContextOverflow) {
		return
	}
	kind := modelprofiledomain.ObservationSuccess
	if o.ContextOverflow {
		kind = modelprofiledomain.ObservationContextOverflow
	}
	// Runtime evidence is a best-effort durable learning write, not part of the
	// user-visible stream transaction. Preserve the workspace isolation while
	// letting a user cancel/timeout after the upstream response without losing a
	// verified overflow→recovery pair.
	observeCtx := ctx
	if workspaceID, ok := reqctxpkg.GetWorkspaceID(ctx); ok {
		observeCtx = reqctxpkg.Detached(workspaceID)
	}
	if err := h.svc.deps.RuntimeProfiles.Observe(observeCtx, modelprofiledomain.Observation{
		Identity:             h.runtimeIdentity(o.Route),
		Kind:                 kind,
		PredictedInputTokens: o.PredictedInput,
		ActualInputTokens:    o.ActualInput,
		RequestBytes:         o.RequestBytes,
		Recovery:             o.Recovery,
	}); err != nil {
		h.svc.log.Warn("runtime model profile observation failed", zap.Error(err))
	}
}

func (h *chatHost) runtimeIdentity(route string) modelprofiledomain.Identity {
	identity := h.runtimeProfile
	switch route {
	case "text":
		identity.RequestClass = modelprofiledomain.RequestClassText
	case "multimodal":
		identity.RequestClass = modelprofiledomain.RequestClassMultimodal
	default:
		identity.RequestClass = ""
	}
	return identity
}

func intValue(v any) int {
	switch n := v.(type) {
	case int:
		return n
	case float64:
		return int(n)
	default:
		return 0
	}
}

// Tools recomputes the offered set every step (loop contract): always the resident tools +
// search_tools, plus the lazy tools this conversation has already discovered (via search_tools,
// recorded in AgentState). search_tools activates a lazy tool; its full schema then appears in
// this next tools list while the overview of inactive tools stays compact in the system prompt.
//
// Tools 每步重算 offer 集（loop 契约）：永远是 resident 工具 + search_tools，加上本对话已 discovered
// 的 lazy 工具（经 search_tools、记在 AgentState）。search_tools 激活 lazy 工具，其完整 schema
// 随下一请求 tools 列表出现；未激活工具只在 system prompt 留紧凑概览。
// ExpandToolMedia implements loop.MediaExpander (WRK-082 批B' 消费咽喉·tool_result 半): tool
// results carrying MediaRef receipts render into native parts for this conversation's model —
// the model sees the image it just generated (or an MCP tool just returned) within the same turn.
// Renderer absent or model modality-incapable → nil (the textual receipt stays, honest degrade).
//
// ExpandToolMedia 实现 loop.MediaExpander(批B' 消费咽喉·tool_result 半):带 MediaRef receipt 的
// 工具结果渲成本对话模型的原生 part——模型**同一回合**看见自己刚生成(或 MCP 刚返回)的图。
// 渲染器缺席或模型模态不支持 → nil(文本 receipt 仍在,诚实降级)。
func (h *chatHost) ExpandToolMedia(ctx context.Context, toolCallID string, ids []string) []llminfra.ContentPart {
	if h.svc.deps.Attachments == nil || len(ids) == 0 {
		return nil
	}
	parts, err := h.svc.deps.Attachments.ToolResultContentParts(ctx, toolCallID, ids, h.caps)
	if err != nil {
		h.svc.log.Warn("chat: tool media expansion failed (textual receipts kept)", zap.Error(err))
		return nil
	}
	return parts
}

func (h *chatHost) Tools(ctx context.Context) []toolapp.Tool {
	// A model.dev/model-catalog row with tools:false is a usable chat model, but its upstream rejects
	// any tools array (Qwen qwen-mt-plus is the real example). Keep the chat route textual instead of
	// sending a request guaranteed to fail. Unknown/custom models remain best-effort and keep tools.
	// 目录 tools:false 的模型仍可聊天、但上游会拒绝任何 tools 数组（真实例子是 Qwen qwen-mt-plus）。
	// chat 路线改为纯文本，避免发送注定失败的请求；未知/custom 模型仍保留 best-effort 工具。
	if h.caps.ToolsKnown && !h.caps.Tools {
		return nil
	}
	ts := h.svc.deps.Toolset
	tools := make([]toolapp.Tool, 0, len(ts.Resident)+1+len(ts.Lazy))
	tools = append(tools, ts.Resident...)
	if h.svc.searchTool != nil {
		tools = append(tools, h.svc.searchTool)
	}
	// Capability tools are per-request residents: availability-filtered upstream, full schema here.
	// 能力工具是逐请求 resident:上游已按可用性过滤,此处直接携完整 schema。
	if h.svc.deps.CapabilityTools != nil {
		tools = append(tools, h.svc.deps.CapabilityTools(ctx)...)
	}
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		for _, t := range ts.Lazy {
			if state.IsToolDiscovered(t.Name()) {
				tools = append(tools, t)
			}
		}
		// Per-workspace MCP dynamic tools discovered this conversation are offered too (F52) — they
		// aren't in the static Toolset, so they ride the same discovered-via-search_tools contract.
		// 本对话已 discovered 的 per-workspace MCP 动态工具也 offer（F52）——不在静态 Toolset，走同款契约。
		if h.svc.deps.DynamicTools != nil {
			for _, t := range h.svc.deps.DynamicTools(ctx) {
				if state.IsToolDiscovered(t.Name()) {
					tools = append(tools, t)
				}
			}
		}
	}
	return tools
}

// TryActivateForTool (loop.AutoActivator) lets the LLM call a lazy tool it named without first
// running search_tools: if the name is a lazy tool, mark it discovered and rebuild the set.
// Returns nil when the tool is in no lazy group (loop then dispatches it as a normal miss).
//
// TryActivateForTool（loop.AutoActivator）让 LLM 直接调它点名的 lazy 工具而无需先跑 search_tools：
// 若该名是 lazy 工具，标记 discovered 并重建集合。工具不在任何 lazy 组时返回 nil（loop 按普通 miss 处理）。
func (h *chatHost) TryActivateForTool(ctx context.Context, name string) []toolapp.Tool {
	known := h.svc.deps.Toolset.FindLazy(name) != nil
	if !known && h.svc.deps.DynamicTools != nil {
		// Maybe a per-workspace MCP dynamic tool (mcp__server__tool), not in the static Toolset (F52).
		for _, t := range h.svc.deps.DynamicTools(ctx) {
			if t.Name() == name {
				known = true
				break
			}
		}
	}
	if !known {
		return nil
	}
	state, ok := reqctxpkg.GetAgentState(ctx)
	if !ok {
		return nil
	}
	state.MarkToolDiscovered(name)
	return h.Tools(ctx)
}

// SystemReminders (loop.ReminderProvider) injects the live todo list ahead of each step as a
// transient <system-reminder> — keeping the model's checklist in front of it without polluting
// persisted history. Empty when no todo service is wired or the list is empty.
//
// SystemReminders（loop.ReminderProvider）每步前把 live todo 清单作为临时 <system-reminder> 注入
// ——把清单顶在模型眼前、又不污染持久历史。无 todo 服务或清单空时为空。
func (h *chatHost) SystemReminders(ctx context.Context) []string {
	var reminders []string
	if h.audioEnrollmentReminder != "" {
		reminders = append(reminders, h.audioEnrollmentReminder)
	}
	if h.svc.deps.Todo != nil {
		if text, ok := h.svc.deps.Todo.SystemReminder(ctx); ok {
			reminders = append(reminders, text)
		}
	}
	return reminders
}

// WriteFinalize lands the assistant turn: it updates the message's terminal fields, persists it
// with its blocks (seq-allocated), and pushes message_stop. It runs on a DETACHED context
// (background + re-seeded workspace/conversation) so an upstream cancel — the user closing the tab
// mid-generation — can never leave a permanent streaming orphan; the turn always reaches a
// terminal state. Provider / ModelID were set on the message before loop.Run (provenance).
//
// WriteFinalize 落 assistant 回合：更新 message 终态字段、连同 blocks（分配 seq）落盘、推
// message_stop。它在 DETACHED context（background + 重新埋 workspace/conversation）上跑，故上游
// cancel——用户在生成中关页——绝不会留永久 streaming 孤儿；回合总抵达终态。Provider / ModelID 在
// loop.Run 前已设在 message 上（溯源）。
func (h *chatHost) WriteFinalize(ctx context.Context, blocks []messagesdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	wsID, _ := reqctxpkg.GetWorkspaceID(ctx)
	dctx := reqctxpkg.Detached(wsID)
	dctx = reqctxpkg.SetConversationID(dctx, h.conversationID)

	h.assistantMsg.Status = status
	h.assistantMsg.StopReason = stopReason
	h.assistantMsg.ErrorCode = errCode
	h.assistantMsg.ErrorMessage = errMsg
	h.assistantMsg.InputTokens = in
	h.assistantMsg.OutputTokens = out

	remaining := make([]messagesdomain.Block, 0, len(blocks))
	for _, block := range blocks {
		if _, recorded := h.recordedBlockIDs[block.ID]; recorded && block.ID != "" {
			continue
		}
		remaining = append(remaining, block)
	}
	if err := h.svc.messages.FinalizeMessage(dctx, h.assistantMsg, remaining); err != nil {
		h.svc.log.Warn("chatapp.WriteFinalize: persist failed (turn lost from history)",
			zap.String("messageId", h.assistantMsgID), zap.Error(err))
	}
	h.svc.notifySearchMessage(dctx, h.conversationID, h.assistantMsg.ID)
	h.svc.emitMessageStop(dctx, h.conversationID, h.assistantMsg)
	// Bump recency + flag unread. unread = true ONLY for a COMPLETED reply: a cancelled / errored
	// terminal is not "a reply to read", and the user just cancelled it — so it stays seen (this is also
	// why the queued-cancel path, which never calls TouchLastMessage, leaves unread alone). Best-effort:
	// a failed touch only mis-sorts / mis-flags the list, it must never disturb the already-persisted turn.
	// 刷新 recency + 标记未读。unread=true 仅对**完成**的回复：取消/出错的终态不是「待读的回复」、且用户刚取消了它——
	// 故保持已读（这也是为何 queued-cancel 路径不调 TouchLastMessage、不动 unread）。best-effort：touch 失败只是排序/标志略偏。
	if err := h.svc.deps.Conversations.TouchLastMessage(dctx, h.conversationID, time.Now().UTC(), status == messagesdomain.StatusCompleted); err != nil {
		h.svc.log.Warn("chatapp.WriteFinalize: touch last_message failed", zap.String("conversation", h.conversationID), zap.Error(err))
	}
}

// RecordBlocks appends one LLM sampling boundary while the assistant turn is still streaming. The
// concrete messages store exposes this as an optional capability so lightweight chat fakes keep
// finalize-only behavior. A successful append mutates blocks in place with their durable id/seq;
// loop deliberately appends the slice to its final history only after this hook returns, so the
// finalizer can filter exactly these rows and never insert them twice.
//
// RecordBlocks 在 assistant 仍 streaming 时增量追加一次 LLM sampling 边界。具体 messages store 以可选
// capability 提供它，使轻量 chat fake 仍保持只在 finalize 落盘。成功追加会原地回填 durable id/seq；
// loop 刻意等此 hook 返回后才把切片并入最终 history，故 finalize 能精确滤掉这些行、绝不重复插入。
func (h *chatHost) RecordBlocks(ctx context.Context, blocks []messagesdomain.Block) error {
	if len(blocks) == 0 {
		return nil
	}
	appender, ok := h.svc.messages.(interface {
		AppendBlocks(context.Context, *messagesdomain.Message, []messagesdomain.Block) error
	})
	if !ok {
		return nil
	}
	if h.recordedBlockIDs == nil {
		h.recordedBlockIDs = make(map[string]struct{})
	}
	pending := make([]messagesdomain.Block, 0, len(blocks))
	for _, block := range blocks {
		if block.ID != "" {
			if _, recorded := h.recordedBlockIDs[block.ID]; recorded {
				continue
			}
		}
		pending = append(pending, block)
	}
	if len(pending) == 0 {
		return nil
	}
	// The loop invokes this hook after a provider deadline/cancel so the finalizer can still
	// preserve the last visible sampling boundary. Reuse the same detached workspace discipline
	// as WriteFinalize; passing the dead turn context here turns an expected recovery write into a
	// WARN and loses the block even though the assistant row is still finalized successfully.
	//
	// loop 可能在 provider deadline/cancel 后调用此 hook，使终态仍保留最后一段可见 sampling 边界。
	// 这里沿用 WriteFinalize 的 detached workspace 纪律；把已死的 turn context 传进来会把本应成功的
	// 恢复写变成 WARN，并在 assistant 仍能正常终态时丢掉该 block。
	appendCtx := ctx
	if ctx.Err() != nil {
		if workspaceID, ok := reqctxpkg.GetWorkspaceID(ctx); ok {
			appendCtx = reqctxpkg.Detached(workspaceID)
			appendCtx = reqctxpkg.SetConversationID(appendCtx, h.conversationID)
		}
	}
	if err := appender.AppendBlocks(appendCtx, h.assistantMsg, pending); err != nil {
		return err
	}
	// Copy the store-assigned values back to the caller's slice. Text/reasoning blocks do not have
	// an id until insertBlocks assigns one; matching by position is safe because pending preserves
	// the original order and no other writer can touch this conversation queue.
	p := 0
	for i := range blocks {
		if blocks[i].ID != "" {
			if _, recorded := h.recordedBlockIDs[blocks[i].ID]; recorded {
				continue
			}
		}
		blocks[i] = pending[p]
		if blocks[i].ID != "" {
			h.recordedBlockIDs[blocks[i].ID] = struct{}{}
		}
		p++
	}
	return nil
}
