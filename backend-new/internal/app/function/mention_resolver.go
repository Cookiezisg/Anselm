package function

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

// AsMentionResolver exposes this service as the chat @-mention resolver for functions:
// a reference snapshots the description + active version's code at send time.
//
// AsMentionResolver 把本 service 暴露为 function 的 @ resolver：引用在发送时快照 description
// + active 版本代码。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionFunction }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	fn, err := r.svc.Get(ctx, id) // Get attaches ActiveVersion
	if err != nil {
		return nil, fmt.Errorf("functionapp.mentionResolver.Resolve %s: %w", id, err)
	}
	content := fn.Description
	if fn.ActiveVersion != nil && fn.ActiveVersion.Code != "" {
		if content != "" {
			content += "\n\n"
		}
		content += fn.ActiveVersion.Code
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionFunction, ID: fn.ID, Name: fn.Name, Content: content,
	}, nil
}
