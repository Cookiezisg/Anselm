package memory

import (
	"context"
	"errors"
	"time"

	memorydomain "github.com/sunweilin/foryx/backend/internal/domain/memory"
	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, name string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeMemory, name, "")
}

// SearchSource projects a memory (entity id = slug name): one row, description
// + content — "我记得存过关于 X 的记忆" is exactly a search query.
//
// SearchSource 投影 memory（entity id = slug 名）：单行，描述 + 正文——
// 「我记得存过关于 X 的记忆」本身就是一句检索。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeMemory }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	ms, err := ss.svc.repo.List(ctx, memorydomain.ListFilter{})
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(ms))
	for _, m := range ms {
		out[m.Name] = m.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, name string) ([]searchdomain.SourceDoc, error) {
	m, err := ss.svc.repo.Get(ctx, name)
	if errors.Is(err, memorydomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return []searchdomain.SourceDoc{{
		ChunkNo:   0,
		Title:     m.Name,
		Body:      searchdomain.CapRunes(m.Description + "\n" + m.Content),
		UpdatedAt: m.UpdatedAt,
	}}, nil
}
