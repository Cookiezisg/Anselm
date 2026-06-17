package router

import (
	"net/http"
	"strings"

	"go.uber.org/zap"

	middlewarehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/middleware"
)

// Chain wraps h with the standard middleware stack, outermost first:
//
//	Recover → RequestLogger → CORS → InjectLocale → IdentifyWorkspace → RequireWorkspace(exempt)
//
// resolver may be nil (validation skipped) before the workspace module is wired. bootstrap
// builds the mux, registers every handler, then passes the result through Chain.
//
// Chain 用标准中间件栈包裹 h（最外层在前）：Recover → RequestLogger → CORS → InjectLocale →
// IdentifyWorkspace → RequireWorkspace(豁免)。resolver 在 workspace 模块接线前可为 nil（跳过校验）。
// bootstrap 构造 mux、注册所有 handler 后把结果过 Chain。
func Chain(h http.Handler, log *zap.Logger, resolver middlewarehttpapi.WorkspaceResolver) http.Handler {
	h = requireWorkspaceExempt(h)
	h = middlewarehttpapi.IdentifyWorkspace(resolver)(h)
	h = middlewarehttpapi.InjectLocale(h)
	h = middlewarehttpapi.CORS(middlewarehttpapi.DefaultCORSConfig())(h)
	h = middlewarehttpapi.RequestLogger(log)(h)
	h = middlewarehttpapi.Recover(log)(h)
	return h
}

// requireWorkspaceExempt applies RequireWorkspace to all /api/v1/* routes EXCEPT the ones
// that must work without a workspace header:
//   - /api/v1/workspaces — onboarding must create a workspace first
//   - /api/v1/health — liveness probe
//   - /api/v1/providers, /api/v1/scenarios — static metadata the onboarding UI reads
//   - /api/v1/webhooks/ — EXTERNAL callers (GitHub etc.) can never send the workspace
//     header; the webhook listener authenticates with its own secret/HMAC and the trigger
//     app resolves the workspace from the trigger's registration at report time
//
// Non-/api/v1/* paths pass through (mux handles NotFound / static assets).
//
// requireWorkspaceExempt 给所有 /api/v1/* 套 RequireWorkspace，但豁免无法带 workspace header 的：
// /workspaces（创建工作区）、/health（健康检查）、/providers + /scenarios（静态元数据）、
// /webhooks/（**外部**调用方如 GitHub 不可能带 header；webhook 监听器自带 secret/HMAC 鉴权，
// workspace 由 trigger app 在 report 时从注册表解析）。非 /api/v1/* 路径放过。
func requireWorkspaceExempt(next http.Handler) http.Handler {
	guarded := middlewarehttpapi.RequireWorkspace(next)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p := r.URL.Path
		if !strings.HasPrefix(p, "/api/v1/") ||
			strings.HasPrefix(p, "/api/v1/workspaces") ||
			strings.HasPrefix(p, "/api/v1/webhooks/") ||
			p == "/api/v1/health" ||
			p == "/api/v1/providers" ||
			p == "/api/v1/scenarios" {
			next.ServeHTTP(w, r)
			return
		}
		guarded.ServeHTTP(w, r)
	})
}
