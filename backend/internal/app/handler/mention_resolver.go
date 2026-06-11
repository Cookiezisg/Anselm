package handler

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

// AsMentionResolver exposes this service as the chat @-mention resolver for handlers: a
// reference snapshots the description + the assembled class interface at send time.
//
// AsMentionResolver 把本 service 暴露为 handler 的 @ resolver：引用在发送时快照 description +
// 组装出的类接口。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionHandler }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	h, err := r.svc.Get(ctx, id) // Get attaches ActiveVersion
	if err != nil {
		return nil, fmt.Errorf("handlerapp.mentionResolver.Resolve %s: %w", id, err)
	}
	content := h.Description
	if h.ActiveVersion != nil {
		classCode := AssembleClass(activeToDraft(h.ActiveVersion))
		if content != "" {
			content += "\n\n"
		}
		content += classCode
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionHandler, ID: h.ID, Name: h.Name, Content: content,
	}, nil
}
