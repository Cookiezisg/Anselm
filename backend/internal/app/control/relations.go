package control

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// NamesByIDs implements relationapp.Namer: a batch id→name lookup so the relation graph
// can hydrate display names for control nodes at read time.
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供 relation 图读时为 control 节点 hydrate
// 显示名。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetControlsByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, c := range rows {
		out[c.ID] = c.Name
	}
	return out, nil
}

// syncForgedEdge records the "create" edge from the originating conversation to v1.
//
// syncForgedEdge 记录从原始对话到 v1 的 "create" 边。
func (s *Service) syncForgedEdge(ctx context.Context, ctlID string, convID *string) {
	if s.relations == nil || convID == nil || *convID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *convID,
		Kind:      relationdomain.KindCreate,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindControl, ctlID,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("controlapp: sync forged edge failed", zap.String("controlId", ctlID), zap.Error(err))
	}
}

// syncEditedEdge refreshes the "edit" edge to the active version's conversation, unless
// that conversation is the origin (which already owns the create edge). Recomputed on
// every active-version change (edit / revert).
//
// syncEditedEdge 把 "edit" 边刷到 active 版本的对话，除非该对话即 origin（已有 create 边）。
// 每次 active 变更（edit / revert）重算。
func (s *Service) syncEditedEdge(ctx context.Context, ctlID string) {
	if s.relations == nil {
		return
	}
	c, err := s.repo.GetControl(ctx, ctlID)
	if err != nil || c.ActiveVersionID == "" {
		return
	}
	active, err := s.repo.GetVersion(ctx, c.ActiveVersionID)
	if err != nil {
		s.log.Warn("controlapp: sync edited edge: get active failed", zap.String("controlId", ctlID), zap.Error(err))
		return
	}
	editorConv := deref(active.ForgedInConversationID)
	originConv := s.originConvID(ctx, ctlID)

	var edges []relationdomain.SyncEdge
	if editorConv != "" && editorConv != originConv {
		edges = []relationdomain.SyncEdge{{
			OtherKind: relationdomain.EntityKindConversation,
			OtherID:   editorConv,
			Kind:      relationdomain.KindEdit,
			Attrs:     map[string]any{"versionId": active.ID, "version": active.Version},
		}}
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindControl, ctlID,
		[]string{relationdomain.KindEdit}, edges); err != nil {
		s.log.Warn("controlapp: sync edited edge failed", zap.String("controlId", ctlID), zap.Error(err))
	}
}

// purgeRelations hard-deletes every edge touching the control logic (called on Delete).
//
// purgeRelations 硬删触及该 control 逻辑的所有边（Delete 时调）。
func (s *Service) purgeRelations(ctx context.Context, ctlID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindControl, ctlID); err != nil {
		s.log.Warn("controlapp: purge relations failed", zap.String("controlId", ctlID), zap.Error(err))
	}
}

// originConvID returns the conversation that forged v1 (empty if v1 was trimmed away).
//
// originConvID 返锻造 v1 的对话（v1 已被裁剪则空）。
func (s *Service) originConvID(ctx context.Context, ctlID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, ctlID, 1)
	if err != nil {
		return ""
	}
	return deref(v1.ForgedInConversationID)
}

func deref(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
