// host.go — chatHost implements loop.Host for the main conversation pipeline.
// Persists to chat_messages, fires chat.message events tagged to the
// conversation. autoTitle and queue management stay in runner.go.
//
// host.go — chatHost 实现 loop.Host 给主对话管线用。落到 chat_messages，
// 给对话发 chat.message 事件。autoTitle 与队列管理留在 runner.go。
package chat

import (
	"context"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// chatHost wires loop.Host to chat-specific persistence + event publishing.
//
// chatHost 把 loop.Host 接到 chat 特有的持久化 + 事件推送上。
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

func (h *chatHost) Publish(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	msg := buildMessage(h.msgID, h.convID, h.uid, blocks, status, stopReason, errCode, errMsg, in, out)
	h.svc.bridge.Publish(ctx, h.convID, eventsdomain.ChatMessage{Message: msg})
}

func (h *chatHost) WriteCheckpoint(ctx context.Context, blocks []chatdomain.Block, in, out int) {
	msg := buildMessage(h.msgID, h.convID, h.uid, blocks, chatdomain.StatusStreaming, "", "", "", in, out)
	if err := h.svc.repo.Save(ctx, msg); err != nil {
		h.svc.log.Warn("streaming checkpoint persist failed, continuing",
			zap.String("msg_id", h.msgID), zap.Error(err))
	}
	h.svc.bridge.Publish(ctx, h.convID, eventsdomain.ChatMessage{Message: msg})
}

func (h *chatHost) WriteFinalize(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	// Detached context: a cancelled upstream stream must not block the
	// terminal write. Re-stamp uid so the saved row keeps ownership.
	//
	// Detached context：已取消的流不能阻止终态写入。重打 uid 让落库行保留 owner。
	saveCtx := reqctxpkg.SetUserID(context.Background(), h.uid)

	msg := buildMessage(h.msgID, h.convID, h.uid, blocks, status, stopReason, errCode, errMsg, in, out)
	if err := h.svc.repo.Save(saveCtx, msg); err != nil {
		h.svc.log.Error("CRITICAL: final assistant message persist failed — message lost",
			zap.String("msg_id", h.msgID), zap.String("conversation_id", h.convID), zap.Error(err))
		// Still publish so UI sees something — overlay persistence failure
		// as the new error reason.
		//
		// 即便如此也要推快照让 UI 看到——把持久化失败覆盖为新 error 原因。
		msg = buildMessage(h.msgID, h.convID, h.uid, blocks, chatdomain.StatusError, chatdomain.StopReasonError,
			"INTERNAL_ERROR", "failed to save assistant message to database", in, out)
	}
	h.svc.bridge.Publish(ctx, h.convID, eventsdomain.ChatMessage{Message: msg})

	// Event-log dual-write: close the assistant message. Map chat status →
	// eventlog status (the four enums align). All any open block_stops are
	// already emitted by streamLLM before WriteFinalize fires.
	//
	// 事件日志 dual-write：关闭 assistant message。chat status → eventlog
	// status 映射（四个枚举对齐）。streamLLM 已在 WriteFinalize 触发前关闭
	// 所有打开的 block_stop。
	h.svc.emitter.StopMessage(ctx, h.msgID, mapStatus(msg.Status),
		msg.StopReason, msg.ErrorCode, msg.ErrorMessage,
		msg.InputTokens, msg.OutputTokens)
}

// mapStatus translates chatdomain.Status* → eventlogdomain.Status*. The
// four values align literally; this helper exists to make the dual-write
// intent explicit at every call site.
//
// mapStatus 把 chatdomain.Status* → eventlogdomain.Status* 翻译。四值字面
// 对齐；本 helper 让 dual-write 意图在每个 call site 显式。
func mapStatus(s string) string {
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

// buildMessage constructs an assistant Message ready for persistence or
// snapshot publish. Blocks are stamped with msgID + sequential global seq.
//
// buildMessage 构造可直接落库或推快照的 assistant Message。Blocks 被打上
// msgID 与全局连续 seq。
func buildMessage(
	msgID, convID, uid string,
	blocks []chatdomain.Block,
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
		Blocks:         stampBlocks(blocks, msgID),
		UpdatedAt:      time.Now().UTC(),
	}
}

// stampBlocks assigns global seq + messageID to every block before a DB write.
// stampBlocks 在写 DB 前为每个 block 打上全局 seq 和 messageID。
func stampBlocks(blocks []chatdomain.Block, msgID string) []chatdomain.Block {
	stamped := make([]chatdomain.Block, len(blocks))
	copy(stamped, blocks)
	for i := range stamped {
		stamped[i].MessageID = msgID
		stamped[i].Seq = i
		if stamped[i].ID == "" {
			stamped[i].ID = newBlockID()
		}
	}
	return stamped
}
