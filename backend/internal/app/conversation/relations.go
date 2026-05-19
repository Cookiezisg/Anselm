package conversation

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of relationapp.Service conversation consumes (nil-tolerant).
type RelationSyncer interface {
	PurgeEntity(ctx context.Context, kind, id string) error
}

func (s *Service) purgeRelations(ctx context.Context, convID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindConversation, convID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("conversationId", convID), zap.Error(err))
	}
}

// GetMetaBatch returns slim metas for the given conversation IDs. Implements relationapp.ConversationReader.
// label = Title if non-empty, else Summary[:30], else "(未命名对话)".
//
// GetMetaBatch 给指定 ID 列表返精简 meta。实现 relationapp.ConversationReader。
// label：Title 非空用 Title；否则 Summary 前 30 字；都空用 "(未命名对话)"。
func (s *Service) GetMetaBatch(ctx context.Context, _ string, ids []string) ([]relationdomain.EntityMeta, error) {
	out := make([]relationdomain.EntityMeta, 0, len(ids))
	for _, id := range ids {
		c, err := s.repo.Get(ctx, id)
		if err != nil {
			// soft-deleted or missing — skip (relgraph treats absent as "not in graph")
			continue
		}
		label := c.Title
		if label == "" {
			if c.Summary != "" {
				label = c.Summary
				if len(label) > 30 {
					label = label[:30] + "…"
				}
			} else {
				label = "(未命名对话)"
			}
		}
		out = append(out, relationdomain.EntityMeta{ID: c.ID, Label: label})
	}
	return out, nil
}
