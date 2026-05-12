// Package scheduler is the workflow execution orchestrator. It reads a
// Workflow's active version, persists a FlowRun, then drives the DAG
// node-by-node (E6 executeRun + E7-E8 dispatchers fill the body).
//
// The trigger domain calls scheduler.StartRun via the SchedulerStarter
// port to fan-out listener fires; HTTP `:trigger` + LLM `trigger_workflow`
// share the same entry point.
//
// See documents/version-1.2/adhoc-topic-documents/forge_redesign/05-execution-plane.md §3.
//
// Package scheduler 是 workflow 执行编排器。读 active Version → 持久化
// FlowRun → DAG dispatch(E6 executeRun + E7-E8 dispatcher 后补)。
// trigger 域经 SchedulerStarter 端口 fan-out 触发;HTTP `:trigger` + LLM
// `trigger_workflow` 共享同一入口。
package scheduler

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	workflowdomain "github.com/sunweilin/forgify/backend/internal/domain/workflow"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// WorkflowReader is the read-only contract scheduler consumes from
// workflowapp.Service. Decoupled via interface so unit tests can fake it.
//
// WorkflowReader 是 scheduler 从 workflowapp.Service 消费的只读契约;
// 单测可 fake。
type WorkflowReader interface {
	GetActiveVersion(ctx context.Context, workflowID string) (*workflowdomain.Version, error)
	GetWorkflow(ctx context.Context, workflowID string) (*workflowdomain.Workflow, error)
	ListEnabled(ctx context.Context) ([]*workflowdomain.Workflow, error)
}

// Service orchestrates FlowRun execution. StartRun is the only entry
// point (cron / fsnotify / webhook listeners + HTTP `:trigger` + LLM
// `trigger_workflow` all funnel here).
//
// Service 编排 FlowRun 执行;StartRun 是唯一入口。
type Service struct {
	repo         flowrundomain.Repository
	workflowRead WorkflowReader
	notif        notificationspkg.Publisher
	log          *zap.Logger

	cancelsMu sync.RWMutex
	cancels   map[string]context.CancelFunc

	// Test hook for E5 — production E6 will fill this in with executeRun.
	// Public so harness can override (e.g. fake-run that closes faster).
	//
	// 测试钩子;E6 用真 executeRun 实现填。harness 可 override。
	ExecuteFn func(ctx context.Context, run *flowrundomain.FlowRun, graph *workflowdomain.Graph)
}

// NewService constructs Service. Panics on nil log / notif. workflowRead
// + repo may be nil only in pre-wire tests that never call StartRun.
//
// NewService 构造 Service;nil log/notif panic;workflowRead+repo 仅
// pre-wire 测试可 nil(不调 StartRun)。
func NewService(
	repo flowrundomain.Repository,
	workflowRead WorkflowReader,
	notif notificationspkg.Publisher,
	log *zap.Logger,
) *Service {
	if log == nil {
		panic("schedulerapp.NewService: log is nil")
	}
	if notif == nil {
		panic("schedulerapp.NewService: notif is nil")
	}
	s := &Service{
		repo:         repo,
		workflowRead: workflowRead,
		notif:        notif,
		log:          log.Named("schedulerapp"),
		cancels:      make(map[string]context.CancelFunc),
	}
	// Default ExecuteFn = no-op (E5 stub). E6 wires the real one.
	// 默认 ExecuteFn 是 no-op;E6 接真 executeRun。
	s.ExecuteFn = s.executeRunStub
	return s
}

// Sentinel errors. Wire codes registered in transport/httpapi/response/errmap.go.
//
// 哨兵错误。
var (
	ErrWorkflowDisabled       = errors.New("scheduler: workflow disabled")
	ErrWorkflowNeedsAttention = errors.New("scheduler: workflow needs attention")
	ErrConcurrencyLimit       = errors.New("scheduler: concurrency limit reached (skipped)")
	ErrWorkflowNotFound       = errors.New("scheduler: workflow not found")
)

