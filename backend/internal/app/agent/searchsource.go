package agent

import (
	"context"
	"errors"
	"strings"
	"time"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeAgent, id, "")
}

// SearchSource projects an agent: entity card (description/tags/mounts) plus
// the ACTIVE version's prompt split into chunks — the prompt is where an
// agent's real capability is described.
//
// SearchSource 投影 agent：实体卡（描述/tags/挂载）+ **活跃版本** prompt 分块——
// prompt 才是 agent 真实能力的描述所在。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeAgent }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	ags, err := ss.svc.repo.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(ags))
	for _, a := range ags {
		out[a.ID] = a.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	a, err := ss.svc.repo.Get(ctx, id)
	if errors.Is(err, agentdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var card strings.Builder
	card.WriteString(a.Description)
	if len(a.Tags) > 0 {
		card.WriteString("\n" + strings.Join(a.Tags, " "))
	}
	docs := []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: a.Name, Tags: a.Tags, UpdatedAt: a.UpdatedAt,
	}}
	if a.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, a.ActiveVersionID); err == nil {
			if v.Skill != "" {
				card.WriteString("\nskill: " + v.Skill)
			}
			if len(v.Knowledge) > 0 {
				card.WriteString("\nknowledge: " + strings.Join(v.Knowledge, " "))
			}
			for _, t := range v.Tools {
				card.WriteString("\ntool: " + t.Ref + " " + t.Name)
			}
			for i, part := range searchdomain.SplitPlain(v.Prompt) {
				docs = append(docs, searchdomain.SourceDoc{
					ChunkNo: i + 1, Title: a.Name, Body: part, Tags: a.Tags, UpdatedAt: a.UpdatedAt,
				})
			}
		}
	}
	docs[0].Body = searchdomain.CapRunes(card.String())
	return docs, nil
}
