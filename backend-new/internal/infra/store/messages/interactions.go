package messages

import (
	"fmt"

	"context"

	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
)

// GetParkedMessage returns a conversation's parked assistant turn (StatusParked) with Blocks
// hydrated, or ErrMessageNotFound. At most one turn is parked at a time (Send is refused while one
// is), so the newest parked row is the answer (R0064).
//
// GetParkedMessage 返回一个对话 parked 的 assistant 回合（StatusParked）并 hydrate Blocks，无则
// ErrMessageNotFound。同一时刻至多一个回合 parked（parked 期间 Send 被拒），故最新的 parked 行即答案（R0064）。
func (s *Store) GetParkedMessage(ctx context.Context, conversationID string) (*messagesdomain.Message, error) {
	rows, err := s.msgs.WhereEq("conversation_id", conversationID).
		WhereEq("status", messagesdomain.StatusParked).
		Order("created_at DESC, id DESC").Find(ctx)
	if err != nil {
		return nil, fmt.Errorf("messagesstore.GetParkedMessage: %w", err)
	}
	if len(rows) == 0 {
		return nil, messagesdomain.ErrMessageNotFound
	}
	m := rows[0]
	if err := s.hydrate(ctx, []*messagesdomain.Message{m}); err != nil {
		return nil, err
	}
	return m, nil
}

// ResolveToolResult fills a pending tool_result block in place — content + terminal status +
// error — keyed by block id (partial Updates, auto workspace filter in the WHERE). The durable
// half of resolving one interaction; not an append (R0064).
//
// ResolveToolResult 原地填一个 pending tool_result 块——content + 终态 + error，按 block id（部分 Updates，
// WHERE 带自动 workspace 过滤）。决议一条交互的耐久半边；非追加（R0064）。
func (s *Store) ResolveToolResult(ctx context.Context, blockID, content, status, errMsg string) error {
	n, err := s.blocks.WhereEq("id", blockID).Updates(ctx, map[string]any{
		"content": content,
		"status":  status,
		"error":   errMsg,
	})
	if err != nil {
		return fmt.Errorf("messagesstore.ResolveToolResult: %w", err)
	}
	if n == 0 {
		return messagesdomain.ErrMessageNotFound
	}
	return nil
}

// SetMessageStatus flips a turn's status + stop_reason in place (parked → completed / cancelled);
// never touches blocks (R0064).
//
// SetMessageStatus 原地翻一个回合的 status + stop_reason（parked → completed / cancelled）；绝不碰 blocks（R0064）。
func (s *Store) SetMessageStatus(ctx context.Context, messageID, status, stopReason string) error {
	n, err := s.msgs.WhereEq("id", messageID).Updates(ctx, map[string]any{
		"status":      status,
		"stop_reason": stopReason,
	})
	if err != nil {
		return fmt.Errorf("messagesstore.SetMessageStatus: %w", err)
	}
	if n == 0 {
		return messagesdomain.ErrMessageNotFound
	}
	return nil
}
