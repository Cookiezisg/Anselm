package llm

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

// These bound only the SETUP phase (connect / TLS / response headers), never the
// streaming body. A healthy long stream is governed solely by the per-event idle timer
// in providerClient.Stream + ctx cancellation — never a total wall-clock cap.
//
// 这些只界定建连阶段（connect / TLS / 响应头），绝不限流式 body。健康长流仅由
// providerClient.Stream 的逐事件 idle 计时器 + ctx 取消管控，无总墙钟。
const (
	dialTimeout           = 10 * time.Second
	tlsHandshakeTimeout   = 10 * time.Second
	responseHeaderTimeout = 60 * time.Second
)

// newSharedHTTPClient builds the one *http.Client every Provider reuses. Timeout is 0
// — NO total wall-clock cap (that would kill a healthy streaming response); only
// connect/TLS/header phases are bounded. Mid-stream silence is caught by the per-event
// idle timer in providerClient.Stream.
//
// newSharedHTTPClient 构造所有 Provider 复用的唯一 *http.Client。Timeout=0（无总墙钟
// ——否则杀健康流）；只界定 connect/TLS/header。流中静默由 Stream 的逐事件 idle 计时器捕获。
func newSharedHTTPClient() *http.Client {
	return &http.Client{
		Timeout: 0,
		Transport: &http.Transport{
			Proxy: http.ProxyFromEnvironment,
			DialContext: (&net.Dialer{
				Timeout:   dialTimeout,
				KeepAlive: 30 * time.Second,
			}).DialContext,
			ForceAttemptHTTP2:     true,
			TLSHandshakeTimeout:   tlsHandshakeTimeout,
			ResponseHeaderTimeout: responseHeaderTimeout,
			ExpectContinueTimeout: 1 * time.Second,
			MaxIdleConns:          100,
			IdleConnTimeout:       90 * time.Second,
		},
	}
}

// maxSSELineBytes lets the SSE scanner accept a single large data: line (e.g. a big
// tool-call arguments frame) instead of aborting at bufio's 64KB default token size.
//
// maxSSELineBytes 让 SSE 扫描器接受单条大 data: 行（如大 tool-call 参数帧），而非在
// bufio 默认 64KB token 上限处 abort。
const maxSSELineBytes = 8 << 20

// scanSSELines is a generic SSE scanner: read lines from r, strip the "data: " prefix,
// skip comment lines (": ..."), call fn for each JSON payload (return false to stop).
// Stops on "[DONE]". This is "how SSE works" — not a provider concern — so per-provider
// parsers reuse it.
//
// scanSSELines 是通用 SSE 扫描器：读行、剥 "data: " 前缀、跳过注释行、对每个 JSON
// payload 调 fn（返 false 提前停）；遇 "[DONE]" 终止。SSE 协议本身的语义，各 provider 复用。
func scanSSELines(r io.Reader, fn func(payload []byte) bool) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), maxSSELineBytes)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue // comment lines, blank lines, event: / id: lines
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			return nil
		}
		if data == "" {
			continue
		}
		if !fn([]byte(data)) {
			return nil
		}
	}
	return scanner.Err()
}

// doRequest is the shared transport "iron law": fire the request, swallow the error on
// caller-initiated cancellation, and map a non-200 status to a sentinel-wrapped error
// via classifyHTTPError. On the happy path it returns the live 200 response and ok=true
// (caller owns Body.Close). On any handled failure it yields the terminal event itself
// and returns ok=false. errPrefix preserves each Provider's "llm.<name>: do" wrapping.
//
// doRequest 是共享传输"铁律"：发请求；caller 主动取消时静默吞错；非 200 状态经
// classifyHTTPError 映射为带 sentinel 包装错。happy path 返 200 响应且 ok=true（Body.Close
// 由 caller 负责）；任何已处理失败自行 yield 终态事件并返 ok=false。
func doRequest(httpClient *http.Client, httpReq *http.Request, errPrefix string, yield func(StreamEvent) bool) (*http.Response, bool) {
	resp, err := httpClient.Do(httpReq)
	if err != nil {
		// ctx cancellation is caller intent — terminate silently, no error event.
		// ctx 取消是 caller 意图——静默终止，不发错误事件。
		if httpReq.Context().Err() != nil {
			return nil, false
		}
		yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%s: do: %w", errPrefix, err)})
		return nil, false
	}
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		resp.Body.Close()
		yield(StreamEvent{Type: EventError, Err: classifyHTTPError(resp.StatusCode, raw)})
		return nil, false
	}
	return resp, true
}

// classifyHTTPError maps an HTTP status + body to a sentinel-wrapped domain error. It
// lives here (not in a provider) because the status→error mapping is provider-agnostic.
//
// classifyHTTPError 把 HTTP 状态 + body 映射为带 sentinel 包装的 domain 错误。放共享层
// （非某个 provider），因为 status→error 映射与 provider 无关。
func classifyHTTPError(status int, body []byte) error {
	msg := strings.TrimSpace(string(body))
	if len(msg) > 200 {
		msg = msg[:200] + "..."
	}
	switch status {
	case http.StatusUnauthorized:
		return fmt.Errorf("%w (401): %s", ErrAuthFailed, msg)
	case http.StatusForbidden:
		return fmt.Errorf("%w (403): %s", ErrAuthFailed, msg)
	case http.StatusTooManyRequests:
		return fmt.Errorf("%w (429): %s", ErrRateLimited, msg)
	case http.StatusBadRequest:
		return fmt.Errorf("%w (400): %s", ErrBadRequest, msg)
	case http.StatusNotFound:
		return fmt.Errorf("%w (404): %s", ErrModelNotFound, msg)
	default:
		return fmt.Errorf("%w (%d): %s", ErrProviderError, status, msg)
	}
}
