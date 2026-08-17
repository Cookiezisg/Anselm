package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap"
)

func TestNotificationUnreadCountRejectsPOSTAsMethodNotAllowed(t *testing.T) {
	mux := http.NewServeMux()
	(&NotificationHandler{log: zap.NewNop()}).Register(mux)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/notifications/unread-count", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST unread-count status = %d, want 405 (body %s)", rec.Code, rec.Body)
	}
	if got := rec.Header().Get("Allow"); got != "GET, HEAD" {
		t.Fatalf("POST unread-count Allow = %q, want %q", got, "GET, HEAD")
	}
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode error envelope: %v (%s)", err, rec.Body)
	}
	if body.Error.Code != "METHOD_NOT_ALLOWED" {
		t.Fatalf("error code = %q, want METHOD_NOT_ALLOWED", body.Error.Code)
	}
}
