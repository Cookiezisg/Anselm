// calls.go — Service wrappers around the call-log repo (D22). LLM tools
// (search_handler_calls / get_handler_call) and HTTP /handlers/{id}/calls
// go through these.
//
// calls.go —— Service 包 call-log repo(D22);LLM tools + HTTP 经此。

package handler

import (
	"context"
	"fmt"

	handlerdomain "github.com/sunweilin/forgify/backend/internal/domain/handler"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// SearchCallsResult is the response shape for SearchCalls.
//
// SearchCallsResult SearchCalls 的响应形状。
type SearchCallsResult struct {
	Count      int                            `json:"count"`
	Calls      []*handlerdomain.Call          `json:"calls"`
	NextCursor string                         `json:"nextCursor,omitempty"`
	HasMore    bool                           `json:"hasMore"`
	Aggregates handlerdomain.CallAggregates   `json:"aggregates"`
}

// CallDetail wraps a Call with machine-derived hints.
//
// CallDetail Call + machine hints。
type CallDetail struct {
	*handlerdomain.Call
	Hints CallHints `json:"hints"`
}

// CallHints flags non-obvious signals.
//
// CallHints 标记非显然信号。
type CallHints struct {
	OutputEmpty         bool `json:"outputEmpty"`
	SignificantlySlower bool `json:"significantlySlower"`
}

// SearchCalls runs a paginated call-log query with aggregates.
//
// SearchCalls 跑分页 call-log 查询 + 聚合。
func (s *Service) SearchCalls(ctx context.Context, filter handlerdomain.CallFilter) (*SearchCallsResult, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("handlerapp.SearchCalls: %w", err)
	}
	rows, next, err := s.repo.ListCalls(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.SearchCalls: %w", err)
	}
	agg, err := s.repo.ComputeCallAggregates(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.SearchCalls: aggregates: %w", err)
	}
	return &SearchCallsResult{
		Count:      len(rows),
		Calls:      rows,
		NextCursor: next,
		HasMore:    next != "",
		Aggregates: agg,
	}, nil
}

// GetCallDetail returns one call row + hints.
//
// GetCallDetail 返单 call 行 + hints。
func (s *Service) GetCallDetail(ctx context.Context, id string) (*CallDetail, error) {
	if _, err := reqctxpkg.RequireUserID(ctx); err != nil {
		return nil, fmt.Errorf("handlerapp.GetCallDetail: %w", err)
	}
	row, err := s.repo.GetCallByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.GetCallDetail: %w", err)
	}
	hints := buildCallHints(ctx, s, row)
	return &CallDetail{Call: row, Hints: hints}, nil
}

// buildCallHints computes the cheap hint flags (same shape as function).
//
// buildCallHints 算便宜 hint(跟 function 同形)。
func buildCallHints(ctx context.Context, s *Service, c *handlerdomain.Call) CallHints {
	h := CallHints{}
	switch v := c.Output.(type) {
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
	agg, err := s.repo.ComputeCallAggregates(ctx, handlerdomain.CallFilter{HandlerID: c.HandlerID, Method: c.Method})
	if err == nil && agg.AvgElapsedMs > 0 && c.ElapsedMs > 3*agg.AvgElapsedMs {
		h.SignificantlySlower = true
	}
	return h
}
