// executions.go — Service wrappers around the execution-log repo (D22). The
// LLM tools (search_function_executions / get_function_execution) and the
// HTTP /functions/{id}/executions endpoint go through these, so HTTP /
// LLM never touch the repo directly (S8).
//
// executions.go —— Service 包 execution-log repo(D22)。LLM 工具 + HTTP
// 端点经此,handler 不直接碰 repo(S8)。

package function

import (
	"context"
	"fmt"

	functiondomain "github.com/sunweilin/forgify/backend/internal/domain/function"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// SearchExecutionsResult is the response shape for SearchExecutions (and the
// search_function_executions LLM tool).
//
// SearchExecutionsResult 是 SearchExecutions 的响应形状。
type SearchExecutionsResult struct {
	Count      int                                  `json:"count"`
	Executions []*functiondomain.Execution          `json:"executions"`
	NextCursor string                               `json:"nextCursor,omitempty"`
	HasMore    bool                                 `json:"hasMore"`
	Aggregates functiondomain.ExecutionAggregates   `json:"aggregates"`
}

// ExecutionDetail is the shape returned by GetExecutionDetail (and the
// get_function_execution LLM tool). Adds machine-computed hints to the raw
// row to fast-track LLM diagnosis (per spec/08-executions.md §7.3).
//
// ExecutionDetail 是 GetExecutionDetail 的返回。在原行上追加 hints 字段加速
// LLM 诊断(spec §7.3)。
type ExecutionDetail struct {
	*functiondomain.Execution
	Hints ExecutionHints `json:"hints"`
}

// ExecutionHints flags non-obvious signals on the row that the LLM should not
// have to recompute. Currently 2 hints; spec §7.3 lists 3 (duplicates_previous
// _input requires comparing to prior rows — deferred to a future revision).
//
// ExecutionHints 标记 LLM 不必重算的信号。当前 2 个(duplicates_previous_input
// 需横比往期行,留后续版本)。
type ExecutionHints struct {
	OutputEmpty           bool `json:"outputEmpty"`
	SignificantlySlower   bool `json:"significantlySlower"`
}

// SearchExecutions runs a paginated execution-log query with aggregates.
//
// SearchExecutions 跑分页 execution-log 查询 + 聚合。
func (s *Service) SearchExecutions(ctx context.Context, filter functiondomain.ExecutionFilter) (*SearchExecutionsResult, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.SearchExecutions: %w", err)
	}
	rows, next, err := s.repo.ListExecutions(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("functionapp.SearchExecutions: %w", err)
	}
	agg, err := s.repo.ComputeAggregates(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("functionapp.SearchExecutions: aggregates: %w", err)
	}
	return &SearchExecutionsResult{
		Count:      len(rows),
		Executions: rows,
		NextCursor: next,
		HasMore:    next != "",
		Aggregates: agg,
	}, nil
}

// GetExecutionDetail returns one row with machine-derived hints attached.
//
// GetExecutionDetail 返单行 + machine 算的 hints。
func (s *Service) GetExecutionDetail(ctx context.Context, id string) (*ExecutionDetail, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("functionapp.GetExecutionDetail: %w", err)
	}
	row, err := s.repo.GetExecutionByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("functionapp.GetExecutionDetail: %w", err)
	}
	hints := buildHints(ctx, s, row)
	return &ExecutionDetail{Execution: row, Hints: hints}, nil
}

// buildHints computes the two cheap hint flags. significantlySlower compares
// against the entity's p50 (queried via ComputeAggregates over the same
// function_id) — 3x p50 threshold per spec.
//
// buildHints 计算 2 个便宜的 hint。significantlySlower 跟同 function 的 p50
// 比(经 ComputeAggregates),3x p50 阈值(spec §7.3)。
func buildHints(ctx context.Context, s *Service, e *functiondomain.Execution) ExecutionHints {
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
	agg, err := s.repo.ComputeAggregates(ctx, functiondomain.ExecutionFilter{FunctionID: e.FunctionID})
	if err == nil && agg.P95ElapsedMs > 0 {
		if e.ElapsedMs > 3*agg.AvgElapsedMs && agg.AvgElapsedMs > 0 {
			h.SignificantlySlower = true
		}
	}
	return h
}
