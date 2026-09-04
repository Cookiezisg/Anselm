package main

import (
	"bytes"
	"encoding/binary"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestFailureBudgetConsumesOnlyMatchingPath(t *testing.T) {
	b := &failureBudget{path: "/v1/media/uploads", remaining: 2}
	matching := httptest.NewRequest(http.MethodPost, "http://127.0.0.1/v1/media/uploads", nil)
	other := httptest.NewRequest(http.MethodPost, "http://127.0.0.1/v1/chat/completions", nil)

	if !b.take(matching) || !b.take(matching) {
		t.Fatal("matching staging requests should consume the failure budget")
	}
	if b.take(matching) {
		t.Fatal("failure budget should be exhausted")
	}
	if b.take(other) {
		t.Fatal("unmatched paths must never consume or trigger the budget")
	}
}

func TestFailureBudgetDisabledByEmptyPath(t *testing.T) {
	b := &failureBudget{remaining: 10}
	req := httptest.NewRequest(http.MethodPost, "http://127.0.0.1/v1/media/uploads", nil)
	if b.take(req) {
		t.Fatal("empty fail path must disable injection")
	}
}

func TestFailureBudgetVideoPollMatchesOnlyDynamicVideoGets(t *testing.T) {
	b := &failureBudget{remaining: 2}
	poll := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/v1/videos/opaque-handle", nil)
	submit := httptest.NewRequest(http.MethodPost, "http://127.0.0.1/v1/videos/generations", nil)
	chat := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/v1/chat/completions", nil)
	if !b.takeVideoPoll(poll) || !b.takeVideoPoll(poll) {
		t.Fatal("dynamic video poll requests should consume the budget")
	}
	if b.takeVideoPoll(poll) {
		t.Fatal("video poll budget should be exhausted")
	}
	if b.takeVideoPoll(submit) || b.takeVideoPoll(chat) {
		t.Fatal("video submit and unrelated requests must not consume the poll budget")
	}
}

func TestInjectedVideoPollTimeoutIsValidPendingGatewayResponse(t *testing.T) {
	status, contentType, body := injectedFailure("video-poll-timeout", http.StatusServiceUnavailable)
	if status != http.StatusOK || contentType != "application/json" || string(body) != `{"status":"pending"}` {
		t.Fatalf("video poll timeout = %d/%q/%s, want 200/application/json/pending", status, contentType, body)
	}
}

func TestInjectedFailureQuotaVariantsUseGatewayContracts(t *testing.T) {
	status, contentType, body := injectedFailure("quota-http", http.StatusPaymentRequired)
	if status != http.StatusPaymentRequired || contentType != "application/json" {
		t.Fatalf("quota HTTP failure = %d/%q, want 402/application/json", status, contentType)
	}
	if string(body) != `{"error":{"code":"QUOTA_EXHAUSTED","message":"monthly gateway budget exhausted"}}` {
		t.Fatalf("quota HTTP body = %s", body)
	}

	status, contentType, body = injectedFailure("quota-http", http.StatusTooManyRequests)
	if status != http.StatusTooManyRequests || contentType != "application/json" {
		t.Fatalf("rate-limit HTTP failure = %d/%q, want 429/application/json", status, contentType)
	}
	if string(body) != `{"error":{"code":"RATE_LIMITED","message":"temporarily rate limited; please retry"}}` {
		t.Fatalf("rate-limit HTTP body = %s", body)
	}

	status, contentType, body = injectedFailure("quota-stream", http.StatusServiceUnavailable)
	if status != http.StatusOK || contentType != "text/event-stream" {
		t.Fatalf("quota stream failure = %d/%q, want 200/text/event-stream", status, contentType)
	}
	if string(body) != "data: {\"error\":{\"code\":\"BUDGET_EXHAUSTED\",\"message\":\"monthly gateway budget exhausted\"}}\n\n" {
		t.Fatalf("quota stream body = %s", body)
	}
}

func TestSpeechHandshakeFailureUsesClosedSetGatewayCode(t *testing.T) {
	status, contentType, body := injectedFailure("speech-handshake", http.StatusUnauthorized)
	if status != http.StatusUnauthorized || contentType != "application/json" {
		t.Fatalf("speech handshake failure = %d/%q, want 401/application/json", status, contentType)
	}
	if string(body) != `{"error":{"code":"QUOTA_EXHAUSTED","message":"fixture upstream prose: monthly speech allowance exhausted"}}` {
		t.Fatalf("speech handshake body = %s", body)
	}
}

func TestIsWebSocketUpgradeRequiresUpgradeToken(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "http://127.0.0.1/v1/speech/asr", nil)
	request.Header.Set("Upgrade", "websocket")
	request.Header.Set("Connection", "keep-alive")
	if isWebSocketUpgrade(request) {
		t.Fatal("keep-alive must not count as a WebSocket upgrade")
	}
	request.Header.Set("Connection", "keep-alive, Upgrade")
	if !isWebSocketUpgrade(request) {
		t.Fatal("upgrade token should be recognized case-insensitively")
	}
	request.Header.Set("Connection", strings.ToUpper("upgrade"))
	if !isWebSocketUpgrade(request) {
		t.Fatal("single upgrade token should be recognized")
	}
}

