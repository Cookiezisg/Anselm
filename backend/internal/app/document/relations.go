package document

import (
	"context"

	"go.uber.org/zap"

	relationdomain "github.com/sunweilin/forgify/backend/internal/domain/relation"
	wikilinkpkg "github.com/sunweilin/forgify/backend/internal/pkg/wikilink"
)

// RelationSyncer is the subset of relationapp.Service document consumes (nil-tolerant).
type RelationSyncer interface {
	SyncOutgoing(ctx context.Context, fromKind, fromID string,
		kindScope []string, edges []relationdomain.SyncEdge) error
	PurgeEntity(ctx context.Context, kind, id string) error
}

// syncRelationsForDocumentBody parses wikilinks in body and re-syncs document_links_entity edges.
//
// syncRelationsForDocumentBody 解析 body 中 wikilink 并重 sync document_links_entity 边。
func (s *Service) syncRelationsForDocumentBody(ctx context.Context, docID, body string) {
	if s.relations == nil {
		return
	}
	refs := wikilinkpkg.Parse(body)
	edges := make([]relationdomain.SyncEdge, 0, len(refs))
	for _, ref := range refs {
		// Skip self-links — document body referencing itself wouldn't be a useful edge
		if ref.Kind == relationdomain.EntityKindDocument && ref.ID == docID {
			continue
		}
		edges = append(edges, relationdomain.SyncEdge{
			OtherKind: ref.Kind,
			OtherID:   ref.ID,
			Kind:      relationdomain.KindDocumentLinksEntity,
			Attrs:     map[string]any{"count": ref.Count},
		})
	}
	if err := s.relations.SyncOutgoing(ctx, relationdomain.EntityKindDocument, docID,
		[]string{relationdomain.KindDocumentLinksEntity}, edges); err != nil {
		s.log.Warn("relation SyncOutgoing (doc_links) failed",
			zap.String("documentId", docID), zap.Error(err))
	}
}

// purgeRelationsForDocuments cascades edges on document deletion (used by SoftDeleteSubtree).
//
// purgeRelationsForDocuments 文档删除时级联清边（SoftDeleteSubtree 用）。
func (s *Service) purgeRelationsForDocuments(ctx context.Context, docIDs []string) {
	if s.relations == nil {
		return
	}
	for _, id := range docIDs {
		if err := s.relations.PurgeEntity(ctx, relationdomain.EntityKindDocument, id); err != nil {
			s.log.Warn("relation PurgeEntity failed",
				zap.String("documentId", id), zap.Error(err))
		}
	}
}

// ListAllMeta returns slim metas for relgraph node assembly. Implements relationapp.DocumentReader.
//
// ListAllMeta 给 relgraph 节点组装返精简 meta。实现 relationapp.DocumentReader。
func (s *Service) ListAllMeta(ctx context.Context, _ string) ([]relationdomain.EntityMeta, error) {
	rows, err := s.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	out := make([]relationdomain.EntityMeta, 0, len(rows))
	for _, r := range rows {
		out = append(out, relationdomain.EntityMeta{ID: r.ID, Label: r.Name, Sub: r.Path})
	}
	return out, nil
}
