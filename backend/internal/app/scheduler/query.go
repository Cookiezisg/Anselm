package scheduler

import (
	"context"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
)

// ListRuns pages a workspace's flowruns (newest-first; optional WorkflowID filter) for the run
// history view.
//
// ListRuns 分页一个 workspace 的 flowrun（最新优先；可选 WorkflowID）供运行历史视图。
func (s *Service) ListRuns(ctx context.Context, filter flowrundomain.ListFilter) ([]*flowrundomain.FlowRun, string, error) {
	return s.runs.ListRuns(ctx, filter)
}

// GetRunWithNodes returns a run header + all its node rows (the full memoization) for the run-detail
// view — including parked approval rows (the inbox is GetRunWithNodes filtered, or ListInbox).
//
// GetRunWithNodes 返 run 头 + 它全部节点行（完整记忆化）供 run 详情视图——含 parked approval 行。
func (s *Service) GetRunWithNodes(ctx context.Context, id string) (*flowrundomain.FlowRun, []*flowrundomain.FlowRunNode, error) {
	run, err := s.runs.GetRun(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	nodes, err := s.runs.GetNodes(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	return run, nodes, nil
}

// ListInbox returns every parked approval node in the workspace — the approval inbox (parked rows
// ARE the inbox; no separate projection table).
//
// ListInbox 返 workspace 内所有 parked approval 节点——审批收件箱（parked 行即收件箱，无投影表）。
func (s *Service) ListInbox(ctx context.Context) ([]*flowrundomain.FlowRunNode, error) {
	return s.runs.ListParkedNodes(ctx)
}
