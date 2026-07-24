package llm

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

// These bound only the SETUP phase (connect / TLS / response headers), never the
// streaming body. The streaming body is governed by providerClient.Stream's per-event idle timer
// (dead-socket detection) + a non-resetting total wall-clock cap (LLMStreamMaxSec, bounds a
// non-converging model) + ctx cancellation.
//
// 这些只界定建连阶段（connect / TLS / 响应头），绝不限流式 body。流式 body 由 providerClient.Stream
// 的逐事件 idle 计时器（死连接探测）+ 不重置的总墙钟（LLMStreamMaxSec，封顶不收敛的模型）+ ctx 取消管控。
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

// NewHTTPClient exposes the shared transport policy to the composition root so
// it can wrap the Anselm gateway lane with device-proof signing.
func NewHTTPClient() *http.Client { return newSharedHTTPClient() }

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
func scanSSELines(ctx context.Context, r io.Reader, fn func(payload []byte) bool) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 0, 64*1024), maxSSELineBytes)
	for scanner.Scan() {
		// Break on a cancelled ctx even when the stream only dribbles non-data lines (SSE
		// keep-alive comments). Those skip fn — where ctx is otherwise checked — so without this a
		// silent keep-alive stream traps the scan forever: the idle-timer's cancel never lands, no
		// EventError is surfaced, and the turn never finalizes (message stuck `streaming`). F33/F12.
		//
		// ctx 取消时必须能打断扫描——即便流只在滴非 data 行（SSE keep-alive 注释）。这些行跳过 fn（ctx 本在
		// fn 内才查），否则静默 keep-alive 流把扫描死困：idle 计时器的 cancel 永不生效、不报 EventError、回合
		// 永不收尾（message 卡 streaming）。F33/F12。
		if ctx.Err() != nil {
			return ctx.Err()
		}
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
	switch status {
	case http.StatusUnauthorized:
		return fmt.Errorf("%w (401)", ErrAuthFailed)
	case http.StatusForbidden:
		return fmt.Errorf("%w (403)", ErrAuthFailed)
	case http.StatusTooManyRequests:
		return fmt.Errorf("%w (429)", ErrRateLimited)
	case http.StatusPaymentRequired:
		// Free-tier gateway signals monthly budget exhaustion as 402. Map to ErrQuotaExhausted
		// (non-retryable) so a depleted free tier fails honestly instead of burning 3 retries.
		//
		// 免费档网关用 402 报本月额度耗尽。映射 ErrQuotaExhausted（不可重试），让耗尽的免费档诚实失败、
		// 不空烧 3 次重试。
		return fmt.Errorf("%w (402)", ErrQuotaExhausted)
	case http.StatusBadRequest, http.StatusRequestEntityTooLarge, http.StatusUnprocessableEntity:
		if reason := requestRejectionReason(body); reason != "" {
			return &RequestRejectedError{Reason: reason, Status: status}
		}
		return fmt.Errorf("%w (%d)", ErrBadRequest, status)
	case http.StatusNotFound:
		return fmt.Errorf("%w (404)", ErrModelNotFound)
	default:
		return fmt.Errorf("%w (%d)", ErrProviderError, status)
	}
}

// requestRejectionReason understands the managed gateway's structured error
// envelope first, then a small compatibility fallback for direct providers.
// It returns only a closed reason enum; provider text never escapes through the
// typed error.
func requestRejectionReason(body []byte) string {
	var env struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
			Details struct {
				Reason string `json:"reason"`
			} `json:"details"`
		} `json:"error"`
	}
	_ = json.Unmarshal(body, &env)
	switch env.Error.Code {
	case "REQUEST_BODY_TOO_LARGE":
		return RejectionRequestBodyTooLarge
	case "UPSTREAM_REJECTED":
		switch env.Error.Details.Reason {
		case RejectionContextLength, RejectionMaxTokens, RejectionInvalidRequest:
			return env.Error.Details.Reason
		}
	}
	message := strings.ToLower(env.Error.Message)
	if message == "" {
		message = strings.ToLower(string(body))
	}
	switch {
	case strings.Contains(message, "context length"),
		strings.Contains(message, "context window"),
		strings.Contains(message, "input too large"),
		strings.Contains(message, "too many input tokens"),
		strings.Contains(message, "maximum input"):
		return RejectionContextLength
	case strings.Contains(message, "max_tokens"):
		return RejectionMaxTokens
	default:
		return ""
	}
}

// streamProviderError applies the same closed rejection vocabulary to providers that report an
// error after returning HTTP 200/SSE. Provider text is inspected only in-process to recognize a
// recoverable reason, then discarded: neither the EventError nor the user-facing turn can echo it.
//
// streamProviderError 把同一闭集拒绝词表用于 HTTP 200/SSE 后才报错的 provider。只在进程内检查
// provider 文本以识别可恢复原因，随即丢弃：EventError 与用户可见回合都不会回显它。
func streamProviderError(code, message string) error {
	// Some providers split an error code and message while others only provide a message. Joining
	// them here is internal-only and bounded by the already-decoded SSE object.
	if reason := requestRejectionReason([]byte(code + " " + message)); reason != "" {
		return &RequestRejectedError{Reason: reason, Status: http.StatusBadRequest}
	}
	return fmt.Errorf("%w: upstream stream rejected the request", ErrProviderError)
}
