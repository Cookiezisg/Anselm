package agent

import (
	"context"
	"strings"

	"go.uber.org/zap"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of relationapp.Service the agent service consumes (nil-tolerant).
// Defined here as a port so agent tests can pass a stub or nil.
//
// RelationSyncer 是 agent service 消费的 relationapp.Service 子集（允许 nil）。
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	SyncIncoming(ctx context.Context, toKind, toID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// agentOutKindScope is the 5 outgoing edge types an agent owns (doc 09 quadrinity; no agent_uses_agent).
//
// agentOutKindScope 是 agent 拥有的 5 种出边类型（无 agent_uses_agent，员工不调员工）。
var agentOutKindScope = []string{
	relationdomain.KindAgentUsesFunction,
	relationdomain.KindAgentUsesHandler,
	relationdomain.KindAgentUsesMCP,
	relationdomain.KindAgentUsesDocument,
	relationdomain.KindAgentUsesSkill,
}

// SetRelationSyncer wires the relation sync port post-construction (avoids import cycle).
//
// SetRelationSyncer 装配后注入 relation 同步端口（避免循环依赖）。
func (s *Service) SetRelationSyncer(r RelationSyncer) { s.relations = r }

// syncRelationsAfterActiveVersionChange runs SyncOutgoing (5 uses_*) + SyncIncoming (edited).
// Called from Create / Accept / Revert after ActiveVersionID settles. Best-effort (logged, not propagated).
//
// syncRelationsAfterActiveVersionChange 跑 SyncOutgoing (5 uses_*) + SyncIncoming (edited)。
// 由 Create / Accept / Revert 在 ActiveVersionID 落定后调；失败只 log 不传播。
func (s *Service) syncRelationsAfterActiveVersionChange(ctx context.Context, agentID string) {
	if s.relations == nil {
		return
	}
	a, err := s.repo.Get(ctx, agentID)
	if err != nil || a == nil || a.ActiveVersionID == "" {
		return
	}
	activeV, err := s.repo.GetVersion(ctx, a.ActiveVersionID)
	if err != nil || activeV == nil {
		s.log.Warn("relation sync: get active version failed",
			zap.String("agentId", agentID), zap.Error(err))
		return
	}
	outEdges := computeAgentOutgoingEdges(activeV)
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindAgent, agentID, agentOutKindScope, outEdges); err != nil {
		s.log.Warn("relation SyncOutgoing failed",
			zap.String("agentId", agentID), zap.Error(err))
	}

	// Edited edge: editor = active version's conv; suppress if editor == origin (v1's conv).
	editorConv := stringDeref(activeV.ForgedInConversationID)
	originConv := s.getOriginConvID(ctx, agentID)
	var editedEdges []relationdomain.SyncEdge
	if editorConv != "" && editorConv != originConv {
		versionNum := 0
		if activeV.Version != nil {
			versionNum = *activeV.Version
		}
		editedEdges = []relationdomain.SyncEdge{{
			OtherKind: relationdomain.EntityKindConversation,
			OtherID:   editorConv,
			Kind:      relationdomain.KindConversationEditedEntity,
			Attrs:     map[string]any{"versionId": activeV.ID, "versionNumber": versionNum},
		}}
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindAgent, agentID,
		[]string{relationdomain.KindConversationEditedEntity}, editedEdges); err != nil {
		s.log.Warn("relation SyncIncoming (edited) failed",
			zap.String("agentId", agentID), zap.Error(err))
	}
}

// syncRelationsAfterCreate writes v1's forged edge; called once from Create.
//
// syncRelationsAfterCreate 写 v1 的 forged 边；只在 Create 调一次。
func (s *Service) syncRelationsAfterCreate(ctx context.Context, agentID string, v1ConvID *string) {
	if s.relations == nil || v1ConvID == nil || *v1ConvID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *v1ConvID,
		Kind:      relationdomain.KindConversationForgedEntity,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindAgent, agentID,
		[]string{relationdomain.KindConversationForgedEntity}, edges); err != nil {
		s.log.Warn("relation SyncIncoming (forged) failed",
			zap.String("agentId", agentID), zap.Error(err))
	}
}

// purgeRelations cascades edges on agent delete.
//
// purgeRelations agent 删除时级联删边。
func (s *Service) purgeRelations(ctx context.Context, agentID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindAgent, agentID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("agentId", agentID), zap.Error(err))
	}
}

// getOriginConvID looks up the conv that produced version_number=1 for this agent.
//
// getOriginConvID 查这个 agent 的 v1 是哪个对话产生的。
func (s *Service) getOriginConvID(ctx context.Context, agentID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, agentID, 1)
	if err != nil || v1 == nil {
		return ""
	}
	return stringDeref(v1.ForgedInConversationID)
}

func stringDeref(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// computeAgentOutgoingEdges derives agent_uses_* edges from a version's Tools (fn/hd/mcp refs),
// Knowledge (document ids) and Skill — the agent analog of workflow graph-ref scanning.
//
// computeAgentOutgoingEdges 从 version 的 Tools(fn/hd/mcp ref)+ Knowledge(文档 id)+ Skill 推出 agent_uses_* 边。
func computeAgentOutgoingEdges(v *agentdomain.AgentVersion) []relationdomain.SyncEdge {
	if v == nil {
		return nil
	}
	type key struct{ otherKind, otherID, kind string }
	seen := map[key]bool{}
	var out []relationdomain.SyncEdge
	add := func(otherKind, otherID, kind string) {
		if otherKind == "" || otherID == "" {
			return
		}
		k := key{otherKind, otherID, kind}
		if seen[k] {
			return
		}
		seen[k] = true
		out = append(out, relationdomain.SyncEdge{OtherKind: otherKind, OtherID: otherID, Kind: kind})
	}

	for _, t := range v.Tools {
		ref := t.Ref
		switch {
		case strings.HasPrefix(ref, "fn_"):
			add(relationdomain.EntityKindFunction, ref, relationdomain.KindAgentUsesFunction)
		case strings.HasPrefix(ref, "hd_"):
			// hd_xxx.method → handler entity id is hd_xxx (strip the .method suffix).
			id := ref
			if i := strings.IndexByte(id, '.'); i >= 0 {
				id = id[:i]
			}
			add(relationdomain.EntityKindHandler, id, relationdomain.KindAgentUsesHandler)
		case strings.HasPrefix(ref, "mcp:"):
			// mcp:server/tool → mcp entity id is the server name.
			server := strings.TrimPrefix(ref, "mcp:")
			if i := strings.IndexByte(server, '/'); i >= 0 {
				server = server[:i]
			}
			add(relationdomain.EntityKindMCP, server, relationdomain.KindAgentUsesMCP)
		}
	}
	for _, docID := range v.Knowledge {
		add(relationdomain.EntityKindDocument, docID, relationdomain.KindAgentUsesDocument)
	}
	if v.Skill != "" {
		add(relationdomain.EntityKindSkill, v.Skill, relationdomain.KindAgentUsesSkill)
	}
	return out
}

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.AgentReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.AgentReader。
func (s *Service) ListAllMeta(ctx context.Context, _ string) ([]relationdomain.EntityMeta, error) {
	rows, err := s.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]relationdomain.EntityMeta, 0, len(rows))
	for _, r := range rows {
		out = append(out, relationdomain.EntityMeta{ID: r.ID, Label: r.Name, Sub: r.Description})
	}
	return out, nil
}
