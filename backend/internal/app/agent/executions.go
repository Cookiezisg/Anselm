package agent

import (
	"context"
	"fmt"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
)

// SearchExecutionsResult is a page of executions + the ok/failed rollup for a status badge.
//
// SearchExecutionsResult 是一页 execution + 供状态徽标的 ok/failed 汇总。
type SearchExecutionsResult struct {
	Count      int                             `json:"count"`
	Executions []*agentdomain.Execution        `json:"executions"`
	NextCursor string                          `json:"nextCursor,omitempty"`
	HasMore    bool                            `json:"hasMore"`
	Aggregates agentdomain.ExecutionAggregates `json:"aggregates"`
}

// SearchExecutions returns a cursor page of executions matching the filter + aggregates.
//
// SearchExecutions 返回匹配 filter 的一页 execution + 聚合。
func (s *Service) SearchExecutions(ctx context.Context, filter agentdomain.ExecutionFilter) (*SearchExecutionsResult, error) {
	rows, next, err := s.repo.ListExecutions(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("agentapp.SearchExecutions: %w", err)
	}
	agg, err := s.repo.ComputeAggregates(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("agentapp.SearchExecutions: aggregates: %w", err)
	}
	return &SearchExecutionsResult{
		Count:      len(rows),
		Executions: rows,
		NextCursor: next,
		HasMore:    next != "",
		Aggregates: agg,
	}, nil
}

// GetExecutionDetail returns one execution's full record (user/workspace-scoped).
//
// GetExecutionDetail 返单条 execution 的完整记录（user/workspace 隔离）。
func (s *Service) GetExecutionDetail(ctx context.Context, id string) (*agentdomain.Execution, error) {
	e, err := s.repo.GetExecutionByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("agentapp.GetExecutionDetail: %w", err)
	}
	return e, nil
}
