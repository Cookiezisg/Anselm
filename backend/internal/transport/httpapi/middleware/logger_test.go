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
