package trigger

import (
	"context"
	"errors"
	"strings"
	"time"

	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
	triggerdomain "github.com/sunweilin/foryx/backend/internal/domain/trigger"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeTrigger, id, "")
}

// SearchSource projects a trigger: name/description/kind/output field names.
// Config is NEVER projected — webhook/sensor configs can carry secrets, and the
// security red line outranks cron-expression searchability.
//
// SearchSource 投影 trigger：名/描述/kind/输出字段名。Config **永不投影**——
// webhook/sensor 配置可能含 secret，安全红线压过 cron 表达式的可检索性。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeTrigger }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	ts, err := ss.svc.repo.ListAllTriggers(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(ts))
	for _, t := range ts {
		out[t.ID] = t.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	t, err := ss.svc.repo.GetTrigger(ctx, id)
	if errors.Is(err, triggerdomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var sb strings.Builder
	sb.WriteString(t.Description)
	sb.WriteString("\nkind: " + t.Kind)
	if len(t.Outputs) > 0 {
		names := make([]string, 0, len(t.Outputs))
		for _, f := range t.Outputs {
			names = append(names, f.Name+" "+f.Description)
		}
		sb.WriteString("\noutputs: " + strings.Join(names, "; "))
	}
	return []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: t.Name, Body: searchdomain.CapRunes(sb.String()), UpdatedAt: t.UpdatedAt,
	}}, nil
}
