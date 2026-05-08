// history.go — LLM history construction from DB messages. Used at the start
// of each user turn to seed loop.Run. The blocks→LLM-wire converter is
// shared with the in-loop extender via loop.BlocksToAssistantLLM.
//
// history.go — 从 DB 消息构建 LLM 历史，每个用户回合开头调一次给 loop.Run
// 喂种子。blocks→LLM-wire 转换器与循环内扩展器共享 loop.BlocksToAssistantLLM。
package chat

import (
	"context"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"

	loopapp "github.com/sunweilin/forgify/backend/internal/app/loop"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	chatinfra "github.com/sunweilin/forgify/backend/internal/infra/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// maxHistoryMessages is the maximum number of past messages loaded per LLM call.
// Older messages beyond this limit are silently dropped.
//
// maxHistoryMessages 是每次 LLM 调用加载的历史消息上限，超出的旧消息静默丢弃。
const maxHistoryMessages = 200

// buildHistory loads completed messages from the DB and returns them as LLM
// wire messages. currentUserMsgID is excluded from the main scan and appended
// last, ensuring the LLM always sees the triggering message at the end
// regardless of created_at ordering (prevents the fast-send race condition).
//
// buildHistory 从 DB 加载已完成消息并转为 LLM 协议格式。
// currentUserMsgID 排除在主扫描外并追加到末尾，保证 LLM 以该消息作为待回复轮次，
// 不受快速连发时 created_at 竞态的影响。
func (s *Service) buildHistory(ctx context.Context, convID, currentUserMsgID string) ([]llminfra.LLMMessage, error) {
	rows, _, err := s.repo.ListMessagesByConversation(ctx, convID, chatdomain.ListFilter{Limit: maxHistoryMessages})
	if err != nil {
		return nil, err
	}

	var out []llminfra.LLMMessage
	var currentUserMsg *chatdomain.Message

	for _, m := range rows {
		if m.Status == chatdomain.StatusStreaming || m.Status == chatdomain.StatusPending {
			continue
		}
		if m.ID == currentUserMsgID {
			currentUserMsg = m
			continue
		}
		msgs, err := s.blocksToLLM(ctx, m)
		if err != nil {
			return nil, fmt.Errorf("buildHistory: message %q: %w", m.ID, err)
		}
		out = append(out, msgs...)
	}

	if currentUserMsg != nil {
		msg, err := s.buildUserLLMMessage(ctx, currentUserMsg)
		if err != nil {
			return nil, fmt.Errorf("buildHistory: current user msg %q: %w", currentUserMsgID, err)
		}
		out = append(out, msg)
	}
	return out, nil
}

// blocksToLLM converts one persisted Message to LLM wire messages.
// Delegates assistant blocks to loop.BlocksToAssistantLLM (single source of
// truth shared with the in-loop extender).
//
// blocksToLLM 把一条已持久化的 Message 转为 LLM 协议消息。assistant blocks
// 委托给 loop.BlocksToAssistantLLM（与循环内扩展器共享的事实源）。
func (s *Service) blocksToLLM(ctx context.Context, m *chatdomain.Message) ([]llminfra.LLMMessage, error) {
	switch m.Role {
	case chatdomain.RoleUser:
		msg, err := s.buildUserLLMMessage(ctx, m)
		if err != nil {
			return nil, err
		}
		return []llminfra.LLMMessage{msg}, nil
	case chatdomain.RoleAssistant:
		return loopapp.BlocksToAssistantLLM(m.Blocks)
	}
	return nil, nil
}

// buildUserLLMMessage converts a user message's blocks + attachments
// (from Message.Attrs) to a single LLM message. Text blocks become
// inline content; attachments (now stored in Attrs JSON, not blocks)
// resolve to ContentParts (image → base64, document → extracted text).
// Attachment failures are soft: logged and skipped.
//
// buildUserLLMMessage 把 user 消息的 blocks + Attachments（来自
// Message.Attrs）转为单条 LLM 消息。text block 变为内联 content；
// 附件（现存 Attrs JSON，非 block）解析为 ContentPart（图片 → base64，
// 文档 → 提取文本）。附件失败属于软失败：记录后跳过。
func (s *Service) buildUserLLMMessage(ctx context.Context, m *chatdomain.Message) (llminfra.LLMMessage, error) {
	msg := llminfra.LLMMessage{Role: llminfra.RoleUser}
	var parts []llminfra.ContentPart

	// Text from blocks (after event-log unification, user text lives in
	// blocks of type=text with raw Content).
	//
	// Text 从 blocks 取（事件日志统一后，用户文本在 type=text block 的
	// 裸 Content）。
	for _, b := range m.Blocks {
		if b.Type == eventlogdomain.BlockTypeText && b.Content != "" {
			parts = append(parts, llminfra.ContentPart{Type: "text", Text: b.Content})
		}
	}

	// Attachments from Message.Attrs JSON ({"attachments": [...]}).
	// Attachments 从 Message.Attrs JSON 取。
	if m.Attrs != "" {
		var attrs struct {
			Attachments []chatdomain.AttachmentRef `json:"attachments"`
		}
		if err := json.Unmarshal([]byte(m.Attrs), &attrs); err == nil {
			for _, ref := range attrs.Attachments {
				part, err := s.attachmentToPart(ctx, ref)
				if err != nil {
					s.log.Warn("skipping attachment in LLM history", zap.Error(err))
					continue
				}
				parts = append(parts, *part)
			}
		}
	}

	if len(parts) == 1 && parts[0].Type == "text" {
		msg.Content = parts[0].Text
		return msg, nil
	}
	msg.Parts = parts
	return msg, nil
}

// attachmentToPart resolves an AttachmentRef to a ContentPart.
// Images → image_url (base64 data URL); documents → inlined text part.
//
// attachmentToPart 把 AttachmentRef 解析为 ContentPart。
// 图片 → image_url（base64 data URL）；文档 → 内联文本。
func (s *Service) attachmentToPart(ctx context.Context, ref chatdomain.AttachmentRef) (*llminfra.ContentPart, error) {
	att, err := s.repo.GetAttachment(ctx, ref.AttachmentID)
	if err != nil {
		return nil, fmt.Errorf("attachmentToPart: get attachment %q: %w", ref.AttachmentID, err)
	}

	if chatinfra.IsImage(att.MimeType) {
		data, err := readAndEncode(att.StoragePath)
		if err != nil {
			return nil, fmt.Errorf("attachmentToPart: encode image %q: %w", att.ID, err)
		}
		return &llminfra.ContentPart{
			Type:     "image_url",
			ImageURL: "data:" + att.MimeType + ";base64," + data,
		}, nil
	}

	text, err := chatinfra.Extract(att.StoragePath, att.MimeType)
	if err != nil {
		return nil, fmt.Errorf("attachmentToPart: extract %q: %w", att.ID, err)
	}
	return &llminfra.ContentPart{
		Type: "text",
		Text: fmt.Sprintf("\n\n[附件: %s]\n%s", att.FileName, text),
	}, nil
}
