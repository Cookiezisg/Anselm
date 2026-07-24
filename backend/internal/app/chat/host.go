package chat

import (
	"context"
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
	svc            *Service
	conversationID string
	assistantMsgID string                  // the in-flight assistant turn (streaming, finalized at end)
	assistantMsg   *messagesdomain.Message // mutated + persisted by WriteFinalize
	caps           ContentCapabilities     // the resolved model's content capabilities (attachment gating)
	summary        string                  // conversation.Summary — compacted older history, prepended
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
func (h *chatHost) Tools(ctx context.Context) []toolapp.Tool {
	ts := h.svc.deps.Toolset
	tools := make([]toolapp.Tool, 0, len(ts.Resident)+1+len(ts.Lazy))
	tools = append(tools, ts.Resident...)
	if h.svc.searchTool != nil {
		tools = append(tools, h.svc.searchTool)
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
	if h.svc.deps.Todo == nil {
		return nil
	}
	if text, ok := h.svc.deps.Todo.SystemReminder(ctx); ok {
		return []string{text}
	}
	return nil
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

	if err := h.svc.messages.FinalizeMessage(dctx, h.assistantMsg, blocks); err != nil {
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
