package mcp

import (
	"context"
	"fmt"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

func (s *Store) SaveCall(ctx context.Context, c *mcpdomain.Call) error {
	if err := s.calls.Create(ctx, c); err != nil {
		return fmt.Errorf("mcpstore.SaveCall: %w", err)
	}
	return nil
}

func (s *Store) ListCalls(ctx context.Context, filter mcpdomain.CallFilter) ([]*mcpdomain.Call, string, error) {
	q := s.calls.Query()
	if filter.ServerID != "" {
		q = q.WhereEq("server_id", filter.ServerID)
	}
	if filter.Tool != "" {
		q = q.WhereEq("tool", filter.Tool)
	}
	if filter.Status != "" {
		q = q.WhereEq("status", filter.Status)
	}
	if filter.TriggeredBy != "" {
		q = q.WhereEq("triggered_by", filter.TriggeredBy)
	}
	rows, next, err := q.Page(ctx, filter.Cursor, filter.Limit)
	if err != nil {
		return nil, "", fmt.Errorf("mcpstore.ListCalls: %w", err)
	}
	return rows, next, nil
}
