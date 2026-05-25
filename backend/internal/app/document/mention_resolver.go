package document

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

type mentionResolver struct{ svc *Service }

// AsMentionResolver exposes this service as a chat @-mention resolver for documents.
//
// AsMentionResolver 把本 service 暴露为 document 的 @ resolver。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionDocument }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	d, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("document.mentionResolver.Resolve %s: %w", id, err)
	}
	content := d.Description
	if d.Content != "" {
		if content != "" {
			content += "\n\n"
		}
		content += d.Content
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionDocument, ID: d.ID, Name: d.Name, Content: content,
	}, nil
}
