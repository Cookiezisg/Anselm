package deviceproof

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	HeaderInstallID = "X-Anselm-Install-ID"
	HeaderProof     = "X-Anselm-Proof"
	HeaderPublicKey = "X-Anselm-Public-Key"
)

type cachedChallenge struct {
	nonce     string
	expiresAt time.Time
}

// Transport signs only requests explicitly marked with an install id or public
// key header; every other provider request passes through byte-for-byte.
type Transport struct {
	base   http.RoundTripper
	signer *Signer
	mu     sync.Mutex
	cache  map[string]cachedChallenge
}

func NewTransport(base http.RoundTripper, signer *Signer) *Transport {
	if base == nil {
		base = http.DefaultTransport
	}
	return &Transport{base: base, signer: signer, cache: make(map[string]cachedChallenge)}
}

func (t *Transport) RoundTrip(req *http.Request) (*http.Response, error) {
	kid := req.Header.Get(HeaderInstallID)
	if kid == "" && req.Header.Get(HeaderPublicKey) != "" {
		kid = t.signer.Thumbprint()
	}
	if kid == "" {
		return t.base.RoundTrip(req)
	}
	body, err := readBody(req)
	if err != nil {
		return nil, err
	}
	for attempt := 0; attempt < 2; attempt++ {
		nonce, err := t.challenge(req.Context(), req.URL.Scheme+"://"+req.URL.Host, attempt > 0)
		if err != nil {
			return nil, err
		}
		clone := req.Clone(req.Context())
		clone.Body = io.NopCloser(bytes.NewReader(body))
		clone.ContentLength = int64(len(body))
		clone.Header = req.Header.Clone()
		clone.Header.Set(HeaderProof, t.sign(kid, nonce, clone, body))
		resp, err := t.base.RoundTrip(clone)
		if err != nil || attempt == 1 || resp.StatusCode != http.StatusUnauthorized {
			return resp, err
		}
		raw, readErr := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		_ = resp.Body.Close()
		if readErr != nil || !isNonceInvalid(raw) {
			resp.Body = io.NopCloser(bytes.NewReader(raw))
			resp.ContentLength = int64(len(raw))
			return resp, nil
		}
	}
	panic("unreachable")
}

func isNonceInvalid(raw []byte) bool {
	var envelope struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	return json.Unmarshal(raw, &envelope) == nil && envelope.Error.Code == "DEVICE_PROOF_NONCE_INVALID"
}

func readBody(req *http.Request) ([]byte, error) {
	if req.Body == nil {
		return nil, nil
	}
	raw, err := io.ReadAll(req.Body)
	if err != nil {
		return nil, fmt.Errorf("deviceproof: read request body: %w", err)
	}
	req.Body = io.NopCloser(bytes.NewReader(raw))
	return raw, nil
}

func (t *Transport) challenge(ctx context.Context, origin string, refresh bool) (string, error) {
	t.mu.Lock()
	if c, ok := t.cache[origin]; !refresh && ok && time.Now().Before(c.expiresAt.Add(-15*time.Second)) {
		t.mu.Unlock()
		return c.nonce, nil
	}
	t.mu.Unlock()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, origin+"/v1/proof/challenge", nil)
	if err != nil {
		return "", fmt.Errorf("deviceproof: build challenge request: %w", err)
	}
	resp, err := t.base.RoundTrip(req)
	if err != nil {
		return "", fmt.Errorf("deviceproof: fetch challenge: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("deviceproof: challenge returned HTTP %d", resp.StatusCode)
	}
	var out struct {
		Nonce     string `json:"nonce"`
		ExpiresAt string `json:"expiresAt"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&out); err != nil {
		return "", fmt.Errorf("deviceproof: decode challenge: %w", err)
	}
	expiresAt, err := time.Parse(time.RFC3339, out.ExpiresAt)
	if err != nil || out.Nonce == "" {
		return "", fmt.Errorf("deviceproof: invalid challenge response")
	}
	t.mu.Lock()
	t.cache[origin] = cachedChallenge{nonce: out.Nonce, expiresAt: expiresAt}
	t.mu.Unlock()
	return out.Nonce, nil
}

func (t *Transport) sign(kid, nonce string, req *http.Request, body []byte) string {
	jti := make([]byte, 16)
	if _, err := rand.Read(jti); err != nil {
		panic("deviceproof: crypto/rand failed: " + err.Error())
	}
	bh := sha256.Sum256(body)
	target := strings.ToLower(req.URL.Host) + req.URL.EscapedPath()
	if req.URL.RawQuery != "" {
		target += "?" + req.URL.RawQuery
	}
	payload, err := json.Marshal(struct {
		Version int    `json:"v"`
		KeyID   string `json:"kid"`
		Issued  int64  `json:"iat"`
		ID      string `json:"jti"`
		Nonce   string `json:"nonce"`
		Method  string `json:"htm"`
		Target  string `json:"htu"`
		Body    string `json:"bh"`
	}{1, kid, time.Now().Unix(), b64.EncodeToString(jti), nonce, req.Method, target, b64.EncodeToString(bh[:])})
	if err != nil {
		panic("deviceproof: marshal fixed payload failed: " + err.Error())
	}
	encoded := b64.EncodeToString(payload)
	return encoded + "." + b64.EncodeToString(ed25519.Sign(t.signer.private, []byte(encoded)))
}
