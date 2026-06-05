package handlers

import (
	"net/http"
	"strconv"

	"go.uber.org/zap"

	notificationapp "github.com/sunweilin/forgify/backend/internal/app/notification"
	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// NotificationHandler serves the notification center: REST (list / unread-count /
// mark-read / mark-all-read) backed by the DB, plus the live notifications SSE stream.
//
// NotificationHandler 提供通知中心：REST（list / unread-count / mark-read / mark-all-read）
// 走 DB，加上实时 notifications SSE 流。
type NotificationHandler struct {
	svc    *notificationapp.Service
	bridge streamdomain.Bridge // notifications stream (subscribe)
	log    *zap.Logger
}

// NewNotificationHandler constructs the handler. bridge is the notifications stream
// (injected at boot, M7); nil disables the SSE endpoint's subscribe.
//
// NewNotificationHandler 构造 handler。bridge 是 notifications 流（boot 装配，M7）。
func NewNotificationHandler(svc *notificationapp.Service, bridge streamdomain.Bridge, log *zap.Logger) *NotificationHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &NotificationHandler{svc: svc, bridge: bridge, log: log.Named("handlers.notification")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *NotificationHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/notifications", h.List)
	mux.HandleFunc("GET /api/v1/notifications/unread-count", h.UnreadCount)
	mux.HandleFunc("PUT /api/v1/notifications/{id}/read", h.MarkRead)
	mux.HandleFunc("POST /api/v1/notifications/read-all", h.MarkAllRead)
	mux.HandleFunc("GET /api/v1/notifications/stream", h.Subscribe)
}

// List handles GET /api/v1/notifications — newest-first, keyset-paginated.
//
// List 处理 GET /api/v1/notifications —— 最新优先、keyset 分页。
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit := 0
	if raw := q.Get("limit"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 {
			limit = n
		}
	}
	items, next, err := h.svc.List(r.Context(), q.Get("cursor"), limit)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Paged(w, items, next, next != "")
}

// UnreadCount handles GET /api/v1/notifications/unread-count — the badge number.
//
// UnreadCount 处理 GET /api/v1/notifications/unread-count —— badge 数。
func (h *NotificationHandler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	n, err := h.svc.CountUnread(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]int{"unread": n})
}

// MarkRead handles PUT /api/v1/notifications/{id}/read.
//
// MarkRead 处理 PUT /api/v1/notifications/{id}/read。
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.MarkRead(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// MarkAllRead handles POST /api/v1/notifications/read-all.
//
// MarkAllRead 处理 POST /api/v1/notifications/read-all。
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.MarkAllRead(r.Context()); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// Subscribe handles GET /api/v1/notifications/stream — the live SSE subscription.
// fromSeq comes from Last-Event-ID (or ?fromSeq) and resumes durable frames from the
// replay ring; too old → 410, the client refetches history via List.
//
// Subscribe 处理 GET /api/v1/notifications/stream —— 实时 SSE 订阅。fromSeq 取自
// Last-Event-ID（或 ?fromSeq），从 replay 环续传 durable 帧；太旧 → 410，客户端经 List 重取。
func (h *NotificationHandler) Subscribe(w http.ResponseWriter, r *http.Request) {
	var fromSeq int64
	if v := r.Header.Get("Last-Event-ID"); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			fromSeq = n
		}
	} else if v := r.URL.Query().Get("fromSeq"); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			fromSeq = n
		}
	}
	ch, cancel, err := h.bridge.Subscribe(r.Context(), fromSeq)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	defer cancel()
	responsehttpapi.StreamSSE(w, r, nil, ch, responsehttpapi.WriteStreamEnvelope)
}
