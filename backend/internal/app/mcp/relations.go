package mcp

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of relationapp.Service mcp consumes (nil-tolerant).
type RelationSyncer interface {
	PurgeEntity(ctx context.Context, kind, id string) error
}

func (s *Service) purgeRelations(ctx context.Context, serverName string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindMCP, serverName); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("serverName", serverName), zap.Error(err))
	}
}

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.McpReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.McpReader。
func (s *Service) ListAllMeta(ctx context.Context, _ string) ([]relationdomain.EntityMeta, error) {
	rows := s.ListServers(ctx)
	out := make([]relationdomain.EntityMeta, 0, len(rows))
	for _, r := range rows {
		out = append(out, relationdomain.EntityMeta{ID: r.Name, Label: r.Name, Sub: r.Status})
	}
	return out, nil
}
