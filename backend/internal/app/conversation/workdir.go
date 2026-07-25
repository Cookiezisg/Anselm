package conversation

import (
	"context"
	"os"

	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	gitinfoinfra "github.com/sunweilin/anselm/backend/internal/infra/gitinfo"

	"go.uber.org/zap"
)

// WorkDirMarker is the chat-side hook for the residency's durable in-line mark (chatapp.Service
// satisfies it, injected post-build like canceler / querier). It exists because the marker is a
// `message_blocks` row and MESSAGES BELONG TO CHAT — conversation owns the thread record, not its
// content, so writing the block here would be this layer reaching into another's table.
//
// A DIP port rather than a direct call for the usual reason: chatapp already depends on
// conversationapp (it reads the head every turn), so the reverse edge must be an interface or the
// packages cycle.
//
// WorkDirMarker 是驻地持久行内标记的 chat 侧钩子（chatapp.Service 满足它，与 canceler / querier 同款
// 后注入）。它存在是因为标记是一条 `message_blocks` 行,而**消息归 chat**——conversation 拥有线程记录、
// 不拥有它的内容,在此写那个块等于本层伸手进别人的表。
//
// 用 DIP 端口而非直接调用是老理由:chatapp 本就依赖 conversationapp（每回合读头行）,故反向边必须是
// 接口、否则两包成环。
type WorkDirMarker interface {
	MarkWorkDirSwitch(ctx context.Context, conversationID, from, to string) error
}

// SetWorkDirMarker injects the chat hook (post-build wiring, breaking the chat↔conversation cycle).
// nil → a residency switch simply leaves no mark.
//
// SetWorkDirMarker 注入 chat 钩子（后注入，破 chat↔conversation 环）。nil → 切换驻地只是不留标记。
func (s *Service) SetWorkDirMarker(m WorkDirMarker) { s.workDirMarker = m }

// markWorkDirSwitch drops the durable in-line mark for a mid-thread residency change. Best-effort and
// deliberately so: the residency itself is already persisted on the row, and refusing the user's
// switch because a decorative mark failed to write would be the tail wagging the dog.
//
// markWorkDirSwitch 为线程中途的驻地变更落下持久行内标记。best-effort 且刻意如此:驻地本身已经落在行上,
// 因为一条装饰性标记没写成而拒掉用户的切换是本末倒置。
func (s *Service) markWorkDirSwitch(ctx context.Context, conversationID, from, to string) {
	if s.workDirMarker == nil {
		return
	}
	if err := s.workDirMarker.MarkWorkDirSwitch(ctx, conversationID, from, to); err != nil {
		s.log.Warn("conversationapp.markWorkDirSwitch: failed (non-fatal)",
			zap.String("conversationId", conversationID), zap.Error(err))
	}
}

// WorkDirInfo computes the residency's live projection for one conversation (`GET /{id}/workdir`).
// Nothing is cached: the filesystem and git are the truth, and a conversation whose directory the user
// just deleted — or whose branch they just switched in their own terminal — must read as it now IS.
//
// An unmounted thread returns the zero projection (empty path, exists=false) rather than a 404: "this
// conversation has no residency" is a successful answer to the question, and the button that calls this
// needs to render the unmounted state too.
//
// The git probe runs ONLY when the directory exists and only once (a single `git status --porcelain=v2
// --branch`), so the cost of an unmounted or missing residency is one os.Stat.
//
// WorkDirInfo 现算某对话驻地的活投影（`GET /{id}/workdir`）。零缓存:文件系统与 git 才是真相,用户刚删掉
// 目录的对话——或刚在自己终端里切了分支的对话——必须读作它**现在的样子**。
//
// 未挂线程返回零投影（空路径、exists=false）而**不是** 404:「这个对话没有驻地」是对该问题的一个**成功**
// 回答,而调用它的那个按钮也要渲染未挂态。
//
// git 探针**仅在**目录存在时跑、且只跑一次（一次 `git status --porcelain=v2 --branch`）,故未挂或已消失的
// 驻地只花一次 os.Stat。
func (s *Service) WorkDirInfo(ctx context.Context, id string) (*conversationdomain.WorkDirInfo, error) {
	c, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	info := &conversationdomain.WorkDirInfo{Path: c.WorkDir}
	if c.WorkDir == "" {
		return info, nil
	}
	// A regular FILE at the path is not a residency either — Exists means "usable as a work dir".
	// 路径上是普通**文件**同样不算驻地——Exists 意为「可作工作目录用」。
	st, statErr := os.Stat(c.WorkDir)
	info.Exists = statErr == nil && st.IsDir()
	if !info.Exists {
		return info, nil
	}
	branch, dirty, isRepo := gitinfoinfra.Status(ctx, c.WorkDir)
	info.IsGitRepo, info.Branch, info.Dirty = isRepo, branch, dirty
	return info, nil
}
