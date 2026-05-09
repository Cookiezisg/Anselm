// runner.go — Queue management, processTask, and the per-turn handoff to
// loop.Run. The ReAct mechanics (stream / tool dispatch / history extension /
// finalize cadence) live in internal/app/loop. This file owns chat-specific
// concerns: queueing, model resolution, system prompt, autoTitle.
//
// runner.go — 队列管理、processTask 与每回合交付给 loop.Run 的入口。ReAct
// 机制（流 / 工具调度 / 历史扩展 / 终态节奏）在 internal/app/loop。本文件
// 只持 chat 专属：队列、模型解析、system prompt、autoTitle。
package chat

import (
	"context"
	"errors"
	"strings"
	"time"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// maxSteps caps the ReAct loop to prevent runaway tool-calling cycles.
// maxSteps 限制 ReAct 循环次数，防止工具调用无限循环。
const maxSteps = 20

// ── Queue / worker ────────────────────────────────────────────────────────────

func (s *Service) getOrCreateQueue(conversationID string) *convQueue {
	q := &convQueue{
		ch:         make(chan queuedTask, queueCapacity),
		agentState: &agentstatepkg.AgentState{},
	}
	actual, loaded := s.queues.LoadOrStore(conversationID, q)
	if loaded {
		return actual.(*convQueue)
	}
	go s.runQueue(conversationID, q)
	return q
}

func (s *Service) runQueue(conversationID string, q *convQueue) {
	const idleTimeout = 5 * time.Minute
	timer := time.NewTimer(idleTimeout)
	defer func() {
		timer.Stop()
		s.queues.Delete(conversationID)
	}()
	for {
		select {
		case task := <-q.ch:
			if !timer.Stop() {
				select {
				case <-timer.C:
				default:
				}
			}
			s.processTask(conversationID, q, task)
			timer.Reset(idleTimeout)
		case <-timer.C:
			return
		}
	}
}

// ── processTask ───────────────────────────────────────────────────────────────

func (s *Service) processTask(conversationID string, q *convQueue, task queuedTask) {
	ctx := task.ctx

	agentCtx, cancel := context.WithCancel(ctx)
	q.mu.Lock()
	q.cancel = cancel
	q.mu.Unlock()
	defer func() {
		cancel()
		q.mu.Lock()
		q.cancel = nil
		q.mu.Unlock()
	}()
	agentCtx = reqctxpkg.WithConversationID(agentCtx, conversationID)
	agentCtx = reqctxpkg.WithAgentState(agentCtx, q.agentState)
	agentCtx = eventlogpkg.With(agentCtx, s.emitter)

	// Allocate the assistant msgID up front so pre-LLM errors emit a stub
	// assistant Message — every chat.message event must carry a real Message.
	//
	// 预分配 assistant msgID，让 LLM 调用前的错误也能以 stub 消息发出
	// （chat.message 必须承载真实 Message）。
	msgID := newMsgID()
	agentCtx = reqctxpkg.WithMessageID(agentCtx, msgID)

	// Event-log: open the assistant message slot on the new bridge so
	// streamLLM-emitted block_start events have a valid parent. Top-level
	// assistant message (parent_block_id="").
	//
	// 事件日志：在新 bridge 上开 assistant message 槽，让 streamLLM 推的
	// block_start 有合法 parent。顶层 assistant message（parent_block_id=""）。
	s.emitter.EmitMessageStart(agentCtx, msgID, chatdomain.RoleAssistant, "", nil)

	bc, err := llmclientpkg.Resolve(agentCtx, s.modelPicker, s.keyProvider, s.llmFactory)
	if err != nil {
		code := "LLM_PROVIDER_ERROR"
		switch {
		case errors.Is(err, llmclientpkg.ErrPickModel):
			code = "MODEL_NOT_CONFIGURED"
		case errors.Is(err, llmclientpkg.ErrResolveCreds):
			code = "API_KEY_PROVIDER_NOT_FOUND"
		}
		s.emitFatalError(agentCtx, task.conv, task.uid, msgID, code, err.Error())
		return
	}

	baseReq := llminfra.Request{
		ModelID: bc.ModelID,
		Key:     bc.Key,
		BaseURL: bc.BaseURL,
		System:  s.buildSystemPrompt(agentCtx, task.conv),
		// loop.Run fills baseReq.Tools from host.Tools().
	}

	host := &chatHost{
		svc:       s,
		convID:    task.conv.ID,
		uid:       task.uid,
		msgID:     msgID,
		userMsgID: task.userMsgID,
	}
	result := loopapp.Run(agentCtx, host, bc.Client, baseReq, maxSteps, s.log)

	s.log.Info("agent run complete",
		zap.String("conversation_id", task.conv.ID),
		zap.String("stop_reason", result.StopReason),
		zap.Int("input_tokens", result.TokensIn),
		zap.Int("output_tokens", result.TokensOut))

	if task.conv.Title == "" && !task.conv.AutoTitled {
		go s.autoTitle(context.Background(), task.conv, task.uid, result.LastMessage)
	}
}

// emitFatalError persists a stub assistant message with status=error and
// publishes its chat.message snapshot. Used for failures before the LLM
// stream begins (model not configured, key resolution failed).
//
// emitFatalError 落库 status=error 的 stub assistant 消息并推快照。供 LLM
// 流开始前的失败使用（模型未配置、key 解析失败）。
func (s *Service) emitFatalError(
	ctx context.Context,
	conv *convdomain.Conversation,
	uid, msgID, code, message string,
) {
	s.log.Error("chat fatal error",
		zap.String("conversation_id", conv.ID),
		zap.String("code", code), zap.String("message", message))

	saveCtx := reqctxpkg.SetUserID(context.Background(), uid)
	msg := buildMessage(msgID, conv.ID, uid,
		chatdomain.StatusError, chatdomain.StopReasonError,
		code, message, 0, 0)
	if err := s.repo.SaveMessage(saveCtx, msg); err != nil {
		s.log.Error("CRITICAL: fatal-error stub message persist failed — message lost",
			zap.String("msg_id", msgID), zap.Error(err))
	}

	// Event-log: close the assistant message with error. Use saveCtx
	// (detached) instead of caller's ctx so a tab-close / stream-cancel
	// race between Resolve failure and StopMessage emit doesn't leave
	// the UI hung on a streaming bubble — same §S9 reasoning as the
	// SaveMessage above and host.go::WriteFinalize::StopMessage.
	//
	// 事件日志：用 saveCtx（detached）关 assistant message——caller ctx
	// 在 Resolve 失败到 StopMessage 之间被 cancel（关 tab / 中止流）会让
	// UI 的流式 bubble 永远不到 stop 事件挂死。同 §S9 上面的 SaveMessage
	// 与 host.go::WriteFinalize::StopMessage 模式。
	s.emitter.StopMessage(saveCtx, msgID, eventlogdomain.StatusError,
		chatdomain.StopReasonError, code, message, 0, 0)
}

// ── System prompt & helpers ───────────────────────────────────────────────────

func (s *Service) buildSystemPrompt(ctx context.Context, conv *convdomain.Conversation) string {
	var sb strings.Builder
	sb.WriteString("You are Forgify, an AI assistant that helps users build tools, automate workflows, and work with data.")
	if conv.SystemPrompt != "" {
		sb.WriteString("\n\n")
		sb.WriteString(conv.SystemPrompt)
	}
	// Capability Catalog block (D8): teaches the LLM what categories of
	// capabilities exist + when to prefer one over another. Skipped
	// silently when no provider is wired (unit tests / no-LLM-key envs)
	// or when the provider returns an empty string (boot window before
	// the first Refresh tick completes).
	//
	// Capability Catalog 段（D8）：教 LLM 有哪些类目能力 + 何时优先何者。
	// 无 provider（单测 / 无 LLM key）或返空（首 Refresh 完成前 boot 窗
	// 口）静默跳。
	if s.catalog != nil {
		if catalogText := s.catalog.GetForSystemPrompt(); catalogText != "" {
			sb.WriteString("\n\n")
			sb.WriteString(catalogText)
		}
	}
	if reqctxpkg.GetLocale(ctx) == reqctxpkg.LocaleZhCN {
		sb.WriteString("\n\nPlease respond in Chinese (Simplified) unless the user writes in another language.")
	}
	return sb.String()
}

// autoTitle picks a short title via LLM, persists, and publishes a
// `conversation` notification (entity snapshot) so all open UI windows
// see the new name. Best-effort: any failure aborts silently.
//
// autoTitle 通过 LLM 取一个短标题，持久化后发 `conversation` 通知
// （entity snapshot）让所有打开的 UI 窗口看到新名字。Best-effort：失败
// 静默退出。
func (s *Service) autoTitle(ctx context.Context, conv *convdomain.Conversation, uid, assistantContent string) {
	titleCtx := reqctxpkg.SetUserID(ctx, uid)
	bc, err := llmclientpkg.Resolve(titleCtx, s.modelPicker, s.keyProvider, s.llmFactory)
	if err != nil {
		return
	}

	tCtx, cancel := context.WithTimeout(titleCtx, 10*time.Second)
	defer cancel()

	req := llminfra.Request{
		ModelID: bc.ModelID, Key: bc.Key, BaseURL: bc.BaseURL,
		System: "Generate a short conversation title (5 words or fewer). Reply with ONLY the title, no punctuation.\n只返回标题本身，不超过 10 个字，不加标点。",
		Messages: []llminfra.LLMMessage{
			{Role: llminfra.RoleUser, Content: "Assistant said: " + truncate(assistantContent, 300)},
		},
	}
	title, err := llminfra.Generate(tCtx, bc.Client, req)
	if err != nil || title == "" {
		return
	}
	conv.Title = strings.TrimSpace(title)
	conv.AutoTitled = true
	if err := s.convRepo.Save(titleCtx, conv); err != nil {
		s.log.Warn("auto-title save failed", zap.Error(err))
		return
	}
	s.notifications.Publish(titleCtx, "conversation", conv.ID, conv)
	s.log.Info("auto-title generated",
		zap.String("conversation_id", conv.ID), zap.String("title", conv.Title))
}
