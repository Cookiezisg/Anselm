// Package reqctx carries per-request metadata (user identity, locale)
// through ctx so any layer can read it without reverse dependencies.
//
// Package reqctx 通过 ctx 传递每次请求的元数据（用户身份、locale），
// 让任何层都能读取而不制造反向依赖。
package reqctx

import (
	"context"
	"errors"
)

// ErrMissingUserID is returned by RequireUserID when no user ID is present
// in ctx (auth middleware didn't run). Treat as a server-side wiring bug
// (HTTP 500), not as auth failure (401).
//
// ErrMissingUserID 由 RequireUserID 在 ctx 中无 user ID 时返回（auth 中间件未跑）。
// 视为服务端接线 bug（HTTP 500），而非鉴权失败（401）。
var ErrMissingUserID = errors.New("reqctx: missing user id in context")

// DefaultLocalUserID is the hardcoded user ID used by Phase 2 single-user mode.
// Will be replaced by real auth extraction later.
//
// DefaultLocalUserID 是 Phase 2 单用户模式的硬编码 ID，未来被真实 auth 替换。
const DefaultLocalUserID = "local-user"

type userIDKey struct{}

// SetUserID returns a copy of ctx carrying the given user ID.
//
// SetUserID 返回携带给定 user ID 的 ctx 拷贝。
func SetUserID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, userIDKey{}, id)
}

// GetUserID retrieves the user ID. A false result means the auth
// middleware didn't run or an empty string was stored — treat as
// a server-side wiring bug (respond 500), not as 401.
//
// GetUserID 取用户 ID。返回 false 表示 auth 中间件未跑或存的是空串——
// 视为服务端接线 bug 返回 500，而非 401。
func GetUserID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey{}).(string)
	return id, ok && id != ""
}

// RequireUserID is the (string, error) variant of GetUserID for callers
// that want to bubble up ErrMissingUserID rather than handle a bool.
// All store/app methods scoped to a user should use this.
//
// RequireUserID 是 GetUserID 的 (string, error) 版本，供希望直接上抛
// ErrMissingUserID 而不处理 bool 的调用者使用。
// 所有按用户过滤的 store / app 方法都应该用它。
func RequireUserID(ctx context.Context) (string, error) {
	id, ok := GetUserID(ctx)
	if !ok {
		return "", ErrMissingUserID
	}
	return id, nil
}
