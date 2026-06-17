package document

import (
	"context"
	"errors"
	"strings"
	"time"

	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeDocument, id, "")
}

// SearchSource projects a document: card (name/path/description/tags) +
// heading-aware content chunks (anchor = heading chain, the jump target).
//
// SearchSource 投影 document：卡片（名/路径/描述/tags）+ 标题感知的内容分块
// （anchor=标题链，即跳转锚）。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeDocument }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	docs, err := ss.svc.repo.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(docs))
	for _, d := range docs {
		out[d.ID] = d.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	d, err := ss.svc.repo.Get(ctx, id)
	if errors.Is(err, documentdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	card := d.Description
	if d.Path != "" {
		card += "\n" + d.Path
	}
	if len(d.Tags) > 0 {
		card += "\n" + strings.Join(d.Tags, " ")
	}
	out := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: d.Name, Body: searchdomain.CapRunes(card), Tags: d.Tags, UpdatedAt: d.UpdatedAt,
	}}
	for i, c := range searchdomain.SplitMarkdown(d.Content) {
		out = append(out, searchdomain.SourceDoc{
			ChunkNo: i + 1, Anchor: c.Anchor, Title: d.Name, Body: c.Body, Tags: d.Tags, UpdatedAt: d.UpdatedAt,
		})
	}
	return out, nil
}
