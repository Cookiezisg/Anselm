// notifications.go — SSE handler for the global notifications stream.
//
// Wire format per event:
//
//	event: notification
//	id: <seq>
//	data: <Event JSON>
//
// Reconnect: client sends `Last-Event-ID: N` header → server replays
// buffered envelopes with seq > N then live; past buffer returns
// 410 Gone + code=SEQ_TOO_OLD; client resubscribes with no Last-Event-ID
// (loses missed events; for entity snapshots that's typically fine
// because subsequent state changes will re-push the entity).
//
// notifications.go ——全局通知流 SSE handler。
//
// 重连：客户端发 `Last-Event-ID: N` → 服务端 replay buffer 中 seq > N
// 再接实时；超 buffer 返 410 Gone + code=SEQ_TOO_OLD；客户端不带
// Last-Event-ID 重订（漏掉错过事件；entity 快照场景通常 OK——下次状态
// 变化会再推 entity）。
package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	notificationsdomain "github.com/sunweilin/forgify/backend/internal/domain/notifications"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// NotificationsHandler exposes /api/v1/notifications as a global SSE
// stream backed by the notifications Bridge.
//
// NotificationsHandler 把 /api/v1/notifications 暴露为通知 Bridge 支撑
// 的全局 SSE 流。
type NotificationsHandler struct {
	bridge notificationsdomain.Bridge
	log    *zap.Logger
}

// NewNotificationsHandler wires the handler dependencies.
//
// NewNotificationsHandler 装配 handler 依赖。
func NewNotificationsHandler(bridge notificationsdomain.Bridge, log *zap.Logger) *NotificationsHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &NotificationsHandler{bridge: bridge, log: log.Named("notifications.handler")}
}

// Register attaches the SSE route.
//
// Register 挂 SSE 路由。
func (h *NotificationsHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/notifications", h.Stream)
}

// Stream serves GET /api/v1/notifications.
//
// Stream 服务 GET /api/v1/notifications。
func (h *NotificationsHandler) Stream(w http.ResponseWriter, r *http.Request) {
	var fromSeq int64
	if v := r.Header.Get("Last-Event-ID"); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n > 0 {
			fromSeq = n
		}
	}

	ch, cancelSub, err := h.bridge.Subscribe(r.Context(), fromSeq)
	if err != nil {
		if errors.Is(err, notificationsdomain.ErrSeqTooOld) {
			responsehttpapi.Error(w, http.StatusGone, "SEQ_TOO_OLD",
				"requested Last-Event-ID has been evicted from the replay buffer; resubscribe without it",
				nil)
			return
		}
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	defer cancelSub()

	responsehttpapi.StreamSSE(w, r, nil, ch,
		func(out io.Writer, env notificationsdomain.Envelope) error {
			data, err := json.Marshal(env.Event)
			if err != nil {
				h.log.Warn("SSE marshal failed",
					zap.String("type", env.Event.Type),
					zap.Int64("seq", env.Seq),
					zap.Error(err))
				return err
			}
			_, err = fmt.Fprintf(out, "event: notification\nid: %d\ndata: %s\n\n",
				env.Seq, data)
			return err
		},
	)
}
