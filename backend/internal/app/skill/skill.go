// Package skill is the service layer for file-based Agent Skills (memory's kin, not function's).
// It owns discovery (on-demand scan), activation (inline / fork), and authoring (create/edit/
// delete). No execution log, no LLM-backed search — both are abstraction mismatches for a
// file-based instruction carrier.
//
// Package skill 是文件式 Agent Skill 的服务层（memory 的近亲，非 function 的）。负责发现
// （按需扫描）、激活（inline / fork）、创作（create/edit/delete）。无 execution log、无
// LLM 搜索——两者皆与文件式指令载体抽象错配。
package skill

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
)

// Service ties the file repo, fork-dispatch port, notifier, and relation sync together.
//
// Service 把文件 repo、fork 派发端口、通知器、关系同步绑在一起。
type Service struct {
	repo      skilldomain.Repository
	search    searchdomain.Notifier      // nil → search indexing disabled. nil → 不接搜索索引。
	subagent  skilldomain.SubagentRunner // fork 端口；nil → fork 降级 ErrSubagentUnavailable
	emitter   notificationdomain.Emitter // nil → 不发通知（仍持久化）
	relations RelationSyncer             // nil → 不同步关系（best-effort 派生）
	log       *zap.Logger
}

// NewService builds the Service. repo + log are required; subagent / emitter are optional
// (nil-tolerant) so skill works even when the subagent runner and notifier are unwired.
//
// NewService 构造 Service。repo + log 必填；subagent / emitter 可选（nil-tolerant），使
// skill 在 subagent runner 与通知器未接时仍可工作。
func NewService(
	repo skilldomain.Repository,
	subagent skilldomain.SubagentRunner,
	emitter notificationdomain.Emitter,
	log *zap.Logger,
) *Service {
	if repo == nil {
		panic("skillapp.NewService: repo is nil")
	}
	if log == nil {
		panic("skillapp.NewService: log is nil")
	}
	return &Service{repo: repo, subagent: subagent, emitter: emitter, log: log.Named("skillapp")}
}

// Get returns one skill with its full body.
//
// Get 返回单个 skill（含完整 body）。
func (s *Service) Get(ctx context.Context, name string) (*skilldomain.Skill, error) {
	sk, err := s.repo.Get(ctx, name)
	if err != nil {
		return nil, fmt.Errorf("skillapp.Get: %w", err)
	}
	return sk, nil
}

// List returns matching skills (no body). On-demand: the repo rescans the directory each call.
//
// List 返回匹配的 skill（不含 body）。按需：repo 每次现扫目录。
func (s *Service) List(ctx context.Context, filter skilldomain.ListFilter) ([]*skilldomain.Skill, error) {
	rows, err := s.repo.List(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("skillapp.List: %w", err)
	}
	return rows, nil
}

// notify best-effort emits skill.<action>; nil emitter / errors never block the main flow.
//
// notify 尽力发 skill.<action>；nil emitter / 出错均不阻断主流程。
func (s *Service) notify(ctx context.Context, action, name string) {
	s.notifySearch(ctx, name)
	if s.emitter == nil {
		return
	}
	if err := s.emitter.Emit(ctx, "skill."+action, map[string]any{"name": name}); err != nil {
		s.log.Warn("skillapp.notify failed", zap.String("name", name), zap.String("action", action), zap.Error(err))
	}
}
