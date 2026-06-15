package reqctx

import (
	"context"
	errorspkg "github.com/sunweilin/foryx/backend/internal/pkg/errors"
)

// ErrMissingWorkspaceID is returned when ctx carries no workspace ID at a point that requires
// one — a WIRING BUG (500, KindInternal), NOT a client error. The RequireWorkspace middleware
// already rejects workspace-scoped routes that arrive without a workspace as 401
// ErrUnauthorizedNoWorkspace, so reaching RequireWorkspaceID with none means middleware was
// skipped or a detached path forgot to re-seed (see Detached). 401 is the client's case; this is ours.
//
// ErrMissingWorkspaceID 在需要 workspace 的地方 ctx 却无 workspace ID 时返回——**接线 bug**（500
// KindInternal）、**非**客户端错误。RequireWorkspace 中间件已用 401 ErrUnauthorizedNoWorkspace 拒掉无
// workspace 的隔离路由，故走到 RequireWorkspaceID 还没有 = 中间件被跳过、或 detached 路径忘了重埋（见
// Detached）。401 是客户端的事，这条是我们的。
var ErrMissingWorkspaceID = errorspkg.New(errorspkg.KindInternal, "MISSING_WORKSPACE_ID", "reqctx: missing workspace id in context")

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

// Detached returns a fresh, never-cancelled context seeded with workspaceID — the base for async
// work that must outlive the request that spawned it: a finalize that has to reach a terminal state
// even though the turn was cancelled, a best-effort background write, an auto-title (S9 "Detached
// Context"). It starts from context.Background() (NOT WithoutCancel) precisely so the parent's
// cancellation can't abort it, and re-seeds workspace_id (the minimum orm isolation needs) from the
// entity/host that owns the work — never the dead request ctx. Chain SetConversationID etc. for
// whatever else the detached work reads.
//
// Detached 返回全新、永不取消、已埋 workspaceID 的 context——异步工作的基座：必须比派生它的请求活得久的
// 工作（被取消的回合仍须落终态的 finalize、best-effort 后台写、自动标题；S9「Detached Context」）。它从
// context.Background()（**非** WithoutCancel）起，正是为让父请求的取消无法中断它，并从拥有该工作的实体/host
// 重埋 workspace_id（orm 隔离的最低要求）——绝不取已死的请求 ctx。按需链 SetConversationID 等。
func Detached(workspaceID string) context.Context {
	return SetWorkspaceID(context.Background(), workspaceID)
}
