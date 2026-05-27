//go:build pipeline

package harness

import (
	"context"
	"testing"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// LocalCtxAs returns a context stamped with the given userID.
//
// Deprecated (Phase 1): superseded by CtxAs in ctx.go; same behavior, kept as
// alias until Phase 3 deletes this file's remaining functions.
//
// LocalCtxAs 返回打了指定 userID 的 ctx。
// Deprecated(Phase 1):同义于 ctx.go 的 CtxAs;保留至 Phase 3 删本文件。
func LocalCtxAs(userID string) context.Context {
	return reqctxpkg.SetUserID(context.Background(), userID)
}

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
