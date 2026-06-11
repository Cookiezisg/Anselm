package handlers

import (
	"net/http"

	"go.uber.org/zap"

	catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CatalogHandler serves GET /api/v1/catalog — the capability overview (what
// entities you have). Read-only; the menu is derived on demand, never stored.
//
// CatalogHandler 提供 GET /api/v1/catalog —— 能力概览（你有哪些实体）。只读；菜单按需
// 派生、不持久化。
type CatalogHandler struct {
	svc *catalogapp.Service
	log *zap.Logger
}

// NewCatalogHandler constructs the handler.
//
// NewCatalogHandler 构造 handler。
func NewCatalogHandler(svc *catalogapp.Service, log *zap.Logger) *CatalogHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &CatalogHandler{svc: svc, log: log.Named("handlers.catalog")}
}

// Register wires the endpoint onto mux.
//
// Register 把端点挂到 mux。
func (h *CatalogHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/catalog", h.Get)
}

// Get returns the current capability overview (summary text + coverage map).
//
// Get 返回当前能力概览（summary 文本 + coverage 映射）。
func (h *CatalogHandler) Get(w http.ResponseWriter, r *http.Request) {
	cat, err := h.svc.Get(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, cat)
}
