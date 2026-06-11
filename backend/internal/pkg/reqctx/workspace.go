package reqctx

import (
	"context"
	"errors"
)

// ErrMissingWorkspaceID is returned when ctx carries no workspace ID (middleware didn't run).
// Treat it as a wiring bug (500), not an auth failure (401).
//
// ErrMissingWorkspaceID 在 ctx 无 workspace ID 时返回（中间件未跑）。视为接线 bug（500），非鉴权失败（401）。
var ErrMissingWorkspaceID = errors.New("reqctx: missing workspace id in context")

type workspaceIDKey struct{}

// SetWorkspaceID returns a copy of ctx carrying id.
//
// SetWorkspaceID 返回携带 id 的 ctx 拷贝。
func SetWorkspaceID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, workspaceIDKey{}, id)
}

// GetWorkspaceID returns the workspace ID; ok=false when missing or empty.
//
// GetWorkspaceID 取 workspace ID；缺失或为空时 ok=false。
func GetWorkspaceID(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(workspaceIDKey{}).(string)
	return id, ok && id != ""
}

// RequireWorkspaceID is the (string, error) form of GetWorkspaceID. Every workspace-scoped
// store/app method uses it to bubble up ErrMissingWorkspaceID.
//
// RequireWorkspaceID 是 GetWorkspaceID 的 (string, error) 版本。所有按工作区隔离的 store/app 方法用它。
func RequireWorkspaceID(ctx context.Context) (string, error) {
	id, ok := GetWorkspaceID(ctx)
	if !ok {
		return "", ErrMissingWorkspaceID
	}
	return id, nil
}
