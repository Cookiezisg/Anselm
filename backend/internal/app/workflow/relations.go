package workflow

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
)

// RelationSyncer is the subset of relationapp.Service we depend on (nil-tolerant).
// Defined here as a port so workflow tests can pass a stub or nil.
//
// RelationSyncer 是我们依赖的 relationapp.Service 子集（允许 nil）。
// 这里作为 port 定义，workflow 测试可传 stub 或 nil。
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	SyncIncoming(ctx context.Context, toKind, toID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// workflowOutKindScope is the 5 outgoing edge types workflow owns; never mutated post-init.
//
// workflowOutKindScope 是 workflow 拥有的 5 种出边类型；初始化后不可变。
var workflowOutKindScope = []string{
	relationdomain.KindWorkflowUsesFunction,
	relationdomain.KindWorkflowUsesHandler,
	relationdomain.KindWorkflowUsesMCP,
	relationdomain.KindWorkflowUsesSkill,
	relationdomain.KindWorkflowUsesDocument,
}

// syncRelationsAfterActiveVersionChange runs SyncOutgoing (5 uses_*) + SyncIncoming (edited).
// Called from Create / AcceptPending / Revert after ActiveVersionID is settled.
// Failures are logged but not propagated (best-effort to avoid blocking core op).
//
// syncRelationsAfterActiveVersionChange 跑 SyncOutgoing (5 uses_*) + SyncIncoming (edited)。
// 由 Create / AcceptPending / Revert 在 ActiveVersionID 落定后调。
// 失败只 log 不传播，避免阻塞核心操作。
func (s *Service) syncRelationsAfterActiveVersionChange(ctx context.Context, wfID string) {
	if s.relations == nil {
		return
	}
	wf, err := s.repo.GetWorkflow(ctx, wfID)
	if err != nil || wf == nil || wf.ActiveVersionID == "" {
		return
	}
	activeV, err := s.repo.GetVersion(ctx, wf.ActiveVersionID)
	if err != nil || activeV == nil {
		s.log.Warn("relation sync: get active version failed",
			zap.String("workflowId", wfID), zap.Error(err))
		return
	}
	s.attachGraph(activeV)
	outEdges := computeWorkflowOutgoingEdges(activeV.GraphParsed)
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindWorkflow, wfID, workflowOutKindScope, outEdges); err != nil {
		s.log.Warn("relation SyncOutgoing failed",
			zap.String("workflowId", wfID), zap.Error(err))
	}

	// Edited edge: editor = active version's conv; suppress if editor == origin (v1's conv).
	editorConv := stringDeref(activeV.ForgedInConversationID)
	originConv := s.getOriginConvID(ctx, wfID)
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
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindWorkflow, wfID,
		[]string{relationdomain.KindConversationEditedEntity}, editedEdges); err != nil {
		s.log.Warn("relation SyncIncoming (edited) failed",
			zap.String("workflowId", wfID), zap.Error(err))
	}
}

// syncRelationsAfterCreate writes the forged edge for v1; called once from Create.
// AcceptPending/Revert do not call this (forged is once-write).
//
// syncRelationsAfterCreate 写 v1 的 forged 边；只在 Create 调一次。
func (s *Service) syncRelationsAfterCreate(ctx context.Context, wfID string, v1ConvID *string) {
	if s.relations == nil || v1ConvID == nil || *v1ConvID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *v1ConvID,
		Kind:      relationdomain.KindConversationForgedEntity,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindWorkflow, wfID,
		[]string{relationdomain.KindConversationForgedEntity}, edges); err != nil {
		s.log.Warn("relation SyncIncoming (forged) failed",
			zap.String("workflowId", wfID), zap.Error(err))
	}
}

// purgeRelations cascades edges on workflow delete.
//
// purgeRelations workflow 删除时级联删边。
func (s *Service) purgeRelations(ctx context.Context, wfID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindWorkflow, wfID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("workflowId", wfID), zap.Error(err))
	}
}

