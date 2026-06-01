package chat

import (
	"context"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// chatHost adapts loop.Host to chat persistence + eventlog emit.
//
// chatHost 把 loop.Host 接到 chat 持久化 + eventlog emit。
type chatHost struct {
	svc       *Service
	convID    string
	uid       string
	msgID     string
	userMsgID string
	// provider / modelID identify the LLM serving this turn; recorded
	// on the assistant Message row for /api/v1/usage cost estimation
	// (V1.2 §4.2). Empty in unit tests that bypass picker.
	//
	// provider / modelID 标识本回合 LLM；落库到 assistant Message 行供
	// /api/v1/usage cost 估算（§4.2）。绕过 picker 的单测为空。
	provider string
	modelID  string
}

func (h *chatHost) LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error) {
	return h.svc.buildHistory(ctx, h.convID, h.userMsgID)
}

// Tools returns the resident set plus every lazy group the conversation has
// activated via activate_tools (read from the ctx AgentState). Absent
// AgentState → resident only.
//
// Tools 返回常驻集，加上本对话经 activate_tools 激活的每个 lazy 组
// （从 ctx AgentState 读）。无 AgentState 时只返常驻集。
func (h *chatHost) Tools(ctx context.Context) []toolapp.Tool {
	ts := h.svc.toolset
	out := append([]toolapp.Tool{}, ts.Resident...)
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		for _, cat := range state.ActivatedGroups() {
			out = append(out, ts.Lazy[cat]...)
		}
	}
	return out
}

// TryActivateForTool implements loop.AutoActivator: finds which lazy category owns toolName,
// activates it in the ctx AgentState, and returns the updated tool set. Returns nil if
// toolName is not in any lazy group (wiring bug, not an activation gap).
//
// TryActivateForTool 实现 loop.AutoActivator:找到 toolName 所属 lazy 组,激活后返新工具集。
func (h *chatHost) TryActivateForTool(ctx context.Context, toolName string) []toolapp.Tool {
	ts := h.svc.toolset
	// Find which lazy category contains this tool.
	var foundCat string
	for cat, tools := range ts.Lazy {
		for _, t := range tools {
			if t.Name() == toolName {
				foundCat = cat
				break
			}
		}
		if foundCat != "" {
			break
		}
	}
	if foundCat == "" {
		return nil // not in any lazy group
	}
	// Activate the group in the AgentState so host.Tools() returns it next step too.
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		state.ActivateGroup(foundCat)
	}
	// Return expanded tool set including the newly activated group.
	out := append([]toolapp.Tool{}, ts.Resident...)
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		for _, cat := range state.ActivatedGroups() {
			out = append(out, ts.Lazy[cat]...)
		}
	}
	return out
}

func (h *chatHost) WriteFinalize(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	// Detached ctx: upstream cancel must not block the terminal write or message_stop emit.
	saveCtx := reqctxpkg.SetUserID(context.Background(), h.uid)
	saveCtx = reqctxpkg.WithConversationID(saveCtx, h.convID)

	msg := buildMessage(h.msgID, h.convID, h.uid, status, stopReason, errCode, errMsg, in, out, h.provider, h.modelID)
	if err := h.svc.repo.SaveMessage(saveCtx, msg); err != nil {
		h.svc.log.Error("CRITICAL: final assistant message persist failed — message lost",
			zap.String("msg_id", h.msgID), zap.String("conversation_id", h.convID), zap.Error(err))
		msg.Status = chatdomain.StatusError
		msg.StopReason = chatdomain.StopReasonError
		msg.ErrorCode = "INTERNAL_ERROR"
		msg.ErrorMessage = "failed to save assistant message to database"
	}

	h.svc.emitter.StopMessage(saveCtx, h.msgID, h.mapEventLogStatus(msg.Status),
		msg.StopReason, msg.ErrorCode, msg.ErrorMessage,
		msg.InputTokens, msg.OutputTokens)

	// ctx + blocks intentionally unused — saveCtx carries everything; blocks were emitted real-time.
	_ = ctx
	_ = blocks
}

// chatStatusToEventLog is the pure switch; ok=false means switch missed a chatdomain.Status*.
//
// chatStatusToEventLog 是纯映射；ok=false 表示 switch 漏覆盖某个 chatdomain.Status*。
func chatStatusToEventLog(s string) (string, bool) {
	switch s {
	case chatdomain.StatusStreaming:
		return eventlogdomain.StatusStreaming, true
	case chatdomain.StatusError:
		return eventlogdomain.StatusError, true
	case chatdomain.StatusCancelled:
		return eventlogdomain.StatusCancelled, true
	case chatdomain.StatusCompleted, chatdomain.StatusPending:
		return eventlogdomain.StatusCompleted, true
	default:
		return eventlogdomain.StatusCompleted, false
	}
}

func (h *chatHost) mapEventLogStatus(s string) string {
	out, ok := chatStatusToEventLog(s)
	if !ok {
		h.svc.log.Warn("chat.host.mapEventLogStatus: unknown chatdomain status; mapped to Completed",
			zap.String("status", s), zap.String("msg_id", h.msgID))
	}
	return out
}

// buildMessage constructs an assistant Message row for persistence (blocks live in message_blocks).
//
// buildMessage 构造可持久化的 assistant Message 行（blocks 在 message_blocks）。
func buildMessage(
	msgID, convID, uid string,
	status, stopReason, errorCode, errorMessage string,
	inputTokens, outputTokens int,
	provider, modelID string,
) *chatdomain.Message {
	return &chatdomain.Message{
		ID:             msgID,
		ConversationID: convID,
		UserID:         uid,
		Role:           chatdomain.RoleAssistant,
		Status:         status,
		StopReason:     stopReason,
		ErrorCode:      errorCode,
		ErrorMessage:   errorMessage,
		InputTokens:    inputTokens,
		OutputTokens:   outputTokens,
		Provider:       provider,
		ModelID:        modelID,
	}
}
