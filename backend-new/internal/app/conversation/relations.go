package conversation

import (
	"context"

	"go.uber.org/zap"

	conversationdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of the relation Service conversation consumes (nil-tolerant).
// The relation app's *Service satisfies it directly — same signature — so wiring is a plain
// injection with no adapter.
//
// RelationSyncer 是 conversation 消费的 relation Service 子集（nil-tolerant）。relation app 的
// *Service 直接满足它——签名一致——故装配是纯注入、无需适配器。
type RelationSyncer interface {
	PurgeEntity(ctx context.Context, kind, id string) error
}

// purgeRelations cascade-removes every edge touching the deleted conversation.
//
// purgeRelations 级联清除触及被删对话的所有边。
func (s *Service) purgeRelations(ctx context.Context, convID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindConversation, convID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("conversationId", convID), zap.Error(err))
	}
}

// NamesByIDs implements relation's Namer port for the conversation kind: id → display label
// (Title, else a Summary preview, else a placeholder). relation's read-time hydrate calls it to
// label conversation nodes/edges; a missing id simply gets no name (falls back to the raw id there).
//
// NamesByIDs 实现 relation 的 Namer 端口（conversation 类）：id → 显示标签（Title，否则 Summary
// 预览，否则占位）。relation 读时 hydrate 调它给 conversation 节点/边贴名；缺失 id 直接无名（那边
// 回退原始 id）。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetBatch(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, c := range rows {
		out[c.ID] = label(c)
	}
	return out, nil
}

// label derives a conversation's display name: Title, else a 30-rune Summary preview, else a
// placeholder — so an unnamed thread still shows something useful in the relation graph.
//
// label 推导对话的显示名：Title，否则 30 字 Summary 预览，否则占位——使未命名线程在 relation 图里
// 仍显示有用信息。
func label(c *conversationdomain.Conversation) string {
	if c.Title != "" {
		return c.Title
	}
	if c.Summary != "" {
		r := []rune(c.Summary)
		if len(r) > 30 {
			return string(r[:30]) + "…"
		}
		return c.Summary
	}
	return "(未命名对话)"
}
