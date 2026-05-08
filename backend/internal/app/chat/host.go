// host.go — chatHost implements loop.Host for the main conversation
// pipeline. WriteFinalize persists the assistant Message row + emits
// message_stop on the eventlog Bridge. autoTitle and queue management
// stay in runner.go.
//
// host.go ——chatHost 实现主对话管线的 loop.Host。WriteFinalize 持久化
// assistant Message 行 + 给 eventlog Bridge 发 message_stop。autoTitle
// 与队列管理留在 runner.go。
package chat

import (
	"context"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// chatHost wires loop.Host to chat-specific persistence + eventlog
// emit. Block writes happen real-time via emit (in stream.go +
// runOneTool); WriteFinalize closes the assistant message at the end.
//
// chatHost 把 loop.Host 接到 chat 特有的持久化 + eventlog emit。Block
// 写实时走 emit（stream.go + runOneTool）；WriteFinalize 在最后关闭
// assistant message。
type chatHost struct {
	svc       *Service
	convID    string
	uid       string
	msgID     string
	userMsgID string // for buildHistory; loop calls LoadHistory once
}

func (h *chatHost) LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error) {
	return h.svc.buildHistory(ctx, h.convID, h.userMsgID)
}

func (h *chatHost) Tools() []toolapp.Tool {
	return h.svc.tools
}

func (h *chatHost) WriteFinalize(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	// Detached context: a cancelled upstream stream must not block the
	// terminal write. Re-stamp uid so the saved row keeps ownership.
	//
	// Detached context：已取消的流不能阻止终态写入。重打 uid 让落库行保留 owner。
	saveCtx := reqctxpkg.SetUserID(context.Background(), h.uid)

	msg := buildMessage(h.msgID, h.convID, h.uid, status, stopReason, errCode, errMsg, in, out)
	if err := h.svc.repo.SaveMessage(saveCtx, msg); err != nil {
		h.svc.log.Error("CRITICAL: final assistant message persist failed — message lost",
			zap.String("msg_id", h.msgID), zap.String("conversation_id", h.convID), zap.Error(err))
		// Override status with error reason for the eventlog stop event.
		// 把 status 覆盖为 error 给 eventlog stop 事件。
		msg.Status = chatdomain.StatusError
		msg.StopReason = chatdomain.StopReasonError
		msg.ErrorCode = "INTERNAL_ERROR"
		msg.ErrorMessage = "failed to save assistant message to database"
	}

	// Event-log: close the assistant message. Map chat status →
	// eventlog status (the four enums align). Block stops were already
	// emitted by streamLLM before WriteFinalize fires.
	//
	// 事件日志：关 assistant message。chat status → eventlog status 映射
	// （四值字面对齐）。Block stops 已在 WriteFinalize 触发前由 streamLLM 发。
	h.svc.emitter.StopMessage(ctx, h.msgID, mapEventLogStatus(msg.Status),
		msg.StopReason, msg.ErrorCode, msg.ErrorMessage,
		msg.InputTokens, msg.OutputTokens)

	// blocks param is unused — emit fires real-time via stream.go +
	// runOneTool, blocks are already in message_blocks. We keep the
	// param to satisfy the loop.Host interface.
	//
	// blocks 参数未用——emit 由 stream.go + runOneTool 实时发，blocks 已在
	// message_blocks。保留参数满足 loop.Host 接口。
	_ = blocks
}

// mapEventLogStatus translates chatdomain.Status* → eventlogdomain.Status*.
//
// mapEventLogStatus 翻译 chatdomain.Status* → eventlogdomain.Status*。
func mapEventLogStatus(s string) string {
	switch s {
	case chatdomain.StatusStreaming:
		return eventlogdomain.StatusStreaming
	case chatdomain.StatusError:
		return eventlogdomain.StatusError
	case chatdomain.StatusCancelled:
		return eventlogdomain.StatusCancelled
	default:
		return eventlogdomain.StatusCompleted
	}
}

// buildMessage constructs an assistant Message row for persistence.
// Blocks are NOT attached — they live in message_blocks and were
// written real-time via emit; SaveMessage only writes the messages row.
//
// buildMessage 构造可持久化的 assistant Message 行。Blocks 不附——它们
// 在 message_blocks 经 emit 实时写；SaveMessage 只写 messages 行。
func buildMessage(
	msgID, convID, uid string,
	status, stopReason, errorCode, errorMessage string,
	inputTokens, outputTokens int,
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
		UpdatedAt:      time.Now().UTC(),
	}
}
