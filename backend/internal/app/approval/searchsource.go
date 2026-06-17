package approval

import (
	"context"
	"errors"
	"strings"
	"time"

	approvaldomain "github.com/sunweilin/anselm/backend/internal/domain/approval"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeApproval, id, "")
}

// SearchSource projects an approval form: card + the ACTIVE version's input
// field names and template body (the human-readable approval prompt).
//
// SearchSource 投影 approval：卡片 + **活跃版本**输入字段名与 template 正文
// （给人看的审批文案）。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeApproval }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	fs, err := ss.svc.repo.ListAllForms(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(fs))
	for _, f := range fs {
		out[f.ID] = f.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	f, err := ss.svc.repo.GetForm(ctx, id)
	if errors.Is(err, approvaldomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var sb strings.Builder
	sb.WriteString(f.Description)
	if f.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, f.ActiveVersionID); err == nil {
			if len(v.Inputs) > 0 {
				names := make([]string, 0, len(v.Inputs))
				for _, fd := range v.Inputs {
					names = append(names, fd.Name+" "+fd.Description)
				}
				sb.WriteString("\ninputs: " + strings.Join(names, "; "))
			}
			if v.Template != "" {
				sb.WriteString("\n" + v.Template)
			}
		}
	}
	return []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: f.Name, Body: searchdomain.CapRunes(sb.String()), UpdatedAt: f.UpdatedAt,
	}}, nil
}