// getOriginConvID looks up the conv that produced version_number=1 for this workflow.
// "" if v1 missing or not LLM-forged.
//
// getOriginConvID 查这个 workflow 的 v1 是哪个对话产生的。v1 缺失或非 LLM 产生时返 ""。
func (s *Service) getOriginConvID(ctx context.Context, wfID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, wfID, 1)
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

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.WorkflowReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.WorkflowReader。
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

// computeWorkflowOutgoingEdges walks a workflow Graph and produces edge specs
// pointing at every entity referenced by the graph's nodes.
//
// computeWorkflowOutgoingEdges 走 workflow Graph，为图中节点引用的每个实体产出边规约。
func computeWorkflowOutgoingEdges(g *workflowdomain.Graph) []relationdomain.SyncEdge {
	if g == nil {
		return nil
	}
	type key struct{ otherKind, otherID, kind string }
	agg := map[key]*relationdomain.SyncEdge{}

	add := func(otherKind, otherID, kind, nodeID string, extra map[string]any) {
		if otherKind == "" || otherID == "" {
			return
		}
		k := key{otherKind, otherID, kind}
		if e, ok := agg[k]; ok {
			// Append nodeID to attrs.nodeIds list
			if ids, ok := e.Attrs["nodeIds"].([]string); ok {
				e.Attrs["nodeIds"] = append(ids, nodeID)
			} else {
				e.Attrs["nodeIds"] = []string{nodeID}
			}
			return
		}
		attrs := map[string]any{"nodeIds": []string{nodeID}}
		for k2, v := range extra {
			attrs[k2] = v
		}
		agg[k] = &relationdomain.SyncEdge{
			OtherKind: otherKind, OtherID: otherID, Kind: kind, Attrs: attrs,
		}
	}

	for _, n := range g.Nodes {
		switch n.Type {
		case workflowdomain.NodeTypeFunction:
			fnID, _ := n.Config["functionId"].(string)
			extra := map[string]any{}
			if v, _ := n.Config["version"].(string); v != "" {
				extra["pinnedVersionId"] = v
			}
			add(relationdomain.EntityKindFunction, fnID, relationdomain.KindWorkflowUsesFunction, n.ID, extra)
		case workflowdomain.NodeTypeHandler:
			hdID, _ := n.Config["handlerId"].(string)
			extra := map[string]any{}
			if v, _ := n.Config["version"].(string); v != "" {
				extra["pinnedVersionId"] = v
			}
			add(relationdomain.EntityKindHandler, hdID, relationdomain.KindWorkflowUsesHandler, n.ID, extra)
		case workflowdomain.NodeTypeMCP:
			server, _ := n.Config["serverName"].(string)
			extra := map[string]any{"serverName": server}
			add(relationdomain.EntityKindMCP, server, relationdomain.KindWorkflowUsesMCP, n.ID, extra)
		case workflowdomain.NodeTypeSkill:
			skillName, _ := n.Config["skillName"].(string)
			extra := map[string]any{"skillName": skillName}
			add(relationdomain.EntityKindSkill, skillName, relationdomain.KindWorkflowUsesSkill, n.ID, extra)
		case workflowdomain.NodeTypeLLM, workflowdomain.NodeTypeAgent:
			// attached_documents is a list of {documentId, includeSubtree}
			if rawList, ok := n.Config["attachedDocuments"].([]any); ok {
				for _, raw := range rawList {
					m, _ := raw.(map[string]any)
					if m == nil {
						continue
					}
					docID, _ := m["documentId"].(string)
					includeSubtree, _ := m["includeSubtree"].(bool)
					extra := map[string]any{"includeSubtree": includeSubtree}
					add(relationdomain.EntityKindDocument, docID, relationdomain.KindWorkflowUsesDocument, n.ID, extra)
				}
			}
		}
	}

	out := make([]relationdomain.SyncEdge, 0, len(agg))
	for _, e := range agg {
		out = append(out, *e)
	}
	return out
}
