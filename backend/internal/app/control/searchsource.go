package control

import (
	"context"
	"errors"
	"strings"
	"time"

	controldomain "github.com/sunweilin/foryx/backend/internal/domain/control"
	searchdomain "github.com/sunweilin/foryx/backend/internal/domain/search"
)

// SetSearchNotifier wires the optional write-side search hook (bootstrap).
//
// SetSearchNotifier 接上可选的写侧搜索钩子（bootstrap）。
func (s *Service) SetSearchNotifier(n searchdomain.Notifier) { s.search = n }

func (s *Service) notifySearch(ctx context.Context, id string) {
	searchdomain.Notify(ctx, s.search, searchdomain.TypeControl, id, "")
}

// SearchSource projects a control logic: card + the ACTIVE version's input
// field names and branch CEL expressions — the CEL text is the logic.
//
// SearchSource 投影 control：卡片 + **活跃版本**输入字段名与分支 CEL 表达式——
// CEL 文本即逻辑本体。
func (s *Service) SearchSource() *SearchSource { return &SearchSource{svc: s} }

type SearchSource struct{ svc *Service }

func (ss *SearchSource) Type() searchdomain.EntityType { return searchdomain.TypeControl }

func (ss *SearchSource) Stamps(ctx context.Context) (map[string]time.Time, error) {
	cs, err := ss.svc.repo.ListAllControls(ctx)
	if err != nil {
		return nil, err
	}
	out := make(map[string]time.Time, len(cs))
	for _, c := range cs {
		out[c.ID] = c.UpdatedAt
	}
	return out, nil
}

func (ss *SearchSource) Docs(ctx context.Context, id string) ([]searchdomain.SourceDoc, error) {
	c, err := ss.svc.repo.GetControl(ctx, id)
	if errors.Is(err, controldomain.ErrNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var sb strings.Builder
	sb.WriteString(c.Description)
	if c.ActiveVersionID != "" {
		if v, err := ss.svc.repo.GetVersion(ctx, c.ActiveVersionID); err == nil {
			if len(v.Inputs) > 0 {
				names := make([]string, 0, len(v.Inputs))
				for _, f := range v.Inputs {
					names = append(names, f.Name+" "+f.Description)
				}
				sb.WriteString("\ninputs: " + strings.Join(names, "; "))
			}
			for _, b := range v.Branches {
				sb.WriteString("\n" + b.Port + ": " + b.When)
			}
		}
	}
	return []searchdomain.SourceDoc{{
		ChunkNo: 0, Title: c.Name, Body: searchdomain.CapRunes(sb.String()), UpdatedAt: c.UpdatedAt,
	}}, nil
}
