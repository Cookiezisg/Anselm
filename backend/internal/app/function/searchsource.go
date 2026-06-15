package function

import (
	"context"
	"errors"
	"strings"
	"time"

	functiondomain "github.com/sunweilin/foryx/backend/internal/domain/function"
	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
	schemapkg "github.com/sunweilin/foryx/backend/internal/pkg/schema"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

// notifySearch marks this function dirty for the search index (nil-safe).
//
// notifySearch 把该 function 标脏给搜索索引（nil 安全）。
func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeFunction, id, "")
}

// SearchSource exposes the function projection for the search indexer: chunk 0
// is the entity card (name/description/tags/IO fields), following chunks are
// the ACTIVE version's code — search serves "blocks usable now", never
// historical versions.
//
// SearchSource 暴露 function 投影给搜索索引器：chunk 0 是实体卡片（名/描述/tags/
// 出入参），后续 chunk 是**活跃版本**代码——搜索面向「现在可用的积木」，从不索历史版本。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeFunction }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	fns, err := ss.svc.repo.ListAllFunctions(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(fns))
	for _, f := range fns {
		out[f.ID] = f.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	f, err := ss.svc.repo.GetFunction(ctx, id)
	if errors.Is(err, functiondomain.ErrNotFound) {
		return nil, nil // gone → delete from index. 已无 → 从索引删。
	}
	if err != nil {
		return nil, err
	}
	var card strings.Builder
	card.WriteString(f.Description)
	if len(f.Tags) > 0 {
		card.WriteString("\n" + strings.Join(f.Tags, " "))
	}
	docs := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: f.Name, Tags: f.Tags, UpdatedAt: f.UpdatedAt,
	}}
	if f.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, f.ActiveVersionID); err == nil {
			card.WriteString("\n" + fieldNames("inputs", v.Inputs) + "\n" + fieldNames("outputs", v.Outputs))
			for i, part := range searchdomain.SplitPlain(v.Code) {
				docs = append(docs, searchdomain.SourceDoc{
					ChunkNo: i + 1, Title: f.Name, Body: part, Tags: f.Tags, UpdatedAt: f.UpdatedAt,
				})
			}
		}
	}
	docs[0].Body = searchdomain.CapRunes(card.String())
	return docs, nil
}

// fieldNames flattens an IO field list into searchable text.
//
// fieldNames 把出入参字段列表拍平成可检索文本。
func fieldNames(label string, fields []schemapkg.Field) string {
	if len(fields) == 0 {
		return ""
	}
	parts := make([]string, 0, len(fields))
	for _, f := range fields {
		parts = append(parts, f.Name+" "+f.Description)
	}
	return label + ": " + strings.Join(parts, "; ")
}
