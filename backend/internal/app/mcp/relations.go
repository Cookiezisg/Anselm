package mcp

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// NamesByIDs implements relationapp.Namer: batch key → name for relation-graph name hydration. An MCP
// equip edge is keyed by whatever the mounting ref used — the server NAME (`mcp:<name>/tool`, the common
// form) OR the mcp_ id — so a key here may be EITHER; try id first, then name (F166). Missing/cross-
// workspace keys are omitted (orphan nodes won't render).
//
// NamesByIDs 实现 relationapp.Namer：批量 键→name，供 relation 图 hydrate 名字。MCP equip 边按挂载 ref 用的
// token 存——server **名**（`mcp:<名>/tool` 常见形）**或** mcp_ id——故这里的键二者皆可能；先按 id、再按 name 试
// （F166）。缺失/跨 workspace 键略过（孤立节点不显示）。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	out := make(map[string]string, len(ids))
	for _, id := range ids {
		if srv, err := s.repo.GetByID(ctx, id); err == nil {
			out[id] = srv.Name
		} else if srv, err := s.repo.GetByName(ctx, id); err == nil {
			out[id] = srv.Name
		}
	}
	return out, nil
}

// purgeRelations removes the relation edges touching the MCP server under EVERY key it may be stored
// under. Unlike other entities, an MCP equip edge is keyed by whatever token the mounting ref used —
// the server NAME (the common `mcp:<name>/tool` form computeMountEdges strips to) OR the mcp_ id — so a
// purge by id alone misses the name-keyed edges and ORPHANS a dangling agent/workflow→mcp edge after the
// server is removed (F166). Pass both srv.ID and srv.Name; each is purged best-effort.
//
// purgeRelations 删除触及该 MCP server 的 relation 边——按它可能被存的**每个**键。MCP equip 边按挂载 ref 用的
// token 存——server **名**（常见 `mcp:<名>/tool` 被 computeMountEdges 削成的）**或** mcp_ id——故仅按 id purge 会漏
// 名-键边、server 移除后留悬挂的 agent/workflow→mcp 孤儿边（F166）。传 srv.ID + srv.Name，各 best-effort 清。
func (s *Service) purgeRelations(ctx context.Context, keys ...string) {
	if s.relations == nil {
		return
	}
	for _, key := range keys {
		if key == "" {
			continue
		}
		if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindMCP, key); err != nil {
			s.log.Warn("mcp relation PurgeEntity failed", zap.String("key", key), zap.Error(err))
		}
	}
}
