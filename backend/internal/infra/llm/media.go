package llm

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

// MediaClient is the managed-gateway resumable upload client. Its HTTP client
// must carry deviceproof.Transport; every create/chunk/complete request marks
// the install id so the transport signs the exact body.
//
// MediaClient 是受管网关的可恢复上传 client。它的 HTTP client 必须带 deviceproof.Transport；每个
// create/chunk/complete 请求都标注 install id，使 transport 对精确 body 签名。
type MediaClient struct {
	http *http.Client

	mu       sync.Mutex
	leases   map[string]cachedLease
	inFlight map[string]*leaseFlight
}

type cachedLease struct {
	url       string
	expiresAt time.Time
}

type leaseFlight struct {
	done chan struct{}
	url  string
	err  error
}

// A cache hit must leave enough time for the provider to start its fetch. Expiry is authoritative
// at the gateway, so a client never serves a URL from the final moments of its lease.
//
// cache hit 必须给 provider 留出足够时间开始拉取。过期时间以 gateway 为权威，client 绝不复用只剩最后
// 瞬间的 URL。
const leaseRefreshSkew = 30 * time.Second

// cleanupTimeout bounds best-effort server-side staging cleanup after a caller cancellation or a
// failed upload. It intentionally does not inherit the caller context: that context is often
// already cancelled, while the gateway still needs a signed DELETE to reclaim private bytes.
const cleanupTimeout = time.Second

func NewMediaClient(c *http.Client) *MediaClient {
	return &MediaClient{http: c, leases: make(map[string]cachedLease), inFlight: make(map[string]*leaseFlight)}
}

// Upload returns the gateway's own RELATIVE, short-lived lease fetch path. It sends raw chunks
// rather than base64 so desktop→gateway bandwidth and memory stay bounded.
//
// It deliberately does NOT absolutize (ADR 0011). The gateway accepts a lease reference only in its
// relative form and prepends its OWN configured public origin before handing the result upstream.
// If the client were allowed to supply the host, a caller holding a legitimate lease of their own
// could point the upstream provider at any origin — an SSRF executed by the provider. Keeping the
// value relative makes that host unrepresentable rather than merely checked.
//
// Upload 返回网关自己的**相对**短期 lease fetch path。它发送 raw chunk 而非 base64，使 desktop→gateway
// 带宽与内存保持有界。
//
// 它**刻意不绝对化**(ADR 0011):网关只接受相对形的 lease 引用,并在交给上游前拼上**自己**配置的公开
// origin。若允许客户端提供 host,持有自己合法 lease 的调用方就能把上游 provider 指向任意 origin——一条
// 由 provider 代为执行的 SSRF。保持相对形使那个 host **不可表达**,而非仅仅「被检查」。
func (c *MediaClient) Upload(ctx context.Context, baseURL, installID, mime string, data []byte) (string, error) {
	if c == nil || c.http == nil || len(data) == 0 {
		return "", fmt.Errorf("llm.media: invalid client or data")
	}
	sum := sha256.Sum256(data)
	key := strings.TrimRight(baseURL, "/") + "\x00" + installID + "\x00" + normalizedMediaMIME(mime) + "\x00" + hex.EncodeToString(sum[:])
	if source, ok := c.cached(key, time.Now()); ok {
		return source, nil
	}
	flight, owner := c.claimFlight(key)
	if !owner {
		select {
		case <-flight.done:
			return flight.url, flight.err
		case <-ctx.Done():
			return "", ctx.Err()
		}
	}

	source, expiresAt, err := c.upload(ctx, baseURL, installID, mime, data, sum)
	c.finishFlight(key, flight, source, expiresAt, err)
	return source, err
}

func (c *MediaClient) cached(key string, now time.Time) (string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	lease, ok := c.leases[key]
	if !ok || !lease.expiresAt.After(now.Add(leaseRefreshSkew)) {
		if ok {
			delete(c.leases, key)
		}
		return "", false
	}
	return lease.url, true
}

func (c *MediaClient) claimFlight(key string) (*leaseFlight, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if existing := c.inFlight[key]; existing != nil {
		return existing, false
	}
	flight := &leaseFlight{done: make(chan struct{})}
	c.inFlight[key] = flight
	return flight, true
}

func (c *MediaClient) finishFlight(key string, flight *leaseFlight, source string, expiresAt time.Time, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if err == nil {
		c.leases[key] = cachedLease{url: source, expiresAt: expiresAt}
	}
	flight.url, flight.err = source, err
	delete(c.inFlight, key)
	close(flight.done)
}

