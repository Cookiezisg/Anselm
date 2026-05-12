// dispatch_http.go — HTTPDispatcher. Reads node.Config keys `method` /
// `url` / `headers` / `body` and calls net/http with SSRF guard
// (loopback / link-local / private network refusal — Plan 05 §3.2 http).
//
// dispatch_http.go —— HTTPDispatcher;net/http GET/POST/...,SSRF 守卫
// 拒 loopback/link-local/private。

package scheduler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultHTTPTimeout is the per-request timeout used when node.Config
// doesn't specify one. Same default as the spec'd 30s for http nodes.
//
// DefaultHTTPTimeout 默认 30s(spec §6.8 http 节点默认)。
const DefaultHTTPTimeout = 30 * time.Second

// HTTPDispatcher bridges workflow http nodes to net/http with SSRF guard.
//
// HTTPDispatcher 桥接 workflow http 节点到 net/http(带 SSRF 守卫)。
type HTTPDispatcher struct {
	client *http.Client
}

// NewHTTPDispatcher constructs HTTPDispatcher. Pass a custom *http.Client
// for test wiring (timeout / transport mocking).
//
// NewHTTPDispatcher 构造 HTTPDispatcher;测试时可传 mock client。
func NewHTTPDispatcher(client *http.Client) *HTTPDispatcher {
	if client == nil {
		client = &http.Client{Timeout: DefaultHTTPTimeout}
	}
	return &HTTPDispatcher{client: client}
}

// Dispatch reads method/url/headers/body from node.Config.
//
// Dispatch 读 method/url/headers/body。
func (d *HTTPDispatcher) Dispatch(ctx context.Context, in DispatchInput) DispatchOutput {
	method, _ := in.Node.Config["method"].(string)
	rawURL, _ := in.Node.Config["url"].(string)
	if rawURL == "" {
		return DispatchOutput{Error: fmt.Errorf("http node %q: url required", in.Node.ID)}
	}
	if method == "" {
		method = http.MethodGet
	}
	method = strings.ToUpper(method)

	if err := ssrfGuard(rawURL); err != nil {
		return DispatchOutput{Error: fmt.Errorf("http node %q: %w", in.Node.ID, err)}
	}

	var body io.Reader
	if bodyVal, ok := in.Node.Config["body"]; ok && bodyVal != nil {
		buf, err := json.Marshal(bodyVal)
		if err != nil {
			return DispatchOutput{Error: fmt.Errorf("http node %q: marshal body: %w", in.Node.ID, err)}
		}
		body = bytes.NewReader(buf)
	}

	req, err := http.NewRequestWithContext(ctx, method, rawURL, body)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("http node %q: new request: %w", in.Node.ID, err)}
	}
	if headers, ok := in.Node.Config["headers"].(map[string]any); ok {
		for k, v := range headers {
			if s, ok := v.(string); ok {
				req.Header.Set(k, s)
			}
		}
	}
	if body != nil && req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := d.client.Do(req)
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("http node %q: do: %w", in.Node.ID, err)}
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 10*1024*1024)) // 10MB cap
	if err != nil {
		return DispatchOutput{Error: fmt.Errorf("http node %q: read response: %w", in.Node.ID, err)}
	}

	var parsed any
	if json.Valid(respBody) {
		_ = json.Unmarshal(respBody, &parsed)
	} else {
		parsed = string(respBody)
	}
	return DispatchOutput{Outputs: map[string]any{
		"out":    parsed,
		"status": resp.StatusCode,
	}}
}

// ssrfGuard rejects URLs that resolve to loopback / link-local / private
// addresses. Defence-in-depth: the http client may still fall through to
// public DNS but we block obvious internal targets up front.
//
// ssrfGuard 拒 loopback / link-local / private 地址(防 SSRF)。
func ssrfGuard(rawURL string) error {
	u, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid url: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return errors.New("only http/https schemes allowed")
	}
	host := u.Hostname()
	if host == "" {
		return errors.New("empty host")
	}
	if isBlockedHost(host) {
		return fmt.Errorf("ssrf guard: host %q blocked", host)
	}
	ips, err := net.LookupIP(host)
	if err != nil {
		// Resolution failure — let the HTTP client surface the real error.
		// DNS 解析失败 — 让 client 自报真错。
		return nil
	}
	for _, ip := range ips {
		if isBlockedIP(ip) {
			return fmt.Errorf("ssrf guard: host %q resolves to blocked %s", host, ip)
		}
	}
	return nil
}

func isBlockedHost(h string) bool {
	h = strings.ToLower(h)
	return h == "localhost" || strings.HasSuffix(h, ".local") || strings.HasSuffix(h, ".internal")
}

func isBlockedIP(ip net.IP) bool {
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsPrivate() || ip.IsUnspecified() {
		return true
	}
	return false
}
