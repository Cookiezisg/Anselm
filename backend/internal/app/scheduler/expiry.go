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
func (s *Service) StartExpiryChecker(ctx context.Context) {
	s.runWG.Add(1)
	go func() {
		defer s.runWG.Done()
		ticker := time.NewTicker(expiryCheckInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.checkExpiredApprovals(ctx)
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

	// Flip the projection row to timed_out (audit trail separate from the decision port).
	// Best-effort: if this fails, we skip to avoid partially-applied state.
	decideCtx := reqctxpkg.SetUserID(context.Background(), a.UserID)
	if err := s.approvals.Decide(decideCtx, a.FlowrunID, a.NodeID, flowrundomain.ApprovalTimedOut, "timeout"); err != nil {
		s.log.Warn("expiry checker: Decide(timed_out) failed",
			zap.String("flowrunID", a.FlowrunID), zap.String("nodeID", a.NodeID), zap.Error(err))
		return
	}

	// Journal signal_received(source=timeout) — first-wins with any concurrent human decision.
	if s.journal == nil {
		return
	}
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
