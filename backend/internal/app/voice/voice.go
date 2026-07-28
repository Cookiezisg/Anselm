// Package voice is the app service for cloned voices (WRK-082 H9): list what exists, and delete
// one — the management face without which the inventory is a trap. Enrollment itself lives in the
// generate tool (it needs the router and the source bytes); this service owns the two operations a
// USER performs directly.
//
// **Deletion is upstream-first, and that ordering is the whole service.** The row is the only
// thing holding the upstream id, so removing it first would strand a registration nobody can name,
// see or reclaim — while it keeps occupying the inventory slot the user was trying to free.
//
// Package voice 是克隆音色的 app 服务(H9):列出有什么、删掉一个——**没有它,那个库存就是个陷阱**。
// 登记本身住在 generate 工具里(它要 router 与源字节);本服务拥有的是**用户直接执行**的那两个操作。
//
// **删除是「先上游、后行」,而这个顺序就是本服务的全部。** 行是唯一持有上游 id 的东西,故先删行会让一个
// 登记搁浅——谁也叫不出它的名、看不见它、收不回它,而它还继续占着用户正想腾出的那个库存位。
package voice

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
)

// Deleter is the upstream port (satisfied by *generate.Router).
//
// Deleter 是上游端口(由 *generate.Router 满足)。
type Deleter interface {
	DeleteVoice(ctx context.Context, provider, upstreamID string) error
}

// Service lists and deletes voices.
//
// Service 列出与删除音色。
type Service struct {
	repo     voicedomain.Repository
	upstream Deleter
	log      *zap.Logger
}

// New builds the service.
//
// New 构造服务。
func New(repo voicedomain.Repository, upstream Deleter, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{repo: repo, upstream: upstream, log: log}
}

// List returns the workspace's voices, newest first. Bounded by the inventory cap, so no cursor.
//
// List 返回本 workspace 的音色,新的在前。受库存上限约束,故无游标。
func (s *Service) List(ctx context.Context) ([]*voicedomain.Voice, error) {
	return s.repo.List(ctx)
}

// Delete removes the upstream registration and then the row.
//
// An upstream failure ABORTS: the row stays, the user can retry, and the inventory count keeps
// telling the truth. Deleting the row anyway would "succeed" while leaving a paid registration
// alive on someone else's servers, invisible forever — the failure mode this ordering exists to
// prevent, so it must not be papered over with a warning log.
//
// Delete 先删上游登记、再删行。
//
// 上游失败即**中止**:行留着、用户可重试、库存计数继续说真话。照删不误会「成功」,却在别人的服务器上
// 留下一个还活着、已付费、**永远不可见**的登记——那正是这个顺序所要防的失败,故它绝不能被一条 warn
// 日志糊过去。
func (s *Service) Delete(ctx context.Context, id string) error {
	all, err := s.repo.List(ctx)
	if err != nil {
		return err
	}
	var target *voicedomain.Voice
	for _, v := range all {
		if v.ID == id {
			target = v
			break
		}
	}
	if target == nil {
		return voicedomain.ErrNotFound
	}
	if err := s.upstream.DeleteVoice(ctx, target.Provider, target.UpstreamID); err != nil {
		return fmt.Errorf("voice.Delete: upstream registration %s survives, row kept: %w",
			target.UpstreamID, err)
	}
	return s.repo.Delete(ctx, id)
}
