package handler

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// NamesByIDs implements relationapp.Namer: a batch id→name lookup for relation-graph
// name hydration of handler nodes.
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供 relation 图为 handler 节点 hydrate 名字。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetHandlersByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, h := range rows {
		out[h.ID] = h.Name
	}
	return out, nil
}

// syncBuiltEdge records the "create" edge from the originating conversation to v1.
func (s *Service) syncBuiltEdge(ctx context.Context, hID string, convID *string) {
	if s.relations == nil || convID == nil || *convID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *convID,
		Kind:      relationdomain.KindCreate,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindHandler, hID,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("handlerapp: sync built edge failed", zap.String("handlerId", hID), zap.Error(err))
	}
}

// syncEditedEdge refreshes the "edit" edge to the active version's conversation (unless
// that's the origin). Recomputed on every active-version change (edit / revert).
func (s *Service) syncEditedEdge(ctx context.Context, hID string) {
	if s.relations == nil {
		return
	}
	h, err := s.repo.GetHandler(ctx, hID)
	if err != nil || h.ActiveVersionID == "" {
		return
	}
	active, err := s.repo.GetVersion(ctx, h.ActiveVersionID)
	if err != nil {
		s.log.Warn("handlerapp: sync edited edge: get active failed", zap.String("handlerId", hID), zap.Error(err))
		return
	}
	editorConv := deref(active.BuiltInConversationID)
	originConv := s.originConvID(ctx, hID)

	var edges []relationdomain.SyncEdge
	if editorConv != "" && editorConv != originConv {
		edges = []relationdomain.SyncEdge{{
			OtherKind: relationdomain.EntityKindConversation,
			OtherID:   editorConv,
			Kind:      relationdomain.KindEdit,
			Attrs:     map[string]any{"versionId": active.ID, "version": active.Version},
		}}
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindHandler, hID,
		[]string{relationdomain.KindEdit}, edges); err != nil {
		s.log.Warn("handlerapp: sync edited edge failed", zap.String("handlerId", hID), zap.Error(err))
	}
}

// purgeRelations hard-deletes every edge touching the handler (called on Delete).
func (s *Service) purgeRelations(ctx context.Context, hID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindHandler, hID); err != nil {
		s.log.Warn("handlerapp: purge relations failed", zap.String("handlerId", hID), zap.Error(err))
	}
}

func (s *Service) originConvID(ctx context.Context, hID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, hID, 1)
	if err != nil {
		return ""
	}
	return deref(v1.BuiltInConversationID)
}

func deref(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
