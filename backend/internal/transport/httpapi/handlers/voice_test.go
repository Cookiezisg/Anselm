package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"

	voiceapp "github.com/sunweilin/anselm/backend/internal/app/voice"
	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type voiceHandlerRepo struct {
	rows      []*voicedomain.Voice
	deleteIDs []string
}

func (f *voiceHandlerRepo) Create(context.Context, *voicedomain.Voice) error { return nil }

func (f *voiceHandlerRepo) List(context.Context) ([]*voicedomain.Voice, error) {
	return f.rows, nil
}

func (f *voiceHandlerRepo) GetByName(context.Context, string) (*voicedomain.Voice, error) {
	return nil, voicedomain.ErrNotFound
}

func (f *voiceHandlerRepo) Delete(_ context.Context, id string) error {
	f.deleteIDs = append(f.deleteIDs, id)
	return nil
}

type voiceHandlerUpstream struct {
	err   error
	calls []struct {
		provider   string
		upstreamID string
	}
}

func (f *voiceHandlerUpstream) DeleteVoice(_ context.Context, provider, upstreamID string) error {
	f.calls = append(f.calls, struct {
		provider   string
		upstreamID string
	}{provider: provider, upstreamID: upstreamID})
	return f.err
}

func handlerVoiceFixture(upstreamErr error) (*VoiceHandler, *voiceHandlerRepo, *voiceHandlerUpstream) {
	repo := &voiceHandlerRepo{rows: []*voicedomain.Voice{{
		ID:         "vce_1111111111111111",
		Name:       "narrator",
		Provider:   "anselm",
		UpstreamID: "vce_upstream_111",
	}}}
	upstream := &voiceHandlerUpstream{err: upstreamErr}
	return NewVoiceHandler(voiceapp.New(repo, upstream, nil), nil), repo, upstream
}

// TestVoiceHandlerDelete_RegisteredRouteReturnsEmpty204 protects the public route and its
// no-body success shape. A JSON envelope here would make the Flutter client treat a settled delete
// as an ordinary payload instead of a completed mutation.
//
// TestVoiceHandlerDelete_RegisteredRouteReturnsEmpty204 保护公开路由和无 body 的成功形状。若这里返回
// JSON envelope,Flutter 会把已落定删除当成普通 payload,而不是已完成的 mutation。
func TestVoiceHandlerDelete_RegisteredRouteReturnsEmpty204(t *testing.T) {
	h, repo, upstream := handlerVoiceFixture(nil)
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/v1/voices/vce_1111111111111111", nil))

	if rec.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204; body = %s", rec.Code, rec.Body)
	}
	if rec.Body.Len() != 0 {
		t.Fatalf("204 body = %q, want empty", rec.Body.String())
	}
	if !reflect.DeepEqual(repo.deleteIDs, []string{"vce_1111111111111111"}) {
		t.Fatalf("local delete ids = %v", repo.deleteIDs)
	}
	if len(upstream.calls) != 1 || upstream.calls[0].provider != "anselm" || upstream.calls[0].upstreamID != "vce_upstream_111" {
		t.Fatalf("upstream calls = %+v", upstream.calls)
	}
}

// TestVoiceHandlerDelete_UpstreamFailureKeepsPointerAndEnvelope ensures the retryable upstream
// reason reaches the wire while the local row remains untouched.
//
// TestVoiceHandlerDelete_UpstreamFailureKeepsPointerAndEnvelope 确保可重试的上游原因到达 wire,同时
// 本地行保持不动。
func TestVoiceHandlerDelete_UpstreamFailureKeepsPointerAndEnvelope(t *testing.T) {
	remote := llminfra.ErrVoiceCloneFailed.WithDetails(map[string]any{"upstream": "HTTP 502: gateway unavailable"})
	h, repo, upstream := handlerVoiceFixture(remote)
	mux := http.NewServeMux()
	h.Register(mux)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodDelete, "/api/v1/voices/vce_1111111111111111", nil))

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503; body = %s", rec.Code, rec.Body)
	}
	var envelope struct {
		Error struct {
			Code    string         `json:"code"`
			Details map[string]any `json:"details"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &envelope); err != nil {
		t.Fatalf("decode error envelope: %v (%s)", err, rec.Body)
	}
	if envelope.Error.Code != "VOICE_CLONE_FAILED" || envelope.Error.Details["upstream"] != "HTTP 502: gateway unavailable" {
		t.Fatalf("error envelope = %+v", envelope.Error)
	}
	if len(upstream.calls) != 1 {
		t.Fatalf("upstream calls = %d, want one", len(upstream.calls))
	}
	if len(repo.deleteIDs) != 0 {
		t.Fatalf("local delete ids = %v, want none after upstream failure", repo.deleteIDs)
	}
}
