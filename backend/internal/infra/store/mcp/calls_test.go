package mcp

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// TestCalls_RoundTripAndIsolation: a saved call lists back with its fields, filtered by server,
// newest-first, and never crosses workspaces (D2).
//
// TestCalls_RoundTripAndIsolation：保存的调用按字段读回、按 server 过滤、最新在前，且绝不跨 workspace（D2）。
func TestCalls_RoundTripAndIsolation(t *testing.T) {
	s, _ := newStore(t)
	ws1 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	ws2 := reqctxpkg.SetWorkspaceID(context.Background(), "ws_2")

	now := time.Now().UTC()
	save := func(ctx context.Context, id, server, tool string) {
		t.Helper()
		if err := s.SaveCall(ctx, &mcpdomain.Call{
			ID: id, ServerID: server, Tool: tool,
			Status: mcpdomain.CallStatusOK, TriggeredBy: mcpdomain.CallTriggeredByChat,
			Input: json.RawMessage(`{"q":1}`), Output: "out",
			StartedAt: now, EndedAt: now,
		}); err != nil {
			t.Fatalf("SaveCall: %v", err)
		}
	}
	save(ws1, "mcl_1", "mcp_a", "search")
	save(ws1, "mcl_2", "mcp_b", "fetch")
	save(ws2, "mcl_3", "mcp_a", "search")

	rows, _, err := s.ListCalls(ws1, mcpdomain.CallFilter{ServerID: "mcp_a"})
	if err != nil {
		t.Fatalf("ListCalls: %v", err)
	}
	if len(rows) != 1 || rows[0].ID != "mcl_1" || rows[0].Tool != "search" || rows[0].Output != "out" {
		t.Fatalf("round-trip wrong: %+v", rows)
	}
	if string(rows[0].Input) != `{"q":1}` {
		t.Fatalf("input JSON lost: %s", rows[0].Input)
	}
	// ws_2 sees only its own call even with no server filter.
	rows2, _, err := s.ListCalls(ws2, mcpdomain.CallFilter{})
	if err != nil || len(rows2) != 1 || rows2[0].ID != "mcl_3" {
		t.Fatalf("workspace isolation broken: %v %+v", err, rows2)
	}
}