func TestSpeechUpstreamURLUsesWebSocketAndPreservesQuery(t *testing.T) {
	base, err := url.Parse("https://api.example.test/base")
	if err != nil {
		t.Fatal(err)
	}
	request, err := url.Parse("/v1/speech/asr?language=zh")
	if err != nil {
		t.Fatal(err)
	}
	got := speechUpstreamURL(base, request)
	if got.String() != "wss://api.example.test/base/v1/speech/asr?language=zh" {
		t.Fatalf("speech upstream URL = %s", got)
	}
}

func TestInjectWAVMetadataPreservesAudioAndAddsChunks(t *testing.T) {
	pcm := bytes.Repeat([]byte{0x12, 0x34}, 16)
	raw := buildTestWAV(pcm)
	mutated, added, err := injectWAVMetadata(raw)
	if err != nil {
		t.Fatalf("injectWAVMetadata: %v", err)
	}
	if added != 24 || len(mutated) != len(raw)+added {
		t.Fatalf("added bytes = %d, length = %d; want 24 and %d", added, len(mutated), len(raw)+24)
	}
	if !bytes.Equal(mutated[:4], raw[:4]) || !bytes.Equal(mutated[8:36], raw[8:36]) || !bytes.Equal(mutated[36+added:], raw[36:]) {
		t.Fatal("metadata injection changed bytes outside the inserted region")
	}
	if string(mutated[36:40]) != "LIST" || string(mutated[48:52]) != "fact" || string(mutated[60:64]) != "data" {
		t.Fatalf("chunk order = %q/%q/%q, want LIST/fact/data", mutated[36:40], mutated[48:52], mutated[60:64])
	}
	if got := binary.LittleEndian.Uint32(mutated[4:8]); got != uint32(len(mutated)-8) {
		t.Fatalf("RIFF size = %d, want %d", got, len(mutated)-8)
	}
}

func TestInjectWAVMetadataAcceptsUnknownLengthDataChunk(t *testing.T) {
	pcm := bytes.Repeat([]byte{0x56, 0x78}, 8)
	raw := buildTestWAV(pcm)
	binary.LittleEndian.PutUint32(raw[40:44], ^uint32(0x400))
	mutated, _, err := injectWAVMetadata(raw)
	if err != nil {
		t.Fatalf("unknown-length data chunk should remain injectable: %v", err)
	}
	if !bytes.Equal(mutated[len(mutated)-len(pcm):], pcm) {
		t.Fatal("unknown-length data payload was not preserved")
	}
}

func TestInjectWAVMetadataRejectsNonWAV(t *testing.T) {
	if _, _, err := injectWAVMetadata([]byte("not audio")); err == nil {
		t.Fatal("non-WAV response must not be treated as injectable audio")
	}
}

func TestInjectWAVMetadataRejectsTruncatedChunk(t *testing.T) {
	raw := append([]byte("RIFF\x00\x00\x00\x00WAVEfmt "), make([]byte, 4)...)
	if _, _, err := injectWAVMetadata(raw); err == nil {
		t.Fatal("truncated WAV must be rejected")
	}
}

func buildTestWAV(pcm []byte) []byte {
	out := make([]byte, 44+len(pcm))
	copy(out, "RIFF")
	binary.LittleEndian.PutUint32(out[4:8], uint32(len(out)-8))
	copy(out[8:12], "WAVE")
	copy(out[12:16], "fmt ")
	binary.LittleEndian.PutUint32(out[16:20], 16)
	binary.LittleEndian.PutUint16(out[20:22], 1)
	binary.LittleEndian.PutUint16(out[22:24], 1)
	binary.LittleEndian.PutUint32(out[24:28], 24000)
	binary.LittleEndian.PutUint32(out[28:32], 48000)
	binary.LittleEndian.PutUint16(out[32:34], 2)
	binary.LittleEndian.PutUint16(out[34:36], 16)
	copy(out[36:40], "data")
	binary.LittleEndian.PutUint32(out[40:44], uint32(len(pcm)))
	copy(out[44:], pcm)
	return out
}
