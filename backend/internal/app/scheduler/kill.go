package scheduler

import (
	"context"
	"fmt"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// trackInflight wraps an advance with a cancellable context registered under the run id, so
// KillWorkflow can interrupt this run even while it is blocked deep in a node (a long agent's
// loop.Run, a slow function). The per-run guard (pool.go drive) ENFORCES at most one goroutine
// advancing a given run at a time, so there is at most one cancel per run — this used to be merely
// emergent from the sequential driver; under the F174 worker pool it is an explicit invariant. The
// returned release deregisters and cancels (freeing the ctx). On a normal finish release just cleans
// up; on a kill the cancel has already fired and release is a harmless second cancel.
//
// trackInflight 给一次 advance 包一个按 run id 注册的可取消 ctx，使 KillWorkflow 能打断这个 run——即便它
// 正卡在某节点深处（长 agent 的 loop.Run、慢 function）。per-run guard（pool.go 的 drive）**强制**同一 run
// 同时至多一个 goroutine 在 advance，故每个 run 至多一个 cancel——这原来只是串行驱动器的副产物；F174
// worker 池下它是显式不变式。返回的 release 注销并 cancel（释放 ctx）。正常结束时 release 只清理；被 kill 时
// cancel 已先触发、release 是无害的第二次 cancel。
func (s *Service) trackInflight(ctx context.Context, flowrunID string) (context.Context, func()) {
	cctx, cancel := context.WithCancel(ctx)
	s.inflightMu.Lock()
	s.inflight[flowrunID] = cancel
	s.inflightMu.Unlock()
	return cctx, func() {
		s.inflightMu.Lock()
		delete(s.inflight, flowrunID)
		s.inflightMu.Unlock()
		cancel()
	}
}

// cancelInflight cancels a run's in-progress advance if one is registered (interrupting a blocked
// node). A no-op when the run is not actively advancing — e.g. a run parked on an approval has
// already returned from advance, so there is nothing to interrupt; KillWorkflow then just marks it
// cancelled in the store.
//
// cancelInflight 取消某 run 在途的 advance（若有注册）（打断阻塞的节点）。run 未在 advance 时 no-op——如
// park 在审批上的 run 早已从 advance 返回、无可打断；KillWorkflow 随即只在 store 里标 cancelled。
func (s *Service) cancelInflight(flowrunID string) {
	s.inflightMu.Lock()
	cancel := s.inflight[flowrunID]
	s.inflightMu.Unlock()
	if cancel != nil {
		cancel()
	}
}

// Shutdown cancels EVERY in-flight advance so a backend shutdown can interrupt any run still wedged
// mid-node after its grace window expires (R3, option C). Unlike KillWorkflow it does NOT mark runs
// cancelled in the store — a shutdown is not a user kill: an interrupted node simply isn't memoized,
// so the run records failed and a :replay resumes it from the last memoized node (a run whose node
// finished within the grace stays running and boot recovery resumes it). No-op if nothing in flight.
//
// Shutdown 取消每个在飞 advance，使后端关停在宽限超时后能打断仍卡在节点中的 run（R3 选项 C）。不同于 KillWorkflow：
// 不在 store 标 cancelled——关停非用户 kill：被打断的节点未记忆化、run 记 failed，:replay 从末个记忆化节点续；宽限内
// 跑完节点的 run 保持 running、由 boot 恢复续跑。无在飞则 no-op。
func (s *Service) Shutdown() {
	// Mark the pool closing BEFORE cancelling in-flight, so from this instant drive() skips execution.
	// Shutdown only cancels ctxs already in s.inflight (registered when a worker enters Advance); a job
	// still BUFFERED in advQueue is not yet in-flight and carries an uncancellable Detached workspace ctx,
	// so StopPool's close(q) queue-drain would otherwise run every buffered run to full completion —
	// unbounded advWG.Wait blocking shutdown past the grace → SIGKILL orphaning sandbox subprocesses. With
	// advClosing set, the drained buffered runs are skipped (they stay Running; boot Recover resumes them,
	// exactly like an interrupted node — record-once keeps durability). R3/F174 shutdown-hang family.
	//
	// 在取消在飞**之前**标记池关闭,使从此刻起 drive() 跳过执行。Shutdown 只取消已在 s.inflight 的 ctx（worker
	// 进入 Advance 时注册）;仍**缓冲**在 advQueue 里的 job 尚未在飞、且带不可取消的 Detached workspace ctx,故
	// StopPool 的 close(q) 排空会把每个缓冲 run 跑到完成——无界 advWG.Wait 把关停拖过宽限 → SIGKILL 孤儿化 sandbox
	// 子进程。设 advClosing 后,被排空的缓冲 run 被跳过（保持 Running；boot Recover 续跑,同被打断的节点——record-once
	// 保住持久性）。R3/F174 关停挂起家族。
	s.advMu.Lock()
	s.advClosing = true
	s.advMu.Unlock()

	s.inflightMu.Lock()
	cancels := make([]context.CancelFunc, 0, len(s.inflight))
	for id, cancel := range s.inflight {
		cancels = append(cancels, cancel)
		delete(s.inflight, id)
	}
	s.inflightMu.Unlock()
	for _, cancel := range cancels {
		cancel()
	}
}

// KillWorkflow hard-stops a workflow's execution: every currently-running run is cancelled — its
// in-progress advance interrupted via ctx (so a long agent / function returns at once), then its
// header marked cancelled (first-wins; a run that finished in the same instant keeps its real
// terminal). Detaching the trigger listener and flipping lifecycle are the workflow service's job
// (it calls this after Detach). Returns how many runs were killed. Workspace-scoped.
//
// KillWorkflow 硬停一个 workflow 的执行：当前所有 running run 都被取消——经 ctx 打断其在途 advance（长
// agent / function 立即返回），再把头标 cancelled（first-wins；同一瞬间结束的 run 保留其真实终态）。摘 trigger
// 监听、翻 lifecycle 是 workflow service 的事（它在 Detach 后调本法）。返被杀 run 数。按 workspace 隔离。
func (s *Service) KillWorkflow(ctx context.Context, workflowID string) (int, error) {
	runs, err := s.runs.ListRunningByWorkflow(ctx, workflowID)
	if err != nil {
		return 0, err
	}
	for _, r := range runs {
		// Mark cancelled BEFORE cancelling the ctx: the interrupted advance's RunAgent/RunAction will
		// return ctx.Err(), which the interpreter would otherwise turn into a `failed` run via failNode.
		// Writing cancelled first (guarded WHERE running) makes cancelled win — failNode's later
		// mark-failed matches 0 rows and is a no-op. Order matters for the run's recorded terminal.
		//
		// 先标 cancelled 再 cancel ctx：被打断的 advance 的 RunAgent/RunAction 会返 ctx.Err()，否则解释器会
		// 经 failNode 把 run 变 `failed`。先写 cancelled（守卫 WHERE running）使 cancelled 赢——failNode 随后
		// 的 mark-failed 匹配 0 行 no-op。顺序决定 run 记录的终态。
		if err := s.runs.MarkRunTerminal(ctx, r.ID, flowrundomain.StatusCancelled, "killed by user"); err != nil {
			s.log.Warn("schedulerapp.KillWorkflow: mark cancelled", zap.String("flowrun", r.ID), zap.Error(err))
		} else {
			s.emitRunTerminal(ctx, workflowID, r.ID, flowrundomain.StatusCancelled, "")
		}
		// Resolve any approval the run was parked on so it doesn't linger as a dead inbox entry.
		// 收掉 run 所 park 的审批，免其作为死收件箱项滞留。
		if _, err := s.runs.CancelParkedNodes(ctx, r.ID); err != nil {
			s.log.Warn("schedulerapp.KillWorkflow: cancel parked nodes", zap.String("flowrun", r.ID), zap.Error(err))
		}
		s.cancelInflight(r.ID)
	}
	return len(runs), nil
}

// cancelRunningForReplace gracefully cancels every in-flight run of a workflow so a `replace`-policy
// firing can run in their place. It mirrors KillWorkflow's race-safe order — mark each run cancelled
// (first-wins, guarded WHERE running) BEFORE interrupting its advance via ctx — so a run that finished
// in the same instant keeps its real terminal and the interrupted advance's failNode is a no-op.
// cancelled (not failed) is correct: a superseded run is not a fault, so it lights no attention banner.
// Unlike KillWorkflow it does NOT touch lifecycle (the workflow stays active — a new run follows).
//
// cancelRunningForReplace 优雅取消一个 workflow 所有在途 run，使 `replace` 策略的 firing 顶替它们跑。镜像
// KillWorkflow 的 race-safe 顺序——先标 cancelled（first-wins、守卫 WHERE running）再经 ctx 打断 advance——
// 故同一瞬间结束的 run 保留真实终态、被打断 advance 的 failNode no-op。标 cancelled（非 failed）正确：被顶替
// 的 run 不是故障、不点 attention 横幅。与 KillWorkflow 不同，它不动 lifecycle（workflow 仍 active——随即有新 run）。
func (s *Service) cancelRunningForReplace(ctx context.Context, workflowID string) error {
	runs, err := s.runs.ListRunningByWorkflow(ctx, workflowID)
	if err != nil {
		return fmt.Errorf("schedulerapp.cancelRunningForReplace: %w", err)
	}
	for _, r := range runs {
		if err := s.runs.MarkRunTerminal(ctx, r.ID, flowrundomain.StatusCancelled, "replaced by a newer trigger"); err != nil {
			s.log.Warn("schedulerapp.cancelRunningForReplace: mark cancelled", zap.String("flowrun", r.ID), zap.Error(err))
		} else {
			s.emitRunTerminal(ctx, workflowID, r.ID, flowrundomain.StatusCancelled, "")
		}
		// Resolve any approval the run was parked on so it doesn't linger as a dead inbox entry.
		// 收掉 run 所 park 的审批，免其作为死收件箱项滞留。
		if _, err := s.runs.CancelParkedNodes(ctx, r.ID); err != nil {
			s.log.Warn("schedulerapp.cancelRunningForReplace: cancel parked nodes", zap.String("flowrun", r.ID), zap.Error(err))
		}
		s.cancelInflight(r.ID)
	}
	return nil
}

// CountRunning reports a workflow's in-flight run count (the workflow service's Runner port uses it
// to pick draining vs inactive on :deactivate). Workspace-scoped.
//
// CountRunning 报告一个 workflow 在途 run 数（workflow service 的 Runner 端口据此在 :deactivate 选
// draining vs inactive）。按 workspace 隔离。
func (s *Service) CountRunning(ctx context.Context, workflowID string) (int, error) {
	return s.runs.CountRunningByWorkflow(ctx, workflowID)
}

// markRunTerminal flips a run terminal then reconciles its workflow's drain state — the one
// chokepoint for a run reaching completed/failed (kill writes cancelled directly via the store and
// flips lifecycle itself). When a draining workflow's LAST in-flight run settles here, the workflow
// becomes inactive (graceful-drain complete).
//
// markRunTerminal 把 run 翻终态后结算其 workflow 排空——run 走到 completed/failed 的唯一收口（kill 经 store
// 直接写 cancelled、自己翻 lifecycle）。当一个 draining workflow 的**最后**一个在途 run 在此结算，该 workflow
// 变 inactive（优雅排空完成）。
func (s *Service) markRunTerminal(ctx context.Context, run *flowrundomain.FlowRun, status, msg string) error {
	if err := s.runs.MarkRunTerminal(ctx, run.ID, status, msg); err != nil {
		return err
	}
	s.emitRunTerminal(ctx, run.WorkflowID, run.ID, status, msg) // durable: the run is over survives reconnect
	s.afterRunSettled(ctx, run.WorkflowID)
	// Self-healing attention + summons: a failed run lights the workflow banner and lands a
	// notification (the user may have left the panel); a completed run clears the banner.
	// cancelled does neither — a hand-stopped run is not a fault.
	// 自愈式 attention + 唤回：失败 run 点亮 workflow 横幅并落通知（用户可能早已离开面板）；
	// completed 熄灯。cancelled 两者皆不做——手动终止不是故障。
	switch status {
	case flowrundomain.StatusFailed:
		name := ""
		if w, werr := s.workflows.GetWorkflow(ctx, run.WorkflowID); werr == nil && w != nil {
			name = w.Name
		}
		s.notify(ctx, "workflow.run_failed", map[string]any{
			"workflowId": run.WorkflowID, "flowrunId": run.ID, "error": msg, "name": name,
		})
		if s.recon != nil {
			if err := s.recon.MarkRunAttention(ctx, run.WorkflowID, true, msg); err != nil {
				s.log.Warn("schedulerapp: mark attention", zap.String("workflow", run.WorkflowID), zap.Error(err))
			}
		}
	case flowrundomain.StatusCompleted:
		if s.recon != nil {
			if err := s.recon.MarkRunAttention(ctx, run.WorkflowID, false, ""); err != nil {
				s.log.Warn("schedulerapp: clear attention", zap.String("workflow", run.WorkflowID), zap.Error(err))
			}
		}
	}
	return nil
}

// afterRunSettled flips a draining workflow to inactive once it has no running runs left. Best-effort
// + nil-tolerant: a count/reconcile error is logged, never failing the run that just settled.
//
// afterRunSettled 在某 workflow 无 running run 后把 draining 翻 inactive。best-effort + nil-tolerant：
// count/reconcile 出错只记日志，绝不连累刚结算的 run。
func (s *Service) afterRunSettled(ctx context.Context, workflowID string) {
	if s.recon == nil {
		return
	}
	n, err := s.runs.CountRunningByWorkflow(ctx, workflowID)
	if err != nil {
		s.log.Warn("schedulerapp: count running for drain reconcile", zap.String("workflow", workflowID), zap.Error(err))
		return
	}
	if n > 0 {
		return
	}
	if err := s.recon.MarkInactiveIfDrained(ctx, workflowID); err != nil {
		s.log.Warn("schedulerapp: drain reconcile", zap.String("workflow", workflowID), zap.Error(err))
	}
}
