// Package handlers — touchpoint: the conversation context ledger's read surface. One paged
// list endpoint (N4) under the conversation sub-resource path; rows are written only by the
// backend's own taps (chat send + the loop's tool choke point), never via HTTP.
//
// handlers — touchpoint:对话上下文台账的读面。conversation 子资源路径下一个分页列表端点(N4);
// 行只由后端自己的水龙头写(chat 发送 + loop 工具咽喉),永不经 HTTP 写。
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	touchpointapp "github.com/sunweilin/anselm/backend/internal/app/touchpoint"
	touchpointdomain "github.com/sunweilin/anselm/backend/internal/domain/touchpoint"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// TouchpointHandler serves the ledger list.
//
// TouchpointHandler 提供台账列表。
type TouchpointHandler struct {
	svc *touchpointapp.Service
	log *zap.Logger
}

// NewTouchpointHandler constructs the handler.
//
// NewTouchpointHandler 构造 handler。
func NewTouchpointHandler(svc *touchpointapp.Service, log *zap.Logger) *TouchpointHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &TouchpointHandler{svc: svc, log: log.Named("handlers.touchpoint")}
}

// Register mounts the route.
//
// Register 挂载路由。
func (h *TouchpointHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/conversations/{conversationId}/touchpoints", h.List)
}

// List pages a conversation's touchpoints by recency; optional ?kind= / ?verb= filters
// (enum-checked in the app layer → TP_INVALID_KIND / TP_INVALID_VERB). An unknown
// conversation yields an empty page, mirroring the todos endpoint (an absent ledger is
// not an error).
//
// List 按新鲜度分页对话触点;可选 ?kind= / ?verb= 过滤(app 层枚举校验 → TP_INVALID_KIND /
// TP_INVALID_VERB)。未知对话返回空页,与 todos 端点一致(无台账非错误)。
func (h *TouchpointHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	q := r.URL.Query()
	items, next, err := h.svc.List(r.Context(), r.PathValue("conversationId"), q.Get("kind"), q.Get("verb"), p.Cursor, p.Limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if items == nil {
		items = []*touchpointdomain.Touchpoint{}
	}
	responsehttpapi.Paged(w, items, next, next != "")
}
