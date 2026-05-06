// conversation.go — HTTP handler for /api/v1/conversations/*.
//
// conversation.go — /api/v1/conversations/* 的 HTTP handler。
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	convapp "github.com/sunweilin/forgify/backend/internal/app/conversation"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	paginationpkg "github.com/sunweilin/forgify/backend/internal/pkg/pagination"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// ConversationHandler serves the 4 /api/v1/conversations/* endpoints.
//
// ConversationHandler 提供 /api/v1/conversations/* 的 4 个端点。
type ConversationHandler struct {
	svc *convapp.Service
	log *zap.Logger
}

// NewConversationHandler wires the handler dependencies.
//
// NewConversationHandler 装配 handler 依赖。
func NewConversationHandler(svc *convapp.Service, log *zap.Logger) *ConversationHandler {
	return &ConversationHandler{svc: svc, log: log}
}

// Register attaches conversation routes.
//
// Register 挂载对话路由。
func (h *ConversationHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/conversations", h.Create)
	mux.HandleFunc("GET /api/v1/conversations", h.List)
	mux.HandleFunc("GET /api/v1/conversations/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/conversations/{id}", h.Rename)
	mux.HandleFunc("DELETE /api/v1/conversations/{id}", h.Delete)
}

type createConvRequest struct {
	Title string `json:"title"`
}

// updateConvRequest is the partial-PATCH body. Each field is a pointer so
// "absent in JSON" (skip) is distinguishable from "present with empty
// string" (explicit clear). Title-only requests still work — clients that
// previously sent {"title":"X"} get the same behavior.
//
// updateConvRequest 是部分 PATCH body。每字段用指针区分"未传"和"传空"。
type updateConvRequest struct {
	Title        *string `json:"title,omitempty"`
	SystemPrompt *string `json:"systemPrompt,omitempty"`
}

// Create: POST /api/v1/conversations → 201.
//
// Create：POST /api/v1/conversations → 201。
func (h *ConversationHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createConvRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	c, err := h.svc.Create(r.Context(), req.Title)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, c)
}

// List: GET /api/v1/conversations?cursor=&limit= → 200 paged.
//
// List：GET /api/v1/conversations?cursor=&limit= → 200 分页。
func (h *ConversationHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := paginationpkg.Parse(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.List(r.Context(), convdomain.ListFilter{
		Cursor: p.Cursor,
		Limit:  p.Limit,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

// Get: GET /api/v1/conversations/{id} → 200 with the full entity (incl.
// systemPrompt). Used by testend's per-conversation system-prompt editor.
//
// Get：GET /api/v1/conversations/{id} → 200 返完整实体（含 systemPrompt）。
func (h *ConversationHandler) Get(w http.ResponseWriter, r *http.Request) {
	c, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// Rename handles PATCH /api/v1/conversations/{id} → 200. Despite the
// historic method name, this is a general partial-update accepting either
// title (legacy) or systemPrompt (TE-13). Either or both may be set;
// fields not in the JSON body are left untouched.
//
// Rename 处理 PATCH /api/v1/conversations/{id} → 200。
// 名义是 Rename，实为通用部分更新——接 title 和/或 systemPrompt。
func (h *ConversationHandler) Rename(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	var req updateConvRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	c, err := h.svc.Update(r.Context(), id, req.Title, req.SystemPrompt)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// Delete: DELETE /api/v1/conversations/{id} → 204.
//
// Delete：DELETE /api/v1/conversations/{id} → 204。
func (h *ConversationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
