// Package trigger (app layer) integrates the four V1 trigger listener
// kinds (cron / fsnotify / webhook / manual) behind one Service surface.
// Workflow accept/revert/delete events drive Register / Unregister calls;
// listener firings turn into scheduler.StartRun via the SchedulerStarter
// port.
//
// Manual triggers have no listener — HTTP `POST /workflows/{id}:trigger`
// and the LLM `trigger_workflow` tool call SchedulerStarter directly.
// Service tracks them via specs registry only (for State observability).
//
// Plan 05 §2 + §6.12.
//
// Package trigger(app 层)整合 4 种 listener。无 listener 的 manual 触发由
// HTTP / LLM 工具直接调 SchedulerStarter;Service 仅在 specs 表注册便于 State
// 观测。
package trigger

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"sync"

	"go.uber.org/zap"

	triggerdomain "github.com/sunweilin/forgify/backend/internal/domain/trigger"
	croninfra "github.com/sunweilin/forgify/backend/internal/infra/trigger/cron"
	fsnotifyinfra "github.com/sunweilin/forgify/backend/internal/infra/trigger/fsnotify"
	webhookinfra "github.com/sunweilin/forgify/backend/internal/infra/trigger/webhook"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// SchedulerStarter is the port Service uses to dispatch fires to the
// scheduler. main.go wires *schedulerapp.Service through this interface
// to break the trigger ↔ scheduler import cycle.
//
// SchedulerStarter 是 Service 触发 dispatch 用的端口;main.go 把
// scheduler.Service 经此接口接,断 trigger ↔ scheduler 循环依赖。
type SchedulerStarter interface {
	StartRun(ctx context.Context, workflowID string, triggerKind string, input map[string]any) (string, error)
}

// Service is the unified trigger surface.
//
// Service 是统一的 trigger 入口。
type Service struct {
	mu        sync.RWMutex
	cron      *croninfra.Listener
	fsnotify  *fsnotifyinfra.Listener
	webhook   *webhookinfra.Listener
	specs     map[string]map[string]triggerdomain.Spec // workflowID → nodeID → spec
	scheduler SchedulerStarter
	log       *zap.Logger
}

// New constructs Service with the given mux (for webhook handler attach).
// scheduler may be nil at construct time; call SetScheduler after the
// scheduler Service is built (avoids constructor cycle).
//
// New 构造 Service;mux 给 webhook 注路由;scheduler 可 nil(构造后用
// SetScheduler 补,避免构造顺序循环)。
func New(mux *http.ServeMux, log *zap.Logger) *Service {
	if log == nil {
		panic("triggerapp.New: nil log")
	}
	if mux == nil {
		panic("triggerapp.New: nil mux")
	}
	s := &Service{
		specs: make(map[string]map[string]triggerdomain.Spec),
		log:   log.Named("triggerapp"),
	}

	onFire := func(workflowID, nodeID string, input map[string]any) {
		s.mu.RLock()
		sched := s.scheduler
		s.mu.RUnlock()
		if sched == nil {
			s.log.Warn("trigger fired before scheduler attached — drop",
				zap.String("workflowID", workflowID),
				zap.String("nodeID", nodeID))
			return
		}
		// Detached ctx with default local user — listener fires from
		// background goroutine, no HTTP request context available.
		// 后台 goroutine 来的 fire,无请求 ctx;用 detached ctx 注入 default
		// local user。
		ctx := reqctxpkg.SetUserID(context.Background(), reqctxpkg.DefaultLocalUserID)
		kind := kindForNode(s, workflowID, nodeID)
		runID, err := sched.StartRun(ctx, workflowID, kind, input)
		if err != nil {
			s.log.Error("scheduler.StartRun failed",
				zap.String("workflowID", workflowID),
				zap.String("nodeID", nodeID),
				zap.Error(err))
			return
		}
		s.log.Info("trigger fired",
			zap.String("workflowID", workflowID),
			zap.String("nodeID", nodeID),
			zap.String("runID", runID))
	}

	s.cron = croninfra.New(s.log, onFire)
	s.fsnotify = fsnotifyinfra.New(s.log, onFire)
	s.webhook = webhookinfra.New(mux, s.log, onFire)
	s.cron.Start()
	return s
}

// SetScheduler attaches the scheduler post-construction. main.go calls
// this after both Service and Scheduler are built (avoids ctor cycle).
//
// SetScheduler 后期挂 scheduler;main.go 在两 Service 构造完都调。
func (s *Service) SetScheduler(starter SchedulerStarter) {
	s.mu.Lock()
	s.scheduler = starter
	s.mu.Unlock()
}

