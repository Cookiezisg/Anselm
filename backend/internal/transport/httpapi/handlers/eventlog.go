// eventlog.go — SSE handler for the recursive event-log protocol.
// Phase 1 ships this alongside the legacy ChatHandler.EventsSSE
// endpoint (/api/v1/events) so frontends can migrate at their own
// pace; Phase 4 cutover deletes the legacy path.
//
// Wire format per event:
//
//	event: <type>          ← message_start | block_delta | ...
//	id: <seq>              ← per-conversation monotonic
//	data: <JSON of event>  ← payload struct as-is (no type/seq dup)
//
// Reconnect: client sends `Last-Event-ID: N` header; server replays
// buffered envelopes with seq > N, then live. Past the buffer's oldest
// entry the server returns 410 Gone — client must HTTP-fetch full
// state and resubscribe with the new tail seq.
//
// eventlog.go ——递归事件日志协议的 SSE handler。Phase 1 与 legacy
// ChatHandler.EventsSSE（/api/v1/events）共存，让前端按自己节奏迁移；
// Phase 4 cutover 删 legacy。
//
// 每条 wire 格式：
//
//	event: <type>          ← message_start | block_delta | ...
//	id: <seq>              ← per-conversation 单调
//	data: <JSON of event>  ← payload struct 原样（不重复 type/seq）
//
// 重连：客户端发 `Last-Event-ID: N` header；服务端 replay 缓存中 seq > N
// 的 envelope，再接实时。超过 buffer 最旧时返 410 Gone——客户端必须
// HTTP fetch 全态后用新 tail seq 重订阅。
package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// EventLogHandler exposes /api/v1/eventlog as an SSE stream backed by
// the recursive-event-log Bridge.
//
// EventLogHandler 把 /api/v1/eventlog 暴露为递归事件日志 Bridge 支撑的
// SSE 流。
type EventLogHandler struct {
	bridge eventlogdomain.Bridge
	log    *zap.Logger
}

// NewEventLogHandler wires the handler dependencies.
//
// NewEventLogHandler 装配 handler 依赖。
func NewEventLogHandler(bridge eventlogdomain.Bridge, log *zap.Logger) *EventLogHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &EventLogHandler{bridge: bridge, log: log.Named("eventlog.handler")}
}

// Register attaches the SSE route.
//
// Register 挂 SSE 路由。
func (h *EventLogHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/eventlog", h.Stream)
}

// Stream serves GET /api/v1/eventlog?conversationId=xxx.
//
// Stream 服务 GET /api/v1/eventlog?conversationId=xxx。
func (h *EventLogHandler) Stream(w http.ResponseWriter, r *http.Request) {
	conversationID := r.URL.Query().Get("conversationId")
	if conversationID == "" {
		responsehttpapi.Error(w, http.StatusBadRequest, "INVALID_REQUEST", "conversationId is required", nil)
		return
	}

	// Last-Event-ID is the standard SSE reconnect header. Parse to
	// int64; absent / invalid → 0 (no replay, live only).
	//
	// Last-Event-ID 是标准 SSE 重连 header。解析为 int64；缺失/非法
	// → 0（无 replay 直接实时）。
	var fromSeq int64
	if v := r.Header.Get("Last-Event-ID"); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n > 0 {
			fromSeq = n
		}
	}

	ch, cancelSub, err := h.bridge.Subscribe(r.Context(), conversationID, fromSeq)
	if err != nil {
		if errors.Is(err, eventlogdomain.ErrSeqTooOld) {
			// 410 Gone signals "buffer evicted; refetch full state".
			// 410 Gone 表示"buffer 已淘汰；refetch 全态"。
			responsehttpapi.Error(w, http.StatusGone, "SEQ_TOO_OLD",
				"requested Last-Event-ID has been evicted from the replay buffer; refetch full state",
				nil)
			return
		}
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	defer cancelSub()

	responsehttpapi.StreamSSE(w, r, nil, ch,
		func(out io.Writer, env eventlogdomain.Envelope) error {
			data, err := json.Marshal(env.Event)
			if err != nil {
				h.log.Warn("SSE marshal failed",
					zap.String("type", env.Event.EventType()),
					zap.Int64("seq", env.Seq),
					zap.Error(err))
				return err
			}
			_, err = fmt.Fprintf(out, "event: %s\nid: %d\ndata: %s\n\n",
				env.Event.EventType(), env.Seq, data)
			return err
		},
	)
}
