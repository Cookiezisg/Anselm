package agent

import (
	"context"
	"strings"

	"go.uber.org/zap"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// syncRelations re-syncs the agent's outgoing equip edges (the mounted fn/hd/mcp/doc/skill on
// the active version) plus the incoming create/edit edge from the conversation that forged it.
// Recomputed on Create / Edit / Revert (active version changed → mounts may have changed).
//
// syncRelations 重 sync agent 的出向 equip 边（active 版本挂载的 fn/hd/mcp/doc/skill）+ 锻造它的
// 对话的入向 create/edit 边。Create / Edit / Revert 后重算（active 版本变 → 挂载可能变）。
func (s *Service) syncRelations(ctx context.Context, a *agentdomain.Agent, v *agentdomain.Version) {
	if s.relations == nil {
		return
	}
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindAgent, a.ID,
		[]string{relationdomain.KindEquip}, computeMountEdges(v)); err != nil {
		s.log.Warn("agentapp.syncRelations: equip sync failed", zap.String("agentId", a.ID), zap.Error(err))
	}
	s.syncForgedEdge(ctx, a.ID, v)
}

// computeMountEdges derives equip out-edges from the active version's mounted refs:
// fn_ → Function, hd_…method → Handler (strip .method), mcp:server/tool → MCP (strip /tool),
// each knowledge doc → Document, skill → Skill. All KindEquip; OtherKind distinguishes target.
// No agent→agent edge (an agent cannot mount another agent).
//
// computeMountEdges 从 active 版本挂载 ref 推 equip 出边：fn_ → Function、hd_…method → Handler
// （剥 .method）、mcp:server/tool → MCP（剥 /tool）、每个 knowledge 文档 → Document、skill → Skill。
// 全 KindEquip；OtherKind 区分目标。无 agent→agent 边（员工不挂员工）。
func computeMountEdges(v *agentdomain.Version) []relationdomain.SyncEdge {
	var edges []relationdomain.SyncEdge
	for _, t := range v.Tools {
		ref := strings.TrimSpace(t.Ref)
		switch {
		case strings.HasPrefix(ref, "fn_"):
			edges = append(edges, equip(relationdomain.EntityKindFunction, ref))
		case strings.HasPrefix(ref, "hd_"):
			id := ref
			if i := strings.IndexByte(ref, '.'); i > 0 {
				id = ref[:i]
			}
			edges = append(edges, equip(relationdomain.EntityKindHandler, id))
		case strings.HasPrefix(ref, "mcp:"):
			server := strings.TrimPrefix(ref, "mcp:")
			if i := strings.IndexByte(server, '/'); i > 0 {
				server = server[:i]
			}
			edges = append(edges, equip(relationdomain.EntityKindMCP, server))
		}
	}
	for _, docID := range v.Knowledge {
		if strings.TrimSpace(docID) != "" {
			edges = append(edges, equip(relationdomain.EntityKindDocument, docID))
		}
	}
	if v.Skill != "" {
		edges = append(edges, equip(relationdomain.EntityKindSkill, v.Skill))
	}
	return edges
}

func equip(kind, id string) relationdomain.SyncEdge {
	return relationdomain.SyncEdge{OtherKind: kind, OtherID: id, Kind: relationdomain.KindEquip}
}

// syncForgedEdge records the create (v1) or edit (v>1) incoming edge from the conversation that
// produced the active version. create and edit live in separate kind-scopes so they coexist
// (v1's create edge survives later edits).
//
// syncForgedEdge 记录产出 active 版本的对话的 create（v1）/ edit（v>1）入边。create 与 edit 在不同
// kind-scope，故共存（v1 的 create 边在后续 edit 后仍在）。
func (s *Service) syncForgedEdge(ctx context.Context, agentID string, v *agentdomain.Version) {
	if s.relations == nil || v.ForgedInConversationID == "" {
		return
	}
	kind := relationdomain.KindCreate
	if v.Version > 1 {
		kind = relationdomain.KindEdit
	}
	edges := []relationdomain.SyncEdge{
		{OtherKind: relationdomain.EntityKindConversation, OtherID: v.ForgedInConversationID, Kind: kind},
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindAgent, agentID, []string{kind}, edges); err != nil {
		s.log.Warn("agentapp.syncForgedEdge: failed", zap.String("agentId", agentID), zap.Error(err))
	}
}

// purgeRelations cascades edge deletion when an agent is deleted.
//
// purgeRelations 在 agent 删除时级联删边。
func (s *Service) purgeRelations(ctx context.Context, id string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindAgent, id); err != nil {
		s.log.Warn("agentapp.purgeRelations: failed", zap.String("agentId", id), zap.Error(err))
	}
}

// NamesByIDs implements relationapp.Namer: batch id→name so the relation graph hydrates
// display names for agent nodes (the target end of workflow equip / conversation forged edges).
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供 relation 图为 agent 节点（workflow equip /
// conversation forged 边的目标端）hydrate 显示名。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, a := range rows {
		out[a.ID] = a.Name
	}
	return out, nil
}