// RegisterTrigger registers a trigger spec to its underlying listener.
// Boot scan + workflow active-version-change both call this.
//
// RegisterTrigger 注册 trigger spec 到对应 listener;boot 扫和 workflow
// active 翻新都调此。
func (s *Service) RegisterTrigger(spec triggerdomain.Spec) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	var err error
	switch spec.Kind {
	case triggerdomain.KindCron:
		err = s.cron.Register(spec)
	case triggerdomain.KindFsnotify:
		err = s.fsnotify.Register(spec)
	case triggerdomain.KindWebhook:
		err = s.webhook.Register(spec)
	case triggerdomain.KindManual:
		// no listener
	default:
		return fmt.Errorf("triggerapp.RegisterTrigger: unknown kind %q", spec.Kind)
	}

	// Track spec even when err non-nil so State() can show the failed
	// trigger to the user (fsnotify path-not-exist case § 6.11).
	// 即使 listener Register 失败也存 spec,让 State() 暴露给用户(§6.11)。
	if s.specs[spec.WorkflowID] == nil {
		s.specs[spec.WorkflowID] = make(map[string]triggerdomain.Spec)
	}
	s.specs[spec.WorkflowID][spec.NodeID] = spec
	return err
}

// UnregisterByWorkflow removes all triggers for a workflow (called on
// disable / delete / active version change).
//
// UnregisterByWorkflow 撤一个 workflow 关联的所有 trigger。
func (s *Service) UnregisterByWorkflow(workflowID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for nodeID, spec := range s.specs[workflowID] {
		switch spec.Kind {
		case triggerdomain.KindCron:
			s.cron.Unregister(workflowID, nodeID)
		case triggerdomain.KindFsnotify:
			s.fsnotify.Unregister(workflowID, nodeID)
		case triggerdomain.KindWebhook:
			s.webhook.Unregister(workflowID, nodeID)
		}
	}
	delete(s.specs, workflowID)
}

// State returns every registered trigger's State for a workflow. Powers
// GET /api/v1/workflows/{id}/triggers (§6.12).
//
// State 返某 workflow 所有 trigger 的状态(§6.12)。
func (s *Service) State(workflowID string) []triggerdomain.State {
	s.mu.RLock()
	specs := s.specs[workflowID]
	s.mu.RUnlock()
	out := make([]triggerdomain.State, 0, len(specs))
	for nodeID, spec := range specs {
		var st triggerdomain.State
		switch spec.Kind {
		case triggerdomain.KindCron:
			st = s.cron.State(workflowID, nodeID)
		case triggerdomain.KindFsnotify:
			st = s.fsnotify.State(workflowID, nodeID)
		case triggerdomain.KindWebhook:
			st = s.webhook.State(workflowID, nodeID)
		case triggerdomain.KindManual:
			st = triggerdomain.State{
				WorkflowID: workflowID, NodeID: nodeID,
				Kind: triggerdomain.KindManual, Status: triggerdomain.StateIdle,
			}
		}
		out = append(out, st)
	}
	return out
}

// Shutdown stops listeners. Call at process exit.
//
// Shutdown 关 listener。
func (s *Service) Shutdown() {
	s.cron.Stop()
	s.fsnotify.Stop()
}

// kindForNode looks up a trigger kind by (workflowID, nodeID). Returns
// empty string if not found.
//
// kindForNode 按 (workflowID,nodeID) 查 trigger 种类。
func kindForNode(s *Service, workflowID, nodeID string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if m, ok := s.specs[workflowID]; ok {
		if spec, ok := m[nodeID]; ok {
			return spec.Kind
		}
	}
	return triggerdomain.KindManual
}

// ErrSchedulerNotAttached is returned by manual fire paths if no
// scheduler has been wired yet (impossible at runtime — defensive).
//
// ErrSchedulerNotAttached 是 manual fire 路径在 scheduler 未挂时返
// (运行时不应发生,防御性)。
var ErrSchedulerNotAttached = errors.New("triggerapp: scheduler not attached")

// FireManual is the manual-trigger entry point used by HTTP
// `POST /workflows/{id}:trigger` and the LLM `trigger_workflow` tool.
// Service forwards directly to the scheduler.
//
// FireManual 是 HTTP / LLM 手动触发入口;Service 直接 forward 到 scheduler。
func (s *Service) FireManual(ctx context.Context, workflowID string, input map[string]any) (string, error) {
	s.mu.RLock()
	sched := s.scheduler
	s.mu.RUnlock()
	if sched == nil {
		return "", ErrSchedulerNotAttached
	}
	return sched.StartRun(ctx, workflowID, triggerdomain.KindManual, input)
}
