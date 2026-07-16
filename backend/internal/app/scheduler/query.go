package scheduler

import (
	"context"
	"time"

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

// GetRunWithNodesPage returns a run header + ONE keyset page of its node rows + the next cursor (N4) —
// the bounded REST run-detail read. A long loop run has thousands of node rows, so the wire pages them
// (the scheduler's GetRunWithNodes full dump is the interpreter's, not the wire's, F168-M7).
//
// GetRunWithNodesPage 返 run 头 + 它节点行的一页 keyset + 下一 cursor（N4）——有界的 REST run 详情读。
// 长 loop run 有数千节点行，故线缆分页（scheduler 的 GetRunWithNodes 全量倾倒是给解释器的、非线缆的，F168-M7）。
func (s *Service) GetRunWithNodesPage(ctx context.Context, id, cursor string, limit int) (*flowrundomain.FlowRun, []*flowrundomain.FlowRunNode, string, error) {
	run, err := s.runs.GetRun(ctx, id)
	if err != nil {
		return nil, nil, "", err
	}
	nodes, next, err := s.runs.ListNodes(ctx, id, cursor, limit)
	if err != nil {
		return nil, nil, "", err
	}
	return run, nodes, next, nil
}

// ListInbox returns every parked approval node in the workspace — the approval inbox (parked rows
// ARE the inbox; no separate projection table).
//
// ListInbox 返 workspace 内所有 parked approval 节点——审批收件箱（parked 行即收件箱，无投影表）。
func (s *Service) ListInbox(ctx context.Context) ([]*flowrundomain.FlowRunNode, error) {
	return s.runs.ListParkedNodes(ctx)
}

// RunStats answers the operational statistics batch (scheduler 工单③): workspace-wide totals +
// one health row per requested workflow id. This is the single place defaults + guards live —
// ids dedup preserving request order, the loud >50 rejection (with the cap in Details), RecentN
// default/clamp, and the 7d default window — so every caller (REST today) gets one behavior.
//
// RunStats 应答运营统计批查（scheduler 工单③）：全 workspace 聚合 + 每个请求 workflow id 一条健康行。
// 默认值 + 守卫的唯一居所——ids 保序去重、>50 大声拒（Details 带上限）、RecentN 默认/钳制、7d 默认
// 窗口——所有调用方（今天是 REST）拿同一行为。
func (s *Service) RunStats(ctx context.Context, q flowrundomain.StatsQuery) (*flowrundomain.RunStats, error) {
	if len(q.WorkflowIDs) > 0 {
		seen := make(map[string]bool, len(q.WorkflowIDs))
		deduped := make([]string, 0, len(q.WorkflowIDs))
		for _, id := range q.WorkflowIDs {
			if id == "" || seen[id] {
				continue
			}
			seen[id] = true
			deduped = append(deduped, id)
		}
		q.WorkflowIDs = deduped
	}
	if len(q.WorkflowIDs) > flowrundomain.StatsMaxWorkflowIDs {
		return nil, flowrundomain.ErrStatsTooManyIDs.WithDetails(map[string]any{
			"allowed": flowrundomain.StatsMaxWorkflowIDs,
			"got":     len(q.WorkflowIDs),
		})
	}
	if q.RecentN <= 0 {
		q.RecentN = flowrundomain.StatsDefaultRecentN
	}
	if q.RecentN > flowrundomain.StatsMaxRecentN {
		q.RecentN = flowrundomain.StatsMaxRecentN
	}
	if q.Since.IsZero() {
		q.Since = time.Now().UTC().Add(-flowrundomain.StatsDefaultWindow)
	}
	return s.runs.RunStats(ctx, q)
}
