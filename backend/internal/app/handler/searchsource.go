package handler

import (
	"context"
	"errors"
	"strings"
	"time"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	schemapkg "github.com/sunweilin/forgify/backend/internal/pkg/schema"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeHandler, id, "")
}

// SearchSource projects a handler as one entity card + ONE ROW PER METHOD
// (anchor = method name) — the block palette's hit unit is the callable
// method, not the class shell.
//
// SearchSource 把 handler 投影为一张实体卡 + **每方法一行**（anchor=方法名）——
// 积木面板的命中单元是可调用方法，不是类壳。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeHandler }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	hs, err := ss.svc.repo.ListAllHandlers(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(hs))
	for _, h := range hs {
		out[h.ID] = h.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	h, err := ss.svc.repo.GetHandler(ctx, id)
	if errors.Is(err, handlerdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	card := h.Description
	if len(h.Tags) > 0 {
		card += "\n" + strings.Join(h.Tags, " ")
	}
	docs := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: h.Name, Tags: h.Tags, UpdatedAt: h.UpdatedAt,
	}}
	if h.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, h.ActiveVersionID); err == nil {
			for i, m := range v.Methods {
				docs = append(docs, searchdomain.SourceDoc{
					ChunkNo:   i + 1,
					Anchor:    m.Name,
					Title:     h.Name + "." + m.Name,
					Body:      searchdomain.CapRunes(methodText(m)),
					Tags:      h.Tags,
					UpdatedAt: h.UpdatedAt,
				})
			}
		}
	}
	docs[0].Body = searchdomain.CapRunes(card)
	return docs, nil
}

// methodText flattens one method into searchable text: description, IO fields,
// then the body code (trigram makes code substrings searchable).
//
// methodText 把一个方法拍平成可检索文本：描述、出入参、再方法体代码（trigram 使
// 代码子串可搜）。
func methodText(m handlerdomain.MethodSpec) string {
	var sb strings.Builder
	sb.WriteString(m.Description)
	join := func(label string, fs []schemapkg.Field) {
		if len(fs) == 0 {
			return
		}
		parts := make([]string, 0, len(fs))
		for _, f := range fs {
			parts = append(parts, f.Name+" "+f.Description)
		}
		sb.WriteString("\n" + label + ": " + strings.Join(parts, "; "))
	}
	join("inputs", m.Inputs)
	join("outputs", m.Outputs)
	if m.Body != "" {
		sb.WriteString("\n" + m.Body)
	}
	return sb.String()
}
