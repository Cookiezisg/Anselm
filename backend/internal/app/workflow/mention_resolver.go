package workflow

import (
	"context"
	"encoding/json"
	"fmt"

	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
)

// AsMentionResolver exposes this service as the chat @-mention resolver for workflows: an
// @-reference snapshots the workflow's description and active graph at send time. The graph is
// part of the workflow's user-facing definition; omitting it makes an @-mention insufficient for
// an AI edit conversation to understand what it is changing.
//
// AsMentionResolver 把本 service 暴露为 workflow 的 @ resolver：@ 引用在发送时快照 workflow 的
// description + active graph。图是 workflow 面向用户的定义；省略它会让 AI 编辑对话无法理解自己要改什么。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

var _ mentiondomain.Resolver = (*mentionResolver)(nil)

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionWorkflow }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	wf, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("workflowapp.mentionResolver.Resolve %s: %w", id, err)
	}
	content := wf.Description
	if wf.ActiveVersion != nil {
		if wf.ActiveVersion.GraphParsed == nil {
			return nil, fmt.Errorf("workflowapp.mentionResolver.Resolve %s: active graph is unavailable", id)
		}
		graph, err := json.MarshalIndent(wf.ActiveVersion.GraphParsed, "", "  ")
		if err != nil {
			return nil, fmt.Errorf("workflowapp.mentionResolver.Resolve %s: marshal active graph: %w", id, err)
		}
		content += fmt.Sprintf(
			"\n\nActive graph (version %d, versionId %s):\n%s",
			wf.ActiveVersion.Version,
			wf.ActiveVersion.ID,
			graph,
		)
	}
	return &mentiondomain.Reference{
		Type:    mentiondomain.MentionWorkflow,
		ID:      wf.ID,
		Name:    wf.Name,
		Content: content,
	}, nil
}
