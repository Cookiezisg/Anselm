package scheduler

import (
	"context"
	"fmt"
	"time"

	"go.uber.org/zap"

	flowrundomain "github.com/sunweilin/forgify/backend/internal/domain/flowrun"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

const expiryCheckInterval = 30 * time.Second

// StartExpiryChecker launches a background goroutine that scans for approval nodes whose timeout
// has elapsed and auto-decides them (signal_received source=timeout, then ResumeApproval). It is
// the backend half of the durable timer for approval nodes (17 §9, 05-approval-node §超时定时器).
// The goroutine stops when ctx is cancelled (call at service shutdown).
//
// StartExpiryChecker 启动后台协程，扫 deadline 过期的 approval 并自动决策(durable timer,17 §9)。
// StartExpiryChecker launches the approval-expiry background goroutine. The goroutine is tracked
// in runWG so Drain() can wait for it, and its context is stored in s.stopExpiry so Drain() can
// cancel it before calling runWG.Wait() — otherwise Drain would deadlock on context.Background().
//
// StartExpiryChecker 启动到期检查协程;stopExpiry 让 Drain 能先取消再 Wait，防止 deadlock。
func (s *Service) StartExpiryChecker(ctx context.Context) {
	expCtx, cancel := context.WithCancel(ctx)
	s.stopExpiry = cancel
	s.runWG.Add(1)
	go func() {
		defer s.runWG.Done()
		defer cancel() // ensure cancel is always called on exit
		ticker := time.NewTicker(expiryCheckInterval)
		defer ticker.Stop()
		for {
			select {
			case <-expCtx.Done():
				return
			case <-ticker.C:
				s.checkExpiredApprovals(expCtx)
			}
		}
	}()
}

func (s *Service) checkExpiredApprovals(ctx context.Context) {
	if s.approvals == nil {
		return
	}
	expired, err := s.approvals.ListExpired(ctx)
	if err != nil {
		s.log.Warn("expiry checker: ListExpired failed", zap.Error(err))
		return
	}
	for _, a := range expired {
		s.expireApproval(ctx, a)
	}
}

func (s *Service) expireApproval(ctx context.Context, a *flowrundomain.Approval) {
	// Derive the journal decision from timeout behavior. Default: reject → no port.
	journalDecision := "no"
	switch a.TimeoutBehavior {
	case "approve":
		journalDecision = "yes"
	}

	decideCtx := reqctxpkg.SetUserID(context.Background(), a.UserID)

	// Guard both journal and approvals upfront: the two writes must be atomic from a durability
	// standpoint. If journal is nil, skip entirely — writing only to the projection without a
	// journal signal_received would leave the approval in an inconsistent state on crash-replay
	// (projection says timed_out but journal has no signal → interpreter would re-park on replay).
	if s.journal == nil {
		s.log.Warn("expiry checker: journal nil, skipping approval timeout (no durability)",
			zap.String("flowrunID", a.FlowrunID), zap.String("nodeID", a.NodeID))
		return
	}

	// Journal signal_received(source=timeout) FIRST — durable truth before projection update.
	// first-wins with any concurrent human decision (ADR-018 dedup_key ensures idempotency).
	if _, jErr := s.journal.AppendEvent(decideCtx, &flowrundomain.FlowRunEvent{
		FlowrunID: a.FlowrunID,
		Type:      flowrundomain.EventSignalReceived,
		NodeID:    a.NodeID,
		Result:    map[string]any{"decision": journalDecision, "source": "timeout"},
	}); jErr != nil {
		s.log.Warn("expiry checker: AppendEvent(signal_received) failed",
			zap.String("flowrunID", a.FlowrunID), zap.String("nodeID", a.NodeID), zap.Error(jErr))
		return
	}

	// Flip the projection row to timed_out AFTER the journal write succeeds. The journal is the
	// durable truth; the projection is a best-effort UI inbox. If Decide fails, the journal already
	// has the signal so the interpreter will resume correctly — the projection just stays "parked"
	// until a future run or manual cleanup.
	if err := s.approvals.Decide(decideCtx, a.FlowrunID, a.NodeID, flowrundomain.ApprovalTimedOut, "timeout"); err != nil {
		s.log.Warn("expiry checker: Decide(timed_out) failed (journal already written, interpreter will resume)",
			zap.String("flowrunID", a.FlowrunID), zap.String("nodeID", a.NodeID), zap.Error(err))
		// Don't return — continue to re-drive the interpreter; the journal write succeeded.
	}

	s.log.Info("expiry checker: approval timed out → auto-decided",
		zap.String("flowrunID", a.FlowrunID), zap.String("nodeID", a.NodeID),
		zap.String("behavior", a.TimeoutBehavior), zap.String("decision", journalDecision))

	// Reload the run and re-drive the interpreter (same as ResumeApproval path).
	run, gErr := s.repo.Get(decideCtx, a.FlowrunID)
	if gErr != nil {
		s.log.Warn("expiry checker: Get flowrun failed",
			zap.String("flowrunID", a.FlowrunID), zap.Error(gErr))
		return
	}

	// Only re-drive if the flowrun is still awaiting signal (idempotent: a human may have raced us).
	if run.Status != flowrundomain.StatusAwaitingSignal {
		return
	}
	if ok, cErr := s.repo.ClaimStatus(decideCtx, a.FlowrunID, flowrundomain.StatusAwaitingSignal, flowrundomain.StatusRunning); cErr != nil || !ok {
		if cErr != nil {
			s.log.Warn("expiry checker: ClaimStatus failed", zap.Error(cErr))
		}
		return
	}

	// Reload graph from active version.
	graph, lErr := s.loadFrozenGraph(decideCtx, run)
	if lErr != nil {
		s.log.Warn("expiry checker: loadFrozenGraph failed", zap.Error(lErr))
		_ = s.repo.UpdateStatus(decideCtx, a.FlowrunID, flowrundomain.StatusFailed, nil,
			"EXPIRY_GRAPH_LOAD_FAILED", fmt.Sprintf("loadFrozenGraph: %v", lErr), nil, run.ElapsedMs)
		return
	}
	s.spawnRun(run, graph, 0)
}