// StartRun spawns a new FlowRun for a workflow trigger. Implements the
// SchedulerStarter port consumed by app/trigger.
//
// Gate order (Plan 05 §3.1):
//  1. RequireUserID(ctx)
//  2. GetWorkflow → ErrWorkflowNotFound (mapped to 404 by errmap)
//  3. Enabled gate (§6.5) → ErrWorkflowDisabled
//  4. NeedsAttention gate → ErrWorkflowNeedsAttention
//  5. Serial concurrency (§6.3) → ErrConcurrencyLimit (skipped, caller
//     logs + moves on; trigger listener treats as normal)
//  6. GetActiveVersion → propagates workflow.ErrNoActiveVersion
//  7. flowrun.Create + register cancel + go ExecuteFn
//
// StartRun 起新 FlowRun;7-gate 校验。
func (s *Service) StartRun(ctx context.Context, workflowID, triggerKind string, triggerInput map[string]any) (string, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return "", fmt.Errorf("schedulerapp.StartRun: %w", err)
	}

	wf, err := s.workflowRead.GetWorkflow(ctx, workflowID)
	if err != nil {
		if errors.Is(err, workflowdomain.ErrNotFound) {
			return "", fmt.Errorf("schedulerapp.StartRun: %w", ErrWorkflowNotFound)
		}
		return "", fmt.Errorf("schedulerapp.StartRun: GetWorkflow: %w", err)
	}

	if !wf.Enabled {
		return "", fmt.Errorf("schedulerapp.StartRun: %w", ErrWorkflowDisabled)
	}
	if wf.NeedsAttention {
		return "", fmt.Errorf("schedulerapp.StartRun: %w", ErrWorkflowNeedsAttention)
	}

	if wf.Concurrency == workflowdomain.ConcurrencySerial {
		running, err := s.repo.CountRunning(ctx, workflowID)
		if err != nil {
			return "", fmt.Errorf("schedulerapp.StartRun: CountRunning: %w", err)
		}
		if running >= 1 {
			return "", fmt.Errorf("schedulerapp.StartRun: %w", ErrConcurrencyLimit)
		}
	}

	version, err := s.workflowRead.GetActiveVersion(ctx, workflowID)
	if err != nil {
		return "", fmt.Errorf("schedulerapp.StartRun: GetActiveVersion: %w", err)
	}

	now := time.Now().UTC()
	run := &flowrundomain.FlowRun{
		ID:           idgenpkg.New("fr"),
		UserID:       uid,
		WorkflowID:   workflowID,
		VersionID:    version.ID,
		TriggerKind:  triggerKind,
		TriggerInput: triggerInput,
		Status:       flowrundomain.StatusRunning,
		StartedAt:    now,
	}
	if err := s.repo.Create(ctx, run); err != nil {
		return "", fmt.Errorf("schedulerapp.StartRun: Create: %w", err)
	}

	// Detached ctx so the run survives caller-cancel (HTTP request close,
	// trigger goroutine drop, etc.). User identity propagated explicitly.
	// runCtx is then made cancellable for explicit Service.Cancel.
	// 起 detached ctx;caller-cancel 不挂掉 run(HTTP 关 / trigger goroutine
	// 撤等);用户身份显式传;再外包一层 WithCancel 让 Service.Cancel 杀。
	runCtx := reqctxpkg.SetUserID(context.Background(), uid)
	runCtx, cancel := context.WithCancel(runCtx)
	s.cancelsMu.Lock()
	s.cancels[run.ID] = cancel
	s.cancelsMu.Unlock()

	graph := version.GraphParsed
	go func() {
		defer s.releaseCancel(run.ID)
		defer func() {
			if r := recover(); r != nil {
				s.log.Error("scheduler.executeRun panic",
					zap.String("runID", run.ID), zap.Any("recover", r))
				// finalize as failed so the row doesn't dangle running.
				// finalize 失败标 failed,防 row 卡在 running。
				_ = s.repo.UpdateStatus(runCtx, run.ID, flowrundomain.StatusFailed,
					nil, "INTERNAL_PANIC", fmt.Sprintf("%v", r),
					ptrNow(), 0)
			}
		}()
		s.ExecuteFn(runCtx, run, graph)
	}()

	s.publish(ctx, run.ID, workflowID, "started", map[string]any{
		"triggerKind": triggerKind,
	})
	return run.ID, nil
}

// Cancel cancels a running or paused FlowRun. The cancel func cascades
// through every dispatcher's ctx so in-flight node calls abort. Cleanup
// (handler instance destroy etc.) happens in executeRun's deferred path.
//
// Cancel 取消运行中/paused FlowRun;cancel ctx 一路串到 dispatcher,清理
// 在 executeRun defer 路径。
func (s *Service) Cancel(_ context.Context, runID string) error {
	s.cancelsMu.RLock()
	cancel, ok := s.cancels[runID]
	s.cancelsMu.RUnlock()
	if !ok {
		return fmt.Errorf("schedulerapp.Cancel: %w", flowrundomain.ErrNotCancellable)
	}
	cancel()
	return nil
}

func (s *Service) releaseCancel(runID string) {
	s.cancelsMu.Lock()
	delete(s.cancels, runID)
	s.cancelsMu.Unlock()
}

// executeRunStub is the E5 placeholder — finalizes the run as completed
// immediately. E6 replaces ExecuteFn with the real DAG-driving body.
// Kept as a method (not free fn) so Service can swap its own behaviour.
//
// executeRunStub 是 E5 占位;立刻 finalize 为 completed。E6 用真 executeRun
// 替换 ExecuteFn。
func (s *Service) executeRunStub(ctx context.Context, run *flowrundomain.FlowRun, _ *workflowdomain.Graph) {
	endedAt := time.Now().UTC()
	elapsedMs := endedAt.Sub(run.StartedAt).Milliseconds()
	if err := s.repo.UpdateStatus(ctx, run.ID, flowrundomain.StatusCompleted,
		map[string]any{"stub": true}, "", "", &endedAt, elapsedMs); err != nil {
		s.log.Warn("scheduler.executeRunStub: finalize failed",
			zap.String("runID", run.ID), zap.Error(err))
		return
	}
	s.publish(ctx, run.ID, run.WorkflowID, "completed", nil)
}

// publish emits a `flowrun` entity notification (slim payload D-redo-6).
//
// publish 推 `flowrun` 通知;瘦身 payload(D-redo-6)。
func (s *Service) publish(ctx context.Context, runID, workflowID, action string, extra map[string]any) {
	payload := map[string]any{"action": action, "workflowId": workflowID}
	for k, v := range extra {
		payload[k] = v
	}
	s.notif.Publish(ctx, "flowrun", runID, payload, "")
}

func ptrNow() *time.Time {
	t := time.Now().UTC()
	return &t
}
