//go:build pipeline

package harness

import (
	"testing"
)

// Phase 3 collapsed this file: the LocalCtxAs free-function alias was removed
// (use CtxAs in ctx.go), so only the action helpers remain. They could move
// to a dedicated actions.go later; for now they stay here as "test-side
// imperative shortcuts that wrap an HTTP call + decode + assert".
//
// Phase 3 收尾:LocalCtxAs alias 已删(用 ctx.go::CtxAs);仅留动作 helper。
// 后续可考虑搬去 actions.go,此处保留作"包了 HTTP 调用 + 解码 + 断言的命令式快捷"。

// PostMessage POSTs a user message and returns its allocated ID; fatals on empty.
//
// PostMessage POST 用户消息,返其 ID;空则 fatal。
func PostMessage(t *testing.T, h *Harness, convID, content string) string {
	t.Helper()
	var resp struct {
		Data struct {
			MessageID string `json:"messageId"`
		} `json:"data"`
	}
	h.PostJSON("/api/v1/conversations/"+convID+"/messages",
		map[string]any{"content": content}, &resp)
	if resp.Data.MessageID == "" {
		t.Fatalf("PostMessage: empty messageId in response")
	}
	return resp.Data.MessageID
}

// PostFunction is shorthand for POST /api/v1/functions.
//
// PostFunction 是 POST /api/v1/functions 的简写。
func PostFunction(t *testing.T, h *Harness, name, code string, out any) int {
	t.Helper()
	return DoRequest(t, h, "POST", "/api/v1/functions", map[string]any{
		"name": name,
		"code": code,
	}, out)
}
