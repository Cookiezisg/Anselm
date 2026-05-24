package middleware

import (
	"context"
	"net/http"

	userdomain "github.com/sunweilin/forgify/backend/internal/domain/user"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// HeaderUserID is the per-request profile selector; client (Wails / browser)
// reads it from localStorage.activeUserId and sends it on every request.
//
// HeaderUserID:per-request profile 选择 header;客户端从 localStorage 读后填入。
const HeaderUserID = "X-Forgify-User-ID"

// UserResolver is the minimal port the auth middleware needs from userapp.Service.
//
// UserResolver:auth middleware 所需 userapp.Service 端口。
type UserResolver interface {
	Get(ctx context.Context, id string) (*userdomain.User, error)
}

// IdentifyUser reads X-Forgify-User-ID (or ?userID= for SSE) and stamps
// ctx with the validated user id. Unknown / missing id → ctx left empty;
// downstream RequireUser middleware will 401 if the route needs a user.
//
// IdentifyUser 读 X-Forgify-User-ID(SSE 用 ?userID=),校验后写入 ctx;
// 不识别/缺失 → ctx 不带 user,由 RequireUser 决定是否 401。
func IdentifyUser(resolver UserResolver) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			uid := r.Header.Get(HeaderUserID)
			if uid == "" {
				uid = r.URL.Query().Get("userID")
			}
			if uid != "" && resolver != nil {
				if _, err := resolver.Get(r.Context(), uid); err != nil {
					uid = "" // unknown id → treat as missing
				}
			}
			ctx := r.Context()
			if uid != "" {
				ctx = reqctxpkg.SetUserID(ctx, uid)
			}
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequireUser rejects requests whose ctx has no user id with 401 /
// UNAUTH_NO_USER. Mount on every user-scoped route. Skip on /users CRUD
// and any liveness endpoints — those must work pre-onboarding.
//
// RequireUser:ctx 无 user 时 401;挂在所有用户路由上;/users CRUD 与
// 健康检查路由例外(需要在 onboarding 前可用)。
func RequireUser(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := reqctxpkg.GetUserID(r.Context()); !ok {
			responsehttpapi.Error(w, http.StatusUnauthorized, "UNAUTH_NO_USER",
				"no valid user identifier; client should clear activeUserId and re-onboard", nil)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// InjectUserID is a test-only middleware that stamps a fixed "test-user" id
// for handler-level unit tests that don't need the full IdentifyUser flow.
// Production wiring uses IdentifyUser + RequireUser.
//
// InjectUserID:test-only,固定塞 "test-user";生产用 IdentifyUser+RequireUser。
func InjectUserID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := reqctxpkg.SetUserID(r.Context(), "test-user")
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// InjectUserIDWith is a deprecated alias kept for legacy callers. The
// resolver argument is ignored — behaves identically to InjectUserID.
// New code should use IdentifyUser + RequireUser instead.
//
// InjectUserIDWith:legacy 兼容别名;resolver 被忽略,行为同 InjectUserID。
func InjectUserIDWith(_ UserResolver) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler { return InjectUserID(next) }
}
