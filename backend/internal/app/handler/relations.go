package handler

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of relationapp.Service handler consumes (nil-tolerant).
//
// RelationSyncer 是 handler 消费的 relationapp.Service 子集（允许 nil）。
type RelationSyncer interface {
	SyncIncoming(ctx context.Context, toKind, toID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

func (s *Service) syncRelationsAfterActiveVersionChange(ctx context.Context, hdID string) {
	if s.relations == nil {
		return
	}
	h, err := s.repo.GetHandler(ctx, hdID)
	if err != nil || h == nil || h.ActiveVersionID == "" {
		return
	}
	activeV, err := s.repo.GetVersion(ctx, h.ActiveVersionID)
	if err != nil || activeV == nil {
		s.log.Warn("relation sync: get active version failed",
			zap.String("handlerId", hdID), zap.Error(err))
		return
	}

	editorConv := stringDeref(activeV.ForgedInConversationID)
	originConv := s.getOriginConvID(ctx, hdID)
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
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindHandler, hdID,
		[]string{relationdomain.KindConversationEditedEntity}, editedEdges); err != nil {
		s.log.Warn("relation SyncIncoming (edited) failed",
			zap.String("handlerId", hdID), zap.Error(err))
	}
}

func (s *Service) syncRelationsAfterCreate(ctx context.Context, hdID string, v1ConvID *string) {
	if s.relations == nil || v1ConvID == nil || *v1ConvID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *v1ConvID,
		Kind:      relationdomain.KindConversationForgedEntity,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindHandler, hdID,
		[]string{relationdomain.KindConversationForgedEntity}, edges); err != nil {
		s.log.Warn("relation SyncIncoming (forged) failed",
			zap.String("handlerId", hdID), zap.Error(err))
	}
}

func (s *Service) purgeRelations(ctx context.Context, hdID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindHandler, hdID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("handlerId", hdID), zap.Error(err))
	}
}

func (s *Service) getOriginConvID(ctx context.Context, hdID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, hdID, 1)
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

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.HandlerReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.HandlerReader。
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
