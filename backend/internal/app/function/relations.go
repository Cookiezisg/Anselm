package function

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/anselm/backend/internal/domain/relation"
)

// NamesByIDs implements relationapp.Namer: a batch id→name lookup so the relation graph
// can hydrate display names for function nodes at read time.
//
// NamesByIDs 实现 relationapp.Namer：批量 id→name，供 relation 图读时为 function 节点 hydrate
// 显示名。
func (s *Service) NamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	rows, err := s.repo.GetFunctionsByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string, len(rows))
	for _, f := range rows {
		out[f.ID] = f.Name
	}
	return out, nil
}

// syncBuiltEdge records the "create" edge from the originating conversation to v1.
//
// syncBuiltEdge 记录从原始对话到 v1 的 "create" 边。
func (s *Service) syncBuiltEdge(ctx context.Context, fnID string, convID *string) {
	if s.relations == nil || convID == nil || *convID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *convID,
		Kind:      relationdomain.KindCreate,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindFunction, fnID,
		[]string{relationdomain.KindCreate}, edges); err != nil {
		s.log.Warn("functionapp: sync built edge failed", zap.String("functionId", fnID), zap.Error(err))
	}
}

// syncEditedEdge refreshes the "edit" edge to the active version's conversation, unless
// that conversation is the origin (which already owns the create edge). Recomputed on
// every active-version change (edit / revert).
//
// syncEditedEdge 把 "edit" 边刷到 active 版本的对话，除非该对话即 origin（已有 create 边）。
// 每次 active 变更（edit / revert）重算。
func (s *Service) syncEditedEdge(ctx context.Context, fnID string) {
	if s.relations == nil {
		return
	}
	f, err := s.repo.GetFunction(ctx, fnID)
	if err != nil || f.ActiveVersionID == "" {
		return
	}
	active, err := s.repo.GetVersion(ctx, f.ActiveVersionID)
	if err != nil {
		s.log.Warn("functionapp: sync edited edge: get active failed", zap.String("functionId", fnID), zap.Error(err))
		return
	}
	editorConv := deref(active.BuiltInConversationID)
	originConv := s.originConvID(ctx, fnID)

	var edges []relationdomain.SyncEdge
	if editorConv != "" && editorConv != originConv {
		edges = []relationdomain.SyncEdge{{
			OtherKind: relationdomain.EntityKindConversation,
			OtherID:   editorConv,
			Kind:      relationdomain.KindEdit,
			Attrs:     map[string]any{"versionId": active.ID, "version": active.Version},
		}}
	}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindFunction, fnID,
		[]string{relationdomain.KindEdit}, edges); err != nil {
		s.log.Warn("functionapp: sync edited edge failed", zap.String("functionId", fnID), zap.Error(err))
	}
}

// purgeRelations hard-deletes every edge touching the function (called on Delete).
//
// purgeRelations 硬删触及该 function 的所有边（Delete 时调）。
func (s *Service) purgeRelations(ctx context.Context, fnID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindFunction, fnID); err != nil {
		s.log.Warn("functionapp: purge relations failed", zap.String("functionId", fnID), zap.Error(err))
	}
}

// originConvID returns the conversation that built v1 (empty if v1 was trimmed away).
//
// originConvID 返构建 v1 的对话（v1 已被裁剪则空）。
func (s *Service) originConvID(ctx context.Context, fnID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, fnID, 1)
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
