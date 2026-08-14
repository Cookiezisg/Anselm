package llm

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestDeleteVoiceAnselm_AcceptsGatewayNoContent locks the managed gateway's delete wire: this
// action is POST, carries the install identity, and succeeds with 204 and no response body.
//
// TestDeleteVoiceAnselm_AcceptsGatewayNoContent 锁住受管网关的删除 wire:动作是 POST,携带 install
// 身份,并且必须接受无响应体的 204 成功。
func TestDeleteVoiceAnselm_AcceptsGatewayNoContent(t *testing.T) {
	const (
		installID = "ins_voice_test"
		voiceID   = "vce_upstream_test"
	)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/voices:delete" {
			t.Fatalf("request = %s %s, want POST /voices:delete", r.Method, r.URL.Path)
		}
		if got := r.Header.Get(deviceproofinfra.HeaderInstallID); got != installID {
			t.Fatalf("install header = %q, want %q", got, installID)
		}
		if got := r.Header.Get("Content-Type"); got != "application/json" {
			t.Fatalf("content type = %q, want application/json", got)
		}
		var body struct {
			VoiceID string `json:"voiceId"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if body.VoiceID != voiceID {
			t.Fatalf("voice id = %q, want %q", body.VoiceID, voiceID)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	if err := DeleteVoiceAnselm(context.Background(), server.Client(), server.URL, installID, voiceID); err != nil {
		t.Fatalf("DeleteVoiceAnselm: %v", err)
	}
}

// TestDeleteVoiceAnselm_PreservesStructuredUpstreamFailure ensures a non-2xx gateway envelope is
// actionable to the caller while remaining the voice-specific error family, not image generation.
//
// TestDeleteVoiceAnselm_PreservesStructuredUpstreamFailure 确保网关非 2xx envelope 对调用方可行动,
// 同时仍属于 voice 专用错误族,不会误报成图像生成失败。
func TestDeleteVoiceAnselm_PreservesStructuredUpstreamFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte(`{"error":{"code":"UPSTREAM_REJECTED","message":"gateway unavailable"}}`))
	}))
	defer server.Close()

	err := DeleteVoiceAnselm(context.Background(), server.Client(), server.URL, "ins_voice_test", "vce_upstream_test")
	if err == nil || !errors.Is(err, ErrVoiceCloneFailed) {
		t.Fatalf("error = %v, want ErrVoiceCloneFailed", err)
	}
	var structured *errorspkg.Error
	if !errors.As(err, &structured) {
		t.Fatalf("error = %T %v, want structured error", err, err)
	}
	upstream, ok := structured.Details["upstream"].(string)
	if !ok || !strings.Contains(upstream, "HTTP 502") || !strings.Contains(upstream, "UPSTREAM_REJECTED") {
		t.Fatalf("upstream details = %#v, want bounded status and gateway reason", structured.Details["upstream"])
	}
	if strings.Contains(err.Error(), "IMAGE_GEN_FAILED") {
		t.Fatalf("voice deletion reported image-generation failure: %v", err)
	}
}
