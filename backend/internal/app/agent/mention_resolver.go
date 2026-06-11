package agent

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/forgify/backend/internal/domain/mention"
)

// AsMentionResolver exposes this service as the chat @-mention resolver for agents: an
// @-reference snapshots the agent's name + description at send time (what this configured LLM
// worker is for), so the model can talk about / hand off to it.
//
// AsMentionResolver 把本 service 暴露为 agent 的 @ resolver：@ 引用在发送时快照 agent 的 name +
// description（这个配置好的 LLM worker 是干什么的），使模型能谈及 / 转交给它。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

var _ mentiondomain.Resolver = (*mentionResolver)(nil)

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionAgent }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	a, err := r.svc.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("agentapp.mentionResolver.Resolve %s: %w", id, err)
	}
	return &mentiondomain.Reference{
		Type:    mentiondomain.MentionAgent,
		ID:      a.ID,
		Name:    a.Name,
		Content: a.Description,
	}, nil
}
