package scheduler

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// RehydrateOnBoot scans paused FlowRuns and re-registers cancel handles
// for Service.Cancel. Caller MUST pass a non-empty userID — typically by
// iterating userService.List at boot (see cmd/server/main.go). No
// magic-id fallback.
//
// RehydrateOnBoot 扫 paused FlowRun 并重注册 cancel 句柄。
// 调用方必须传非空 userID(主 main.go 会遍历 users.List 调用)。
func (s *Service) RehydrateOnBoot(ctx context.Context, userID string) error {
	if userID == "" {
		return fmt.Errorf("schedulerapp.RehydrateOnBoot: %w", reqctxpkg.ErrMissingUserID)
	}
	scopedCtx := reqctxpkg.SetUserID(ctx, userID)
	rows, err := s.repo.ListPaused(scopedCtx)
	if err != nil {
		return fmt.Errorf("schedulerapp.RehydrateOnBoot: %w", err)
	}
	s.log.Info("rehydrating paused flowruns", zap.Int("count", len(rows)))
	for _, run := range rows {
		s.cancelsMu.Lock()
		s.cancels[run.ID] = func() {
			s.log.Info("cancel called on pre-resume paused run",
				zap.String("runID", run.ID))
		}
		s.cancelsMu.Unlock()
	}

	// Boot reconciliation: a run still in `running` means the process crashed mid-execution — the
	// executeRun goroutine never wrote a terminal status. Until M6 journal-replay can resume it,
	// mark it failed/INTERRUPTED so it stops being an uncancellable zombie that pins CountRunning
	// and blocks serial workflows forever (review R2 running-crash).
	running, _, err := s.repo.List(scopedCtx, flowrundomain.ListFilter{Status: flowrundomain.StatusRunning, Limit: 1000})
	if err != nil {
		return fmt.Errorf("schedulerapp.RehydrateOnBoot: list running: %w", err)
	}
	for _, run := range running {
		now := time.Now().UTC()
		elapsed := now.Sub(run.StartedAt).Milliseconds()
		if uErr := s.repo.UpdateStatus(scopedCtx, run.ID, flowrundomain.StatusFailed, nil,
			"INTERRUPTED", "process restarted mid-execution", &now, elapsed); uErr != nil {
			s.log.Error("reconcile running→failed", zap.String("runID", run.ID), zap.Error(uErr))
		}
	}
	if len(running) > 0 {
		s.log.Warn("reconciled interrupted running flowruns to failed", zap.Int("count", len(running)))
	}

	// Boot catchup: re-drain any firings a crash left `pending` (persist-before-act recorded them
	// durably). The single-tx claim makes re-dispatch idempotent — a firing already claimed+started
	// is skipped, so no duplicate runs (ADR-021).
	s.DispatchPending(scopedCtx)
	return nil
}
