//go:build pipeline

package harness

import (
	"context"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// DefaultUserID is the canonical local user ID used across pipeline tests;
// shares value with SeedTestUserID (seed.go) so HTTP auto-inject and direct
// Service-call paths share one identity. Tests own this constant; backend's
// reqctxpkg deliberately exposes no test-specific equivalent.
//
// DefaultUserID 是 pipeline 测试公用本地用户 ID,与 SeedTestUserID(seed.go)
// 同值——确保 HTTP 自动注入 header 与直调 Service 方法走同一身份。
// 测试自管;后端 reqctxpkg 故意不暴露测试专用常量。
const DefaultUserID = SeedTestUserID

// CtxAs returns a context stamped with the given userID via reqctxpkg.SetUserID.
// Phase 1 will retire helpers.go's package-level LocalCtxAs in favor of this name.
//
// CtxAs 用 reqctxpkg.SetUserID 返回打了指定 userID 的 ctx。Phase 1 起
// 取代 helpers.go 里同义的 LocalCtxAs。
func CtxAs(userID string) context.Context {
	return reqctxpkg.SetUserID(context.Background(), userID)
}

// DefaultCtx is CtxAs(DefaultUserID); anchor for tests that don't pin a user.
//
// DefaultCtx 等价 CtxAs(DefaultUserID),不固定 user 的测试用作锚点。
func DefaultCtx() context.Context { return CtxAs(DefaultUserID) }
