package search

import (
	"context"
	"strings"

	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

const (
	retrieveDefaultTopK = 6
	retrieveMaxTopK     = 20
)

// Retrieve is the RAG surface: the same hybrid pipeline as Search but
// chunk-grained and unfolded, with full bodies hydrated — callers inject the
// chunks as context. Vectors present = hybrid, absent = lexical; callers never
// know nor care.
//
// Retrieve 是 RAG 出口：与 Search 同一条混合管线，但 chunk 粒度、不折叠、
// 补全文 body——调用方把块注入上下文。向量在场即混合、缺席即词法；调用方无感知。
func (s *Service) Retrieve(ctx context.Context, q string, opts searchdomain.RetrieveOpts) ([]searchdomain.Chunk, error) {
	if strings.TrimSpace(q) == "" {
		return nil, searchdomain.ErrQueryRequired
	}
	for _, t := range opts.Types {
		if !searchdomain.IsValidEntityType(t) {
			return nil, searchdomain.ErrTypeInvalid
		}
	}
	topK := opts.TopK
	if topK <= 0 {
		topK = retrieveDefaultTopK
	}
	if topK > retrieveMaxTopK {
		topK = retrieveMaxTopK
	}

	parsed := searchdomain.ParseQuery(q)
	lex, err := s.repo.SearchLexical(ctx, searchdomain.LexicalQuery{
		LongTokens:      parsed.Long,
		ShortTokens:     parsed.Short,
		Types:           opts.Types,
		IncludeArchived: true,
		Limit:           fusionWindow,
	})
	if err != nil {
		return nil, err
	}
	fused := s.fuseSemantic(ctx, &searchdomain.Query{Q: q, Types: opts.Types, IncludeArchived: true}, lex)
	if len(fused) > topK {
		fused = fused[:topK]
	}

	ids := make([]string, 0, len(fused))
	for _, dh := range fused {
		ids = append(ids, dh.DocID)
	}
	bodies, err := s.repo.BodiesByIDs(ctx, ids)
	if err != nil {
		return nil, err
	}
	budget := opts.MaxChars
	out := make([]searchdomain.Chunk, 0, len(fused))
	for _, dh := range fused {
		body := bodies[dh.DocID]
		if budget > 0 {
			r := []rune(body)
			if len(r) > budget {
				body = string(r[:budget])
			}
			budget -= len([]rune(body))
		}
		out = append(out, searchdomain.Chunk{
			EntityType: dh.EntityType,
			EntityID:   dh.EntityID,
			Anchor:     dh.Anchor,
			Title:      dh.Title,
			Body:       body,
			Score:      dh.Score,
		})
		if opts.MaxChars > 0 && budget <= 0 {
			break
		}
	}
	return out, nil
}
