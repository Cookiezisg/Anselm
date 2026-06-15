package mcp

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/foryx/backend/internal/domain/relation"
)

// NamesByIDs implements relationapp.Namer: batch mcp_id → name for relation-graph name
// hydration. The relation node id is the mcp_ id (not the name), so renames don't break
// edges (aligns function/handler). Missing/cross-workspace ids are omitted (orphan nodes
// won't render).
//
// NamesByIDs 实现 relationapp.Namer：批量 mcp_id → name，供 relation 图 hydrate 名字。relation
// 节点 id 用 mcp_ id（非 name），改名不断边（对齐 function/handler）。缺失/跨 workspace 的 id 略过
// （孤立节点不显示）。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	out := make(map[string]string, len(ids))
	for _, id := range ids {
		srv, err := s.repo.GetByID(ctx, id)
		if err != nil {
			continue
		}
		out[id] = srv.Name
	}
	return out, nil
}

// purgeRelations hard-deletes every relation edge touching this server (called on remove).
//
// purgeRelations 硬删触及该 server 的所有 relation 边（删除时调）。
func (s *Service) purgeRelations(ctx context.Context, id string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindMCP, id); err != nil {
		s.log.Warn("mcp relation PurgeEntity failed", zap.String("id", id), zap.Error(err))
	}
}
