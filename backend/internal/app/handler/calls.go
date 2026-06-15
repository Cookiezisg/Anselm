package handler

import (
	"context"
	"fmt"

	handlerdomain "github.com/sunweilin/foryx/backend/internal/domain/handler"
)

// SearchCallsResult is the response shape for SearchCalls: a page of rows + ok/failed rollup.
//
// SearchCallsResult 是 SearchCalls 的响应形状：一页行 + ok/failed 汇总。
type SearchCallsResult struct {
	Calls      []*handlerdomain.Call        `json:"calls"`
	NextCursor string                       `json:"nextCursor,omitempty"`
	HasMore    bool                         `json:"hasMore"`
	Aggregates handlerdomain.CallAggregates `json:"aggregates"`
}

// SearchCalls runs a paginated call-log query with the ok/failed rollup.
func (s *Service) SearchCalls(ctx context.Context, filter handlerdomain.CallFilter) (*SearchCallsResult, error) {
	rows, next, err := s.repo.ListCalls(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.SearchCalls: %w", err)
	}
	agg, err := s.repo.ComputeCallAggregates(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.SearchCalls: aggregates: %w", err)
	}
	return &SearchCallsResult{Calls: rows, NextCursor: next, HasMore: next != "", Aggregates: agg}, nil
}

// GetCall returns one call-log row verbatim.
func (s *Service) GetCall(ctx context.Context, id string) (*handlerdomain.Call, error) {
	c, err := s.repo.GetCallByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("handlerapp.GetCall: %w", err)
	}
	return c, nil
}
