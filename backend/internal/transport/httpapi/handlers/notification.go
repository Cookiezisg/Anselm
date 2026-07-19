package handlers

import (
	"net/http"

	"go.uber.org/zap"

	notificationapp "github.com/sunweilin/anselm/backend/internal/app/notification"
	notificationdomain "github.com/sunweilin/anselm/backend/internal/domain/notification"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// NotificationHandler serves the notification center's REST surface (list / unread-count /
// mark-read / mark-all-read / mark-all-unread) backed by the DB. The live notifications SSE
// subscription is served by StreamHandler alongside the other two streams (one place for all three, E1).
//
// NotificationHandler 提供通知中心的 REST 面（list / unread-count / mark-read / mark-all-read /
// mark-all-unread）走 DB。实时 notifications SSE 订阅由 StreamHandler 与另两条流统一提供（三流一处，E1）。
type NotificationHandler struct {
	svc *notificationapp.Service
	log *zap.Logger
}

// NewNotificationHandler constructs the handler.
//
// NewNotificationHandler 构造 handler。
func NewNotificationHandler(svc *notificationapp.Service, log *zap.Logger) *NotificationHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &NotificationHandler{svc: svc, log: log.Named("handlers.notification")}
}

// Register wires the REST endpoints onto mux (the SSE stream is StreamHandler's).
//
// Register 把 REST 端点挂到 mux（SSE 流归 StreamHandler）。
func (h *NotificationHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/notifications", h.List)
	mux.HandleFunc("GET /api/v1/notifications/unread-count", h.UnreadCount)
	// 非 CRUD 状态变更用 :action(N5):实体级 {id}:mark-read、集合级 :mark-all-read / :mark-all-unread。
	mux.HandleFunc("POST /api/v1/notifications/{idAction}", h.postOnNotification)
	mux.HandleFunc("POST /api/v1/notifications:mark-all-read", h.MarkAllRead)
	mux.HandleFunc("POST /api/v1/notifications:mark-all-unread", h.MarkAllUnread)
}

// postOnNotification dispatches the single entity-level action POST /notifications/{id}:mark-read.
//
// postOnNotification 派发唯一的实体级动作 POST /notifications/{id}:mark-read。
func (h *NotificationHandler) postOnNotification(w http.ResponseWriter, r *http.Request) {
	id, action, ok := idAndAction(r, "idAction")
	if !ok || action != "mark-read" {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	h.markRead(w, r, id)
}

// List handles GET /api/v1/notifications — newest-first, keyset-paginated.
//
// List 处理 GET /api/v1/notifications —— 最新优先、keyset 分页。
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	items, next, err := h.svc.List(r.Context(), p.Cursor, p.Limit)
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

// markRead marks one notification read (POST /notifications/{id}:mark-read).
//
// markRead 把一条通知标已读（POST /notifications/{id}:mark-read）。
func (h *NotificationHandler) markRead(w http.ResponseWriter, r *http.Request, id string) {
	if err := h.svc.MarkRead(r.Context(), id); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// markAllBody is the OPTIONAL request body for :mark-all-read / :mark-all-unread — a half-open
// [after, before) window on created_at (RFC3339). Absent body OR an absent field → an unbounded bound,
// so a bodyless call marks the WHOLE ledger (backward compatible); the tray sends a time-group's window.
//
// markAllBody 是 :mark-all-read / :mark-all-unread 的**可选** body——created_at 上的半开窗 [after, before)
// （RFC3339）。无 body 或字段缺席 → 该界不设，故无 body 调用标**整本账**（向后兼容）；托盘发某时间组的窗口。
type markAllBody struct {
	After  string `json:"after"`
	Before string `json:"before"`
}

// parseMarkAllWindow decodes the optional window body and normalizes each bound to UTC (a non-RFC3339
// bound is a loud 422 NOTIFICATION_INVALID_WINDOW, reusing the flowrun parseListTime idiom); an empty body
// leaves both bounds zero → the whole ledger.
//
// parseMarkAllWindow 解码可选窗口 body 并把每界归一到 UTC（非 RFC3339 界大声 422，复用 flowrun 的 parseListTime）；
// 空 body 留两界为零 → 整本账。
func (h *NotificationHandler) parseMarkAllWindow(r *http.Request) (notificationdomain.MarkAllWindow, error) {
	var body markAllBody
	if err := decodeJSONOptional(r, &body); err != nil {
		return notificationdomain.MarkAllWindow{}, err
	}
	after, err := parseListTime(body.After, "after", notificationdomain.ErrInvalidWindow)
	if err != nil {
		return notificationdomain.MarkAllWindow{}, err
	}
	before, err := parseListTime(body.Before, "before", notificationdomain.ErrInvalidWindow)
	if err != nil {
		return notificationdomain.MarkAllWindow{}, err
	}
	return notificationdomain.MarkAllWindow{After: after, Before: before}, nil
}

// MarkAllRead handles POST /api/v1/notifications:mark-all-read (optional [after, before) window body).
//
// MarkAllRead 处理 POST /api/v1/notifications:mark-all-read（可选 [after, before) 窗口 body）。
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	window, err := h.parseMarkAllWindow(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.svc.MarkAllRead(r.Context(), window); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// MarkAllUnread handles POST /api/v1/notifications:mark-all-unread (the mirror of mark-all-read).
//
// MarkAllUnread 处理 POST /api/v1/notifications:mark-all-unread（mark-all-read 的镜像）。
func (h *NotificationHandler) MarkAllUnread(w http.ResponseWriter, r *http.Request) {
	window, err := h.parseMarkAllWindow(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	if err := h.svc.MarkAllUnread(r.Context(), window); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
