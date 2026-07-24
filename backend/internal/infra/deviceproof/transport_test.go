package deviceproof

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestTransportSignsExactRequestAndRefreshesExpiredNonce(t *testing.T) {
	signer, err := generate()
	if err != nil {
		t.Fatal(err)
	}
	var challenges atomic.Int32
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/v1/proof/challenge" {
			n := challenges.Add(1)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"nonce": "nonce-" + string(rune('0'+n)), "expiresAt": time.Now().Add(time.Minute).Format(time.RFC3339),
			})
			return
		}
		if calls.Add(1) == 1 {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = io.WriteString(w, `{"error":{"code":"DEVICE_PROOF_NONCE_INVALID"}}`)
			return
		}
		parts := strings.Split(r.Header.Get(HeaderProof), ".")
		if len(parts) != 2 {
			t.Errorf("proof parts = %d", len(parts))
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		sig, _ := b64.DecodeString(parts[1])
		if !ed25519.Verify(signer.private.Public().(ed25519.PublicKey), []byte(parts[0]), sig) {
			t.Error("signature did not verify")
		}
		rawPayload, err := base64.RawURLEncoding.DecodeString(parts[0])
		if err != nil {
			t.Errorf("decode payload: %v", err)
		}
		var proof struct {
			KeyID  string `json:"kid"`
			Method string `json:"htm"`
			Target string `json:"htu"`
			Body   string `json:"bh"`
		}
		if err := json.Unmarshal(rawPayload, &proof); err != nil {
			t.Errorf("unmarshal payload: %v", err)
		}
		body, _ := io.ReadAll(r.Body)
		bodyHash := sha256.Sum256(body)
		wantTarget := strings.ToLower(r.Host) + r.URL.EscapedPath() + "?" + r.URL.RawQuery
		if proof.KeyID != "ins_test" || proof.Method != http.MethodPost || proof.Target != wantTarget || proof.Body != base64.RawURLEncoding.EncodeToString(bodyHash[:]) {
			t.Errorf("signed request = %+v, want kid/method/target/body bound to concrete request", proof)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer srv.Close()

	client := srv.Client()
	client.Transport = NewTransport(client.Transport, signer)
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/chat/completions?x=1", strings.NewReader(`{"a":1}`))
	req.Header.Set(HeaderInstallID, "ins_test")
	resp, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK || challenges.Load() != 2 || calls.Load() != 2 {
		t.Fatalf("status/challenges/calls = %d/%d/%d", resp.StatusCode, challenges.Load(), calls.Load())
	}
}

func TestTransportLeavesUnmarkedProviderRequestUntouched(t *testing.T) {
	signer, err := generate()
	if err != nil {
		t.Fatal(err)
	}
	var challenges atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/v1/proof/challenge" {
			challenges.Add(1)
		}
		if got := r.Header.Get(HeaderProof); got != "" {
			t.Errorf("unmarked request received proof %q", got)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer srv.Close()

	client := srv.Client()
	client.Transport = NewTransport(client.Transport, signer)
	resp, err := client.Get(srv.URL + "/other-provider")
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent || challenges.Load() != 0 {
		t.Fatalf("status/challenges = %d/%d, want 204/0", resp.StatusCode, challenges.Load())
	}
}

func TestProofHeadersSignsWebSocketGETWithHTTPChallenge(t *testing.T) {
	signer, err := generate()
	if err != nil {
		t.Fatal(err)
	}
	var challenges atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/proof/challenge" {
			t.Fatalf("unexpected challenge path %s", r.URL.Path)
		}
		challenges.Add(1)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"nonce": "nonce-ws", "expiresAt": time.Now().Add(time.Minute).Format(time.RFC3339),
		})
	}))
	defer srv.Close()

	proof := NewTransport(srv.Client().Transport, signer)
	wsURL := strings.Replace(srv.URL, "http://", "ws://", 1) + "/v1/speech/asr?language=zh"
	headers, err := proof.ProofHeaders(context.Background(), http.MethodGet, wsURL, "ins_test", nil, false)
	if err != nil {
		t.Fatal(err)
	}
	if headers.Get(HeaderInstallID) != "ins_test" || headers.Get(HeaderProof) == "" {
		t.Fatalf("missing signed headers: %v", headers)
	}
	parts := strings.Split(headers.Get(HeaderProof), ".")
	if len(parts) != 2 {
		t.Fatalf("proof parts = %d", len(parts))
	}
	sig, err := b64.DecodeString(parts[1])
	if err != nil {
		t.Fatal(err)
	}
	if !ed25519.Verify(signer.private.Public().(ed25519.PublicKey), []byte(parts[0]), sig) {
		t.Fatal("signature did not verify")
	}
	rawPayload, err := b64.DecodeString(parts[0])
	if err != nil {
		t.Fatal(err)
	}
	var payload struct {
		KeyID  string `json:"kid"`
		Method string `json:"htm"`
		Target string `json:"htu"`
		Body   string `json:"bh"`
	}
	if err := json.Unmarshal(rawPayload, &payload); err != nil {
		t.Fatal(err)
	}
	emptyHash := sha256.Sum256(nil)
	wantTarget := strings.TrimPrefix(strings.ToLower(wsURL), "ws://")
	if payload.KeyID != "ins_test" || payload.Method != http.MethodGet || payload.Target != wantTarget || payload.Body != b64.EncodeToString(emptyHash[:]) {
		t.Fatalf("payload = %+v, want websocket GET target %q and empty body hash", payload, wantTarget)
	}
	if challenges.Load() != 1 {
		t.Fatalf("challenges = %d, want 1", challenges.Load())
	}
}

func TestTransportDoesNotRetryOrdinaryUnauthorizedResponse(t *testing.T) {
	signer, err := generate()
	if err != nil {
		t.Fatal(err)
	}
	var challenges atomic.Int32
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/v1/proof/challenge" {
			challenges.Add(1)
			_ = json.NewEncoder(w).Encode(map[string]string{
				"nonce": "nonce", "expiresAt": time.Now().Add(time.Minute).Format(time.RFC3339),
			})
			return
		}
		calls.Add(1)
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = io.WriteString(w, `{"error":{"code":"INVALID_INSTALL"}}`)
	}))
	defer srv.Close()

	client := srv.Client()
	client.Transport = NewTransport(client.Transport, signer)
	req, err := http.NewRequest(http.MethodGet, srv.URL+"/v1/quota", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set(HeaderInstallID, "ins_test")
	resp, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized || challenges.Load() != 1 || calls.Load() != 1 {
		t.Fatalf("status/challenges/calls = %d/%d/%d, want 401/1/1", resp.StatusCode, challenges.Load(), calls.Load())
	}
	if !strings.Contains(string(raw), "INVALID_INSTALL") {
		t.Fatalf("response body was not preserved: %q", raw)
	}
}
