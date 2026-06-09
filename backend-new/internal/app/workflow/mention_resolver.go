package workflow

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

// AsMentionResolver exposes this service as the chat @-mention resolver for workflows: an
// @-reference snapshots the workflow's name + description at send time (the orchestration graph
// itself isn't inlined — the description tells the model what the workflow does).
//
// AsMentionResolver 把本 service 暴露为 workflow 的 @ resolver：@ 引用在发送时快照 workflow 的
// name + description（编排图本身不内联——description 告诉模型这个 workflow 干什么）。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

var _ mentiondomain.Resolver = (*mentionResolver)(nil)

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionWorkflow }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	wf, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.mentionResolver.Resolve %s: %w", id, err)
	}
	return &mentiondomain.Reference{
		Type:    mentiondomain.MentionWorkflow,
		ID:      wf.ID,
		Name:    wf.Name,
		Content: wf.Description,
	}, nil
}
