package workflow

import (
	"context"
	"strings"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/foryx/backend/internal/domain/relation"
	workflowdomain "github.com/sunweilin/foryx/backend/internal/domain/workflow"
)

// NamesByIDs implements relationapp.Namer: a batch id→name lookup so the relation graph can
// hydrate display names for workflow nodes at read time.
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供 relation 图读时为 workflow 节点 hydrate
// 显示名。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetWorkflowsByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, w := range rows {
		out[w.ID] = w.Name
	}
	return out, nil
}

// syncRelations re-syncs the workflow's outgoing equip edges (every entity its active graph
// references: trigger / fn / hd / mcp / agent / control / approval) plus the incoming
// create/edit edge from the conversation that built the active version. Recomputed on
// Create / Edit / Revert (active version changed → references may have changed).
//
// syncRelations 重 sync workflow 的出向 equip 边（active 图引用的每个实体：trigger / fn / hd /
// mcp / agent / control / approval）+ 构建 active 版本的对话的入向 create/edit 边。Create /
// Edit / Revert 后重算（active 版本变 → 引用可能变）。
func (s *Service) syncRelations(ctx context.Context, w *workflowdomain.Workflow, v *workflowdomain.Version, g *workflowdomain.Graph) {
	if s.relations == nil {
		return
	}
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindWorkflow, w.ID,
		[]string{relationdomain.KindEquip}, computeRefEdges(g)); err != nil {
		s.log.Warn("workflowapp.syncRelations: equip sync failed", zap.String("workflowId", w.ID), zap.Error(err))
	}
	s.syncBuiltEdge(ctx, w.ID, v)
}

// computeRefEdges derives equip out-edges from the graph's node refs, one per referenced
// entity: trg_ → Trigger, fn_ → Function, hd_…method → Handler (strip .method),
// mcp:server/tool → MCP (strip /tool), ag_ → Agent, ctl_ → Control, apf_ → Approval. All
// KindEquip; OtherKind distinguishes the target. Deduped (a graph may reference an entity in
// several nodes — the topology edge is the same).
//
// computeRefEdges 从图 node ref 推 equip 出边，每个被引用实体一条：trg_ → Trigger、fn_ →
// Function、hd_…method → Handler（剥 .method）、mcp:server/tool → MCP（剥 /tool）、ag_ → Agent、
// ctl_ → Control、apf_ → Approval。全 KindEquip；OtherKind 区分目标。去重（图可在多节点引用同一
// 实体——拓扑边相同）。
func computeRefEdges(g *workflowdomain.Graph) []relationdomain.SyncEdge {
	if g == nil {
		return nil
	}
	type key struct{ kind, id string }
	seen := map[key]bool{}
	var edges []relationdomain.SyncEdge
	add := func(kind, id string) {
		k := key{kind, id}
		if id == "" || seen[k] {
			return
		}
		seen[k] = true
		edges = append(edges, relationdomain.SyncEdge{OtherKind: kind, OtherID: id, Kind: relationdomain.KindEquip})
	}
	for i := range g.Nodes {
		ref := strings.TrimSpace(g.Nodes[i].Ref)
		switch {
		case strings.HasPrefix(ref, workflowdomain.RefPrefixTrigger):
			add(relationdomain.EntityKindTrigger, ref)
		case strings.HasPrefix(ref, workflowdomain.RefPrefixFunction):
			add(relationdomain.EntityKindFunction, ref)
		case strings.HasPrefix(ref, workflowdomain.RefPrefixHandler):
			add(relationdomain.EntityKindHandler, entityIDOf(ref))
		case strings.HasPrefix(ref, workflowdomain.RefPrefixMCP):
			add(relationdomain.EntityKindMCP, entityIDOf(ref))
		case strings.HasPrefix(ref, workflowdomain.RefPrefixAgent):
			add(relationdomain.EntityKindAgent, ref)
		case strings.HasPrefix(ref, workflowdomain.RefPrefixControl):
			add(relationdomain.EntityKindControl, ref)
		case strings.HasPrefix(ref, workflowdomain.RefPrefixApproval):
			add(relationdomain.EntityKindApproval, ref)
		}
	}
	return edges
}

// syncBuiltEdge records the create (v1) or edit (v>1) incoming edge from the conversation
// that produced the active version. create and edit live in separate kind-scopes so they
// coexist (v1's create edge survives later edits).
//
// syncBuiltEdge 记录产出 active 版本的对话的 create（v1）/ edit（v>1）入边。create 与 edit 在
// 不同 kind-scope，故共存（v1 的 create 边在后续 edit 后仍在）。
func (s *Service) syncBuiltEdge(ctx context.Context, workflowID string, v *workflowdomain.Version) {
	if s.relations == nil || v.BuiltInConversationID == nil || *v.BuiltInConversationID == "" {
		return
	}
	kind := relationdomain.KindCreate
	if v.Version > 1 {
		kind = relationdomain.KindEdit
	}
	edges := []relationdomain.SyncEdge{
		{OtherKind: relationdomain.EntityKindConversation, OtherID: *v.BuiltInConversationID, Kind: kind},
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindWorkflow, workflowID, []string{kind}, edges); err != nil {
		s.log.Warn("workflowapp.syncBuiltEdge: failed", zap.String("workflowId", workflowID), zap.Error(err))
	}
}

// purgeRelations hard-deletes every edge touching the workflow (called on Delete).
//
// purgeRelations 硬删触及该 workflow 的所有边（Delete 时调）。
func (s *Service) purgeRelations(ctx context.Context, id string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindWorkflow, id); err != nil {
		s.log.Warn("workflowapp.purgeRelations: failed", zap.String("workflowId", id), zap.Error(err))
	}
}
