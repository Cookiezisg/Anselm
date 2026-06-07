package mcp

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// CallTool routes a tool/call to the server's connected client with a per-call timeout, and
// updates health counters (3 consecutive failures → degraded; a success → back to ready).
// serverID is the mcp_ id; the dynamic tool adapter and HTTP handler resolve it first.
//
// CallTool 用 per-call 超时把 tool/call 路由到 server 的已连接 client，并更新健康计数（连续 3 次
// 失败 → degraded；一次成功 → 恢复 ready）。serverID 是 mcp_ id；动态工具适配器与 HTTP handler 先解析它。
func (s *Service) CallTool(ctx context.Context, serverID, tool string, args json.RawMessage) (string, error) {
	s.mu.RLock()
	client := s.clients[serverID]
	st := s.states[serverID]
	s.mu.RUnlock()

	if st == nil {
		return "", fmt.Errorf("mcpapp.CallTool: %w: %q", mcpdomain.ErrServerNotFound, serverID)
	}
	if client == nil || !mcpdomain.IsCallable(st.Status) {
		return "", fmt.Errorf("mcpapp.CallTool %s: %w (status=%s)", st.Name, mcpdomain.ErrServerNotConnected, st.Status)
	}

	cctx, cancel := context.WithTimeout(ctx, defaultCallTimeout)
	defer cancel()
	result, err := client.CallTool(cctx, tool, args)
	s.recordResult(serverID, err)
	return result, err
}

// recordResult bumps per-server health counters; consecutive failures/successes flip
// degraded/ready. Holds s.mu.
//
// recordResult 更新 per-server 健康计数；连续失败/成功翻转 degraded/ready。持 s.mu。
func (s *Service) recordResult(id string, callErr error) {
	now := time.Now().UTC()
	s.mu.Lock()
	defer s.mu.Unlock()
	st := s.states[id]
	if st == nil {
		return
	}
	st.TotalCalls++
	if callErr != nil {
		st.TotalFailures++
		st.ConsecutiveFailures++
		st.LastError = callErr.Error()
		st.LastErrorAt = &now
		if st.ConsecutiveFailures >= mcpdomain.DegradedThreshold && st.Status == mcpdomain.StatusReady {
			st.Status = mcpdomain.StatusDegraded
		}
	} else {
		st.ConsecutiveFailures = 0
		if st.Status == mcpdomain.StatusDegraded {
			st.Status = mcpdomain.StatusReady
		}
	}
}
