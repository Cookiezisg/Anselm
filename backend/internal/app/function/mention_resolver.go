package function

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

type mentionResolver struct{ svc *Service }

// AsMentionResolver exposes this service as a chat @-mention resolver for functions.
//
// AsMentionResolver 把本 service 暴露为 function 的 @ resolver。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionFunction }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	fn, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("function.mentionResolver.Resolve %s: %w", id, err)
	}
	content := fn.Description
	if fn.ActiveVersionID != "" {
		if v, err := r.svc.GetVersion(ctx, fn.ActiveVersionID); err == nil && v.Code != "" {
			if content != "" {
				content += "\n\n"
			}
			content += v.Code
		}
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionFunction, ID: fn.ID, Name: fn.Name, Content: content,
	}, nil
}
