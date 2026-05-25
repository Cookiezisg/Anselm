package handler

import (
	"context"
	"fmt"
	"strings"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

type mentionResolver struct{ svc *Service }

// AsMentionResolver exposes this service as a chat @-mention resolver for handlers.
//
// AsMentionResolver 把本 service 暴露为 handler 的 @ resolver。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionHandler }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	hd, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("handler.mentionResolver.Resolve %s: %w", id, err)
	}
	var b strings.Builder
	b.WriteString(hd.Description)
	if hd.ActiveVersionID != "" {
		if v, err := r.svc.GetVersion(ctx, hd.ActiveVersionID); err == nil {
			if len(v.InitArgsSchema) > 0 {
				b.WriteString("\n\ninit args:")
				for _, a := range v.InitArgsSchema {
					fmt.Fprintf(&b, "\n- %s (%s)", a.Name, a.Type)
				}
			}
			if len(v.Methods) > 0 {
				b.WriteString("\n\nmethods:")
				for _, m := range v.Methods {
					fmt.Fprintf(&b, "\n- %s", m.Name)
				}
			}
		}
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionHandler, ID: hd.ID, Name: hd.Name, Content: b.String(),
	}, nil
}
