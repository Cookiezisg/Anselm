package function

import (
	"context"
	"fmt"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
)

// SearchExecutionsResult is the response shape for SearchExecutions: a page of rows +
// the ok/failed rollup.
//
// SearchExecutionsResult 是 SearchExecutions 的响应形状：一页行 + ok/failed 汇总。
type SearchExecutionsResult struct {
	Executions []*functiondomain.Execution        `json:"executions"`
	NextCursor string                             `json:"nextCursor,omitempty"`
	HasMore    bool                               `json:"hasMore"`
	Aggregates functiondomain.ExecutionAggregates `json:"aggregates"`
}

// SearchExecutions runs a paginated execution-log query with the ok/failed rollup.
//
// SearchExecutions 跑分页 execution-log 查询并附 ok/failed 汇总。
func (s *Service) SearchExecutions(ctx context.Context, filter functiondomain.ExecutionFilter) (*SearchExecutionsResult, error) {
	rows, next, err := s.repo.ListExecutions(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("functionapp.SearchExecutions: %w", err)
	}
	agg, err := s.repo.ComputeExecutionAggregates(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("functionapp.SearchExecutions: aggregates: %w", err)
	}
	return &SearchExecutionsResult{
		Executions: rows,
		NextCursor: next,
		HasMore:    next != "",
		Aggregates: agg,
	}, nil
}

// GetExecution returns one execution row verbatim (no machine-derived hints — the
// reader judges empty output / slowness off the raw fields).
//
// GetExecution 原样返单行 execution（无机器衍生 hints——读者从原始字段自判空输出 / 慢）。
func (s *Service) GetExecution(ctx context.Context, id string) (*functiondomain.Execution, error) {
	row, err := s.repo.GetExecutionByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("functionapp.GetExecution: %w", err)
	}
	return row, nil
}
