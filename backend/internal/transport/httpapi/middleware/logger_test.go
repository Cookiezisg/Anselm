package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap"
	"go.uber.org/zap/zaptest/observer"
)

func TestRequestLoggerRedactsAttachmentPlaybackToken(t *testing.T) {
	core, logs := observer.New(zap.InfoLevel)
	h := RequestLogger(zap.New(core))(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/api/v1/attachment-playback/secret-token", nil))

	if logs.Len() != 1 {
		t.Fatalf("logs = %d, want 1", logs.Len())
	}
	fields := logs.All()[0].ContextMap()
	if got := fields["path"]; got != "/api/v1/attachment-playback/<redacted>" {
		t.Fatalf("logged path = %v", got)
	}
}

// The wrapper-forwarding law (E 真机验收 0725): statusRecorder sits in front of EVERY route, so any
// interface it fails to forward is silently stripped from the whole API surface. Hiding Flusher would
// break SSE (three streams); hiding Hijacker broke the speech WebSocket — gorilla's Upgrade answered a
// plain-text 500 before any handler ran, with zero log lines to point at it.
//
// 包装转发律(0725 真机验收):statusRecorder 挡在每条路由前面,它没转发的接口就等于从整个 API 面上被静默
// 剥掉。藏 Flusher 断 SSE(三条流);藏 Hijacker 断了 speech WebSocket——gorilla 的 Upgrade 在任何 handler
// 运行之前答了裸文本 500,且没有一行日志可指认。
func TestStatusRecorderForwardsStreamingInterfaces(t *testing.T) {
	rec := newStatusRecorder(httptest.NewRecorder())
	if _, ok := interface{}(rec).(http.Flusher); !ok {
		t.Error("statusRecorder must forward http.Flusher (SSE dies without it)")
	}
	if _, ok := interface{}(rec).(http.Hijacker); !ok {
		t.Error("statusRecorder must forward http.Hijacker (every WebSocket route dies without it)")
	}
}
