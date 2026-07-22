package skill

import (
	"context"
	"fmt"

	mentiondomain "github.com/sunweilin/anselm/backend/internal/domain/mention"
)

// AsMentionResolver exposes this Service as the @-mention resolver for skills (WRK-076): unlike
// a document (a reference), @-mentioning a skill is an ACTIVATION — the resolver renders the
// skill's body (via Guide: ${CLAUDE_SKILL_DIR} + directory preamble, no positional args) as the
// injected snapshot. The pre-authorization side-effect (allowed-tools) is applied separately by
// chat at turn-run time via PreauthorizeActiveSkill (the mention Resolve contract is pure — no
// side effects, so it can't touch agent state). Id = the slug name.
//
// AsMentionResolver 把本 Service 暴露为 skill 的 @ resolver（WRK-076）：不同于 document（引用），
// @ 一个 skill 是**激活**——resolver 渲染 skill body（经 Guide：${CLAUDE_SKILL_DIR} + 目录前导、
// 无位置参数）作为注入快照。预授权副作用（allowed-tools）由 chat 在回合运行时经
// PreauthorizeActiveSkill 另行施加（mention Resolve 契约是纯的、无副作用，碰不到 agent state）。
// id = slug 名。
func (s *Service) AsMentionResolver() mentiondomain.Resolver { return &mentionResolver{svc: s} }

type mentionResolver struct{ svc *Service }

var _ mentiondomain.Resolver = (*mentionResolver)(nil)

func (r *mentionResolver) Type() mentiondomain.MentionType { return mentiondomain.MentionSkill }

func (r *mentionResolver) Resolve(ctx context.Context, id string) (*mentiondomain.Reference, error) {
	sk, err := r.svc.repo.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("skill.mentionResolver.Resolve %s: %w", id, err)
	}
	// Guide renders the body the same way an activation would (directory anchor + preamble),
	// without recording the active skill — that half is chat's PreauthorizeActiveSkill.
	// Guide 按激活同样方式渲 body（目录锚 + 前导），不记 active skill——那半归 chat 的 PreauthorizeActiveSkill。
	content, err := r.svc.Guide(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("skill.mentionResolver.Resolve render %s: %w", id, err)
	}
	return &mentiondomain.Reference{
		Type:    mentiondomain.MentionSkill,
		ID:      sk.Name,
		Name:    sk.Name,
		Content: content,
	}, nil
}
