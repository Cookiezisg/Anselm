package llm

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

// sharedHTTPTimeout caps a single streaming call; long enough for slow
// reasoning models, short enough to fail a wedged connection.
//
// sharedHTTPTimeout 限制单次流式调用时长；够慢推理模型用，又能让卡死连接超时失败。
const sharedHTTPTimeout = 120 * time.Second

// newSharedHTTPClient builds the one *http.Client every Provider reuses across requests.
//
// newSharedHTTPClient 构造所有 Provider 跨请求复用的唯一 *http.Client。
func newSharedHTTPClient() *http.Client {
	return &http.Client{Timeout: sharedHTTPTimeout}
}

// doRequest is the shared transport "iron law": fire the request, swallow the
// error on caller-initiated cancellation, and map a non-200 status to a
// sentinel-wrapped error via classifyHTTPError. On the happy path it returns
// the live response (status 200) and ok=true; the caller owns Body.Close.
// On any handled failure it yields the terminal event itself and returns ok=false.
// errPrefix preserves each Provider's original "llm.<name>: do" error wrapping.
//
// doRequest 是共享传输"铁律"：发请求；caller 主动取消时静默吞错；非 200 状态
// 经 classifyHTTPError 映射为 sentinel 包装错。happy path 返回 200 响应且 ok=true，
// Body.Close 由 caller 负责；任何已处理失败自行 yield 终态事件并返回 ok=false。
// errPrefix 保留各 Provider 原有的 "llm.<name>: do" 错误包装。
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
