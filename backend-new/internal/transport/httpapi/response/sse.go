package response

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

const keepAliveInterval = 15 * time.Second

// StreamSSE wires SSE headers, an optional prelude, keep-alive pings, and ctx exit, then
// pumps items through onEvent. Generic over the item type so every SSE endpoint reuses the
// same transport plumbing (only onEvent differs).
//
// StreamSSE 装配 SSE header / 可选 prelude / keep-alive ping / ctx 退出，把 items 经 onEvent
// 泵出。泛型于 item 类型，让每个 SSE 端点复用同一套传输管道（只 onEvent 不同）。
func StreamSSE[T any](
	w http.ResponseWriter,
	r *http.Request,
	onPrelude func(io.Writer),
	items <-chan T,
	onEvent func(io.Writer, T) error,
) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		Error(w, http.StatusInternalServerError, "INTERNAL_ERROR", "streaming not supported", nil)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)
	flusher.Flush()

	if onPrelude != nil {
		onPrelude(w)
		flusher.Flush()
	}

	ticker := time.NewTicker(keepAliveInterval)
	defer ticker.Stop()

	for {
		select {
		case item, ok := <-items:
			if !ok {
				return
			}
			_ = onEvent(w, item)
			flusher.Flush()
		case <-ticker.C:
			fmt.Fprint(w, ": keep-alive\n\n")
			flusher.Flush()
		case <-r.Context().Done():
			return
		}
	}
}
