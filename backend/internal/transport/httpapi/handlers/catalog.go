// catalog.go — HTTP transport for the Capability Catalog. Per
// catalog.md §9 just 2 endpoints — the catalog is mostly an internal
// component; these endpoints exist for testend debugging and for the
// UI's "Refresh now" affordance.
//
// 2 endpoints (both registered literally — no {wildcard} dispatch):
//   GET    /api/v1/catalog            return current cached Catalog
//                                     (or null when no Refresh has
//                                     produced one yet — boot window
//                                     or all-sources-failed)
//   POST   /api/v1/catalog:refresh    force immediate Service.Refresh
//                                     (bypasses the 1s polling cadence)
//
// catalog.go ——Capability Catalog 的 HTTP transport。catalog.md §9：仅 2
// 端点——catalog 多为内部组件；这两个为 testend 调试 + UI "立即刷新"。
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CatalogHandler hosts the 2 catalog endpoints. log is for handler-side
// instrumentation (rare; most observability comes from the Service +
// pollLoop layers).
//
// CatalogHandler 持 2 个 catalog 端点。log 给 handler 侧 instrumentation
// （罕见；observability 多在 Service + pollLoop）。
type CatalogHandler struct {
	svc *catalogapp.Service
	log *zap.Logger
}

// NewCatalogHandler constructs a CatalogHandler.
//
// NewCatalogHandler 构造 CatalogHandler。
func NewCatalogHandler(svc *catalogapp.Service, log *zap.Logger) *CatalogHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &CatalogHandler{svc: svc, log: log.Named("handlers.catalog")}
}

// Register attaches the 2 routes to mux.
//
// Register 把 2 路由挂到 mux。
func (h *CatalogHandler) Register(mux *http.ServeMux) {
	// Both paths are literal — no {wildcard} or :action dispatch needed.
	// 两路径均字面——无 {wildcard} 或 :action dispatch 需要。
	mux.HandleFunc("GET /api/v1/catalog", h.Get)
	mux.HandleFunc("POST /api/v1/catalog:refresh", h.Refresh)
}

// Get returns the current cached Catalog. Returns the wrapped struct
// when present; returns null inside the envelope when the cache hasn't
// been built yet (boot window before first Refresh, or all-sources-
// failed scenario where Service kept its prior cache).
//
// Get 返当前缓存 Catalog。存在则返包装 struct；cache 未构造时（首
// Refresh 前 boot 窗口 / 全 source 挂保留前 cache 情形）envelope 内 null。
func (h *CatalogHandler) Get(w http.ResponseWriter, _ *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.Get())
}

// Refresh forces an immediate Service.Refresh (bypasses the 1s polling
// cadence). Returns the resulting Catalog so the UI's "Refresh now"
// button can render the updated content without a follow-up GET.
// Single-flight behavior is preserved: if a polling tick is already
// running concurrently, this Refresh waits its turn (Service uses a
// mutex internally for the cache write phase).
//
// Refresh 强制立即 Service.Refresh（绕过 1s 轮询）。返结果 Catalog 让 UI
// "立即刷新" 按钮无需再 GET 即可渲染。Single-flight 保留：若 polling
// tick 并发跑中，本 Refresh 等其完成（Service 内部 cache 写阶段持锁）。
func (h *CatalogHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Refresh(r.Context()); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, h.svc.Get())
}
