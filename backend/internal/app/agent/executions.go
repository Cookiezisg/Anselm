package agent

import (
	"context"
	"fmt"

	agentdomain "github.com/sunweilin/forgify/backend/internal/domain/agent"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// SearchExecutionsResult is the response shape for SearchExecutions (mirrors functionapp).
//
// SearchExecutionsResult 是 SearchExecutions 的响应形状（对标 functionapp）。
type SearchExecutionsResult struct {
	Count      int                              `json:"count"`
	Executions []*agentdomain.AgentExecution    `json:"executions"`
	NextCursor string                           `json:"nextCursor,omitempty"`
	HasMore    bool                             `json:"hasMore"`
	Aggregates agentdomain.ExecutionAggregates  `json:"aggregates"`
}

// ExecutionDetail is the raw AgentExecution row plus machine-computed hints (mirrors functionapp).
//
// ExecutionDetail 是原始 AgentExecution 行加机器计算的 hints。
type ExecutionDetail struct {
	*agentdomain.AgentExecution
	Hints ExecutionHints `json:"hints"`
}

// ExecutionHints flags non-obvious signals so the LLM doesn't have to recompute (mirrors functionapp).
//
// ExecutionHints 标记 LLM 不必重算的信号。
type ExecutionHints struct {
	OutputEmpty         bool `json:"outputEmpty"`
	SignificantlySlower bool `json:"significantlySlower"`
}

// SearchExecutions runs a paginated execution-log query with aggregates (mirrors functionapp).
//
// SearchExecutions 跑分页 execution-log 查询并附聚合。
func (s *Service) SearchExecutions(ctx context.Context, filter agentdomain.ExecutionFilter) (*SearchExecutionsResult, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("agentapp.SearchExecutions: %w", err)
	}
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

// GetExecutionDetail returns one row with machine-derived hints attached (mirrors functionapp).
//
// GetExecutionDetail 返单行加 machine 算的 hints。
func (s *Service) GetExecutionDetail(ctx context.Context, id string) (*ExecutionDetail, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("agentapp.GetExecutionDetail: %w", err)
	}
	row, err := s.repo.GetExecutionByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("agentapp.GetExecutionDetail: %w", err)
	}
	return &ExecutionDetail{AgentExecution: row, Hints: buildHints(ctx, s, row)}, nil
}

func buildHints(ctx context.Context, s *Service, e *agentdomain.AgentExecution) ExecutionHints {
	h := ExecutionHints{}
	switch v := e.Output.(type) {
	case nil:
		h.OutputEmpty = true
	case string:
		if v == "" {
			h.OutputEmpty = true
		}
	case []any:
		if len(v) == 0 {
			h.OutputEmpty = true
		}
	case map[string]any:
		if len(v) == 0 {
			h.OutputEmpty = true
		}
	}
	agg, err := s.repo.ComputeAggregates(ctx, agentdomain.ExecutionFilter{AgentID: e.AgentID})
	if err == nil && agg.AvgElapsedMs > 0 && e.ElapsedMs > 3*agg.AvgElapsedMs {
		h.SignificantlySlower = true
	}
	return h
}
