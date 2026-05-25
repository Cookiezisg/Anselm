package workflow

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

type mentionResolver struct{ svc *Service }

// AsMentionResolver exposes this service as a chat @-mention resolver for workflows.
//
// AsMentionResolver 把本 service 暴露为 workflow 的 @ resolver。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionWorkflow }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	w, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflow.mentionResolver.Resolve %s: %w", id, err)
	}
	content := w.Description
	if w.ActiveVersionID != "" {
		if v, err := r.svc.GetVersion(ctx, w.ActiveVersionID); err == nil && v.Graph != "" {
			if content != "" {
				content += "\n\n"
			}
			content += v.Graph // 完整 frozen JSON 定义（nodes/edges）
		}
	}
	return &mentiondomain.Reference{
		Type: mentiondomain.MentionWorkflow, ID: w.ID, Name: w.Name, Content: content,
	}, nil
}
