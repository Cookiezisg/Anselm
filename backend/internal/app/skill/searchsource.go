package skill

import (
	"context"
	"errors"
	"time"

	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
	skilldomain "github.com/sunweilin/foryx/backend/internal/domain/skill"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, name string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeSkill, name, "")
}

// SearchSource projects a skill (entity id = slug name, the file identity):
// card from frontmatter + SKILL.md body split by headings.
//
// SearchSource 投影 skill（entity id = slug 名，即文件身份）：frontmatter 卡片 +
// SKILL.md 正文按标题分块。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeSkill }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	skills, err := ss.svc.repo.List(ctx, skilldomain.ListFilter{})
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(skills))
	for _, sk := range skills {
		out[sk.Name] = sk.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, name string) ([]searchdomain.SourceDoc, error) {
	sk, err := ss.svc.repo.Get(ctx, name)
	if errors.Is(err, skilldomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	card := sk.Description
	if sk.Frontmatter.WhenToUse != "" {
		card += "\n" + sk.Frontmatter.WhenToUse
	}
	out := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: sk.Name, Body: searchdomain.CapRunes(card), UpdatedAt: sk.UpdatedAt,
	}}
	for i, c := range searchdomain.SplitMarkdown(sk.Body) {
		out = append(out, searchdomain.SourceDoc{
			ChunkNo: i + 1, Anchor: c.Anchor, Title: sk.Name, Body: c.Body, UpdatedAt: sk.UpdatedAt,
		})
	}
	return out, nil
}
