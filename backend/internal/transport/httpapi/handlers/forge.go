// forge.go — SSE handler for the trinity forge stream
// (forge_started / forge_op_applied / forge_env_attempt / forge_completed).
// Per-user keying, Last-Event-ID reconnect, 410 Gone on evicted seq.
//
// Wire format per event:
//
//	event: <type>          ← forge_started | forge_op_applied | ...
//	id: <seq>              ← per-user monotonic (bridge-assigned)
//	data: <JSON of event>  ← payload struct; scope nested {kind, id} (D-redo-23)
//
// forge.go ——trinity 锻造流 SSE handler。per-user keying;Last-Event-ID
// 重连;evicted 返 410。payload scope 嵌套(D-redo-23)。
package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// ForgeHandler exposes /api/v1/forge as an SSE stream backed by the
// forge Bridge.
//
// ForgeHandler 把 /api/v1/forge 暴露为 forge Bridge 支撑的 SSE 流。
type ForgeHandler struct {
	bridge forgedomain.Bridge
	log    *zap.Logger
}

// NewForgeHandler wires the handler dependencies.
//
// NewForgeHandler 装配 handler 依赖。
func NewForgeHandler(bridge forgedomain.Bridge, log *zap.Logger) *ForgeHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ForgeHandler{bridge: bridge, log: log.Named("forge.handler")}
}

// Register attaches the SSE route.
//
// Register 挂 SSE 路由。
func (h *ForgeHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/forge", h.Stream)
}

// Stream serves GET /api/v1/forge. Per-user; no query parameter.
//
// Stream 服务 GET /api/v1/forge。per-user;无 query 参。
func (h *ForgeHandler) Stream(w http.ResponseWriter, r *http.Request) {
	var fromSeq int64
	if v := r.Header.Get("Last-Event-ID"); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n > 0 {
			fromSeq = n
		}
	}

	ch, cancelSub, err := h.bridge.Subscribe(r.Context(), fromSeq)
	if err != nil {
		if errors.Is(err, forgedomain.ErrSeqTooOld) {
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
		func(out io.Writer, env forgedomain.Envelope) error {
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
