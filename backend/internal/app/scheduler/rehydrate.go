// rehydrate.go — boot-time scan for paused FlowRuns. Plan 05 §6.1:
// desktop app users close lids / sleep machines, so approval-paused runs
// must survive process restart. Service.RehydrateOnBoot is called once
// at startup (after main.go wires the scheduler) — it lists paused runs
// + re-registers the cancellation context entries so a subsequent
// Service.Cancel still works (the run itself stays paused until the
// approval HTTP endpoint resolves it).
//
// rehydrate.go —— 启动时扫 paused FlowRun。§6.1:桌面 app 用户合盖/睡机器,
// approval 暂停的 run 必须跨进程重启活下来。Service.RehydrateOnBoot 在
// main 装配后调一次:列 paused runs,重注 cancel 句柄(让 Service.Cancel
// 仍能杀)。

package scheduler

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// RehydrateOnBoot scans paused FlowRuns + re-registers cancel handles so
// Service.Cancel can still work. The runs stay paused — they resume only
// when the approval HTTP endpoint resolves their gate.
//
// userID is the default local user (Plan 05 boot scans on behalf of the
// installed single user); empty userID falls back to reqctxpkg.DefaultLocalUserID.
//
// RehydrateOnBoot 扫 paused FlowRun 重注 cancel;run 保持 paused,等 approval
// HTTP 端点解。userID 空则用 DefaultLocalUserID。
func (s *Service) RehydrateOnBoot(ctx context.Context, userID string) error {
	if userID == "" {
		userID = reqctxpkg.DefaultLocalUserID
	}
	scopedCtx := reqctxpkg.SetUserID(ctx, userID)
	rows, err := s.repo.ListPaused(scopedCtx)
	if err != nil {
		return fmt.Errorf("schedulerapp.RehydrateOnBoot: %w", err)
	}
	s.log.Info("rehydrating paused flowruns", zap.Int("count", len(rows)))
	for _, run := range rows {
		// Pre-register a no-op cancel so Cancel(runID) doesn't error
		// before the user resolves the approval. The real run-context
		// gets a fresh cancel func when ResumeApproval is called.
		// 预注 no-op cancel 让 Cancel(runID) 不报 ErrNotCancellable;真 ctx
		// 在 ResumeApproval 时建。
		s.cancelsMu.Lock()
		s.cancels[run.ID] = func() {
			s.log.Info("cancel called on pre-resume paused run",
				zap.String("runID", run.ID))
		}
		s.cancelsMu.Unlock()
	}
	return nil
}