func (c *MediaClient) upload(ctx context.Context, baseURL, installID, mime string, data []byte, sum [sha256.Size]byte) (string, time.Time, error) {
	var created struct {
		UploadID      string `json:"uploadId"`
		ChunkMaxBytes int    `json:"chunkMaxBytes"`
	}
	if err := c.json(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/media/uploads", installID, map[string]any{"sha256": hex.EncodeToString(sum[:]), "mimeType": mime, "totalBytes": len(data)}, &created); err != nil {
		return "", time.Time{}, err
	}
	if created.UploadID == "" || created.ChunkMaxBytes <= 0 {
		return "", time.Time{}, fmt.Errorf("llm.media: invalid create response")
	}
	uploadCompleted := false
	defer func() {
		if !uploadCompleted {
			c.cancelUpload(baseURL, installID, created.UploadID)
		}
	}()
	for offset, recoveries := 0, 0; offset < len(data); {
		end := offset + created.ChunkMaxBytes
		if end > len(data) {
			end = len(data)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPut, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(created.UploadID), bytes.NewReader(data[offset:end]))
		if err != nil {
			return "", time.Time{}, err
		}
		req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
		req.Header.Set("Upload-Offset", strconv.Itoa(offset))
		req.Header.Set("Content-Type", "application/offset+octet-stream")
		resp, err := c.http.Do(req)
		if err != nil {
			// A broken response is ambiguous: the gateway may have fsynced this exact chunk before
			// the connection died. Read its cursor once rather than replaying bytes blindly.
			if recoveries < 1 {
				if confirmed, statusErr := c.uploadOffset(ctx, baseURL, installID, created.UploadID); statusErr == nil && confirmed >= offset && confirmed <= len(data) {
					offset, recoveries = confirmed, recoveries+1
					continue
				}
			}
			return "", time.Time{}, err
		}
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
		_ = resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return "", time.Time{}, fmt.Errorf("llm.media append: %w", classifyHTTPError(resp.StatusCode, raw))
		}
		var appended struct {
			Offset int `json:"offset"`
		}
		if err := json.Unmarshal(raw, &appended); err != nil || appended.Offset != end {
			if err != nil {
				return "", time.Time{}, fmt.Errorf("llm.media append: invalid response: %w", err)
			}
			return "", time.Time{}, fmt.Errorf("llm.media append: acknowledged offset %d, want %d", appended.Offset, end)
		}
		offset = end
		recoveries = 0
	}
	var completed struct {
		FetchPath string `json:"fetchPath"`
		ExpiresAt string `json:"expiresAt"`
	}
	if err := c.json(ctx, http.MethodPost, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(created.UploadID)+"/complete", installID, nil, &completed); err != nil {
		return "", time.Time{}, err
	}
	expiresAt, err := time.Parse(time.RFC3339, completed.ExpiresAt)
	if err != nil || !expiresAt.After(time.Now()) {
		if err != nil {
			return "", time.Time{}, fmt.Errorf("llm.media: invalid lease expiry: %w", err)
		}
		return "", time.Time{}, fmt.Errorf("llm.media: expired lease response")
	}
	p, err := url.Parse(completed.FetchPath)
	if err != nil || p.IsAbs() || p.Host != "" || !strings.HasPrefix(p.Path, "/v1/media/leases/") || p.RawQuery == "" {
		if err == nil {
			err = fmt.Errorf("llm.media: invalid relative lease fetch path")
		}
		return "", time.Time{}, err
	}
	uploadCompleted = true
	// Returned RELATIVE on purpose — the gateway prepends its own public origin. See Upload's
	// contract. 刻意返回**相对**形——由网关拼上它自己的公开 origin。见 Upload 契约。
	return p.String(), expiresAt, nil
}

func (c *MediaClient) uploadOffset(ctx context.Context, baseURL, installID, uploadID string) (int, error) {
	var status struct {
		Offset int `json:"offset"`
	}
	if err := c.json(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(uploadID), installID, nil, &status); err != nil {
		return 0, err
	}
	return status.Offset, nil
}

// cancelUpload is deliberately best-effort. A successful durable abort makes the staging object
// unusable immediately; any unavailable gateway is still covered by its bounded TTL/GC lifecycle.
// Cleanup errors must not hide the original upload failure from the user.
func (c *MediaClient) cancelUpload(baseURL, installID, uploadID string) {
	ctx, cancel := context.WithTimeout(context.Background(), cleanupTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodDelete, strings.TrimRight(baseURL, "/")+"/media/uploads/"+url.PathEscape(uploadID), nil)
	if err != nil {
		return
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	resp, err := c.http.Do(req)
	if err == nil && resp != nil {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4<<10))
		_ = resp.Body.Close()
	}
}

func normalizedMediaMIME(mime string) string { return strings.ToLower(strings.TrimSpace(mime)) }

func (c *MediaClient) json(ctx context.Context, method, endpoint, installID string, in, out any) error {
	var body io.Reader
	if in != nil {
		b, e := json.Marshal(in)
		if e != nil {
			return e
		}
		body = bytes.NewReader(b)
	}
	req, e := http.NewRequestWithContext(ctx, method, endpoint, body)
	if e != nil {
		return e
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	req.Header.Set("Content-Type", "application/json")
	resp, e := c.http.Do(req)
	if e != nil {
		return e
	}
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	_ = resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("llm.media: %w", classifyHTTPError(resp.StatusCode, raw))
	}
	return json.Unmarshal(raw, out)
}

// LeaseIDFromFetchPath extracts the lease id out of the relative fetch path Upload returns.
//
// **The token in that path is deliberately discarded.** The gateway re-derives it from the lease
// itself (`SampleFetchToken`), so sending it back would be handing a capability over a hop that has
// no use for it. Naming the lease is enough; ownership is what authorizes, not possession of the
// token.
//
// LeaseIDFromFetchPath 从 Upload 返回的相对 fetch path 里抽出 lease id。
//
// **那条路径里的 token 被刻意丢弃。** 网关会从 lease 自身重新派生它(`SampleFetchToken`),故把它送回去
// 等于在一个用不到它的跳上递出一个 capability。**指名 lease 就够了**;授权靠的是归属,不是持有 token。
func LeaseIDFromFetchPath(fetchPath string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(fetchPath))
	if err != nil || u.IsAbs() || u.Host != "" {
		return "", fmt.Errorf("llm.media: lease fetch path must be relative")
	}
	const prefix = "/v1/media/leases/"
	rest, ok := strings.CutPrefix(u.Path, prefix)
	if !ok {
		return "", fmt.Errorf("llm.media: unexpected lease fetch path")
	}
	id, _, ok := strings.Cut(rest, "/")
	if !ok || strings.TrimSpace(id) == "" {
		return "", fmt.Errorf("llm.media: lease fetch path carries no lease id")
	}
	return id, nil
}
