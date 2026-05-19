package function

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
)

// RelationSyncer is the subset of relationapp.Service function consumes (nil-tolerant).
//
// RelationSyncer 是 function 消费的 relationapp.Service 子集（允许 nil）。
type RelationSyncer interface {
	SyncIncoming(ctx context.Context, toKind, toID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// syncRelationsAfterActiveVersionChange writes/refreshes the edited edge based on
// the function's ActiveVersionID. Suppresses if editor==origin.
//
// syncRelationsAfterActiveVersionChange 按 ActiveVersionID 写/刷 edited 边；editor==origin 时 suppress。
func (s *Service) syncRelationsAfterActiveVersionChange(ctx context.Context, fnID string) {
	if s.relations == nil {
		return
	}
	f, err := s.repo.GetFunction(ctx, fnID)
	if err != nil || f == nil || f.ActiveVersionID == "" {
		return
	}
	activeV, err := s.repo.GetVersion(ctx, f.ActiveVersionID)
	if err != nil || activeV == nil {
		s.log.Warn("relation sync: get active version failed",
			zap.String("functionId", fnID), zap.Error(err))
		return
	}

	editorConv := stringDeref(activeV.ForgedInConversationID)
	originConv := s.getOriginConvID(ctx, fnID)
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
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindFunction, fnID,
		[]string{relationdomain.KindConversationEditedEntity}, editedEdges); err != nil {
		s.log.Warn("relation SyncIncoming (edited) failed",
			zap.String("functionId", fnID), zap.Error(err))
	}
}

// syncRelationsAfterCreate writes v1's forged edge.
//
// syncRelationsAfterCreate 写 v1 的 forged 边。
func (s *Service) syncRelationsAfterCreate(ctx context.Context, fnID string, v1ConvID *string) {
	if s.relations == nil || v1ConvID == nil || *v1ConvID == "" {
		return
	}
	edges := []relationdomain.SyncEdge{{
		OtherKind: relationdomain.EntityKindConversation,
		OtherID:   *v1ConvID,
		Kind:      relationdomain.KindConversationForgedEntity,
	}}
	if err := s.relations.SyncIncoming(ctx, relationdomain.EntityKindFunction, fnID,
		[]string{relationdomain.KindConversationForgedEntity}, edges); err != nil {
		s.log.Warn("relation SyncIncoming (forged) failed",
			zap.String("functionId", fnID), zap.Error(err))
	}
}

func (s *Service) purgeRelations(ctx context.Context, fnID string) {
	if s.relations == nil {
		return
	}
	if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindFunction, fnID); err != nil {
		s.log.Warn("relation PurgeEntity failed",
			zap.String("functionId", fnID), zap.Error(err))
	}
}

func (s *Service) getOriginConvID(ctx context.Context, fnID string) string {
	v1, err := s.repo.GetVersionByNumber(ctx, fnID, 1)
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

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.FunctionReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.FunctionReader。
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
