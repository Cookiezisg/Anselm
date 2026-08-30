// Package proxycore is the transparent recording reverse-proxy CORE shared by the in-test
// Recorder (harness/llmrecord.go) and the standalone rig tap (cmd/llmtap). It exists so the
// two invariants that make a pass-through proxy actually transparent live in exactly one place:
// the outbound Host header must name the UPSTREAM (a shared TLS frontend routes on it), and
// flushing must be forwarded end to end (FlushInterval -1 + a Flusher-forwarding writer) — an
// SSE stream buffered anywhere in the middle reads as a stall to the real client.
//
// Package proxycore 是透明录制反向代理的**核**,由测试内 Recorder(harness/llmrecord.go)与独立
// 台架 tap(cmd/llmtap)共用。它存在使「代理真正透明」的两条不变量只写一份:出站 Host 头必须写
// **上游**(共享 TLS 前端按它路由),flush 必须端到端转发(FlushInterval -1 + 转发 Flusher 的
// writer)——SSE 流在中间任何一处被缓冲,对真客户端读起来就是卡死。
package proxycore

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"sync"
)

// Handler builds the pass-through handler. onRequest sees every request with its full body
// (the body is re-wound before forwarding); onResponse, when non-nil, sees each upstream
// response header before the body streams (status capture without buffering).
//
// Handler 造直通处理器。onRequest 看到每个请求与完整 body(转发前已回卷);onResponse 非 nil 时
// 在 body 开始流之前看到每个上游响应头(捕获状态码而不缓冲)。
func Handler(upstream *url.URL, onRequest func(r *http.Request, body []byte), onResponse func(resp *http.Response)) http.Handler {
	return HandlerWithResponseBody(upstream, onRequest, onResponse, nil)
}

// HandlerWithResponseBody is Handler plus a post-stream response-body witness. The body is wrapped,
// not read up front, so downstream streaming and Flush semantics remain untouched; the callback
// runs once when the client reaches EOF or closes early.
//
// HandlerWithResponseBody 是 Handler 外加响应体见证。响应体只做包装、不提前读完，故下游流式与
// Flush 语义不变；客户端读到 EOF 或提前关闭时回调恰执行一次。
func HandlerWithResponseBody(upstream *url.URL, onRequest func(r *http.Request, body []byte), onResponse func(resp *http.Response), onResponseBody func(resp *http.Response, body []byte)) http.Handler {
	return HandlerWithResponseBodyPolicy(upstream, onRequest, onResponse, onResponseBody, nil)
}

// HandlerWithResponseBodyPolicy additionally allows a caller to decorate an upstream body
// before ReverseProxy starts copying it. This is intentionally narrow test-rig plumbing: a
// policy may close a live stream to exercise client reconnect and replay-gap behavior without
// buffering or rewriting the response.
func HandlerWithResponseBodyPolicy(upstream *url.URL, onRequest func(r *http.Request, body []byte), onResponse func(resp *http.Response), onResponseBody func(resp *http.Response, body []byte), decorate func(resp *http.Response, body io.ReadCloser) io.ReadCloser) http.Handler {
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.Out.URL.Scheme = upstream.Scheme
			pr.Out.URL.Host = upstream.Host
			pr.Out.URL.Path = joinUpstreamPath(upstream.Path, pr.In.URL.Path)
			pr.Out.Host = upstream.Host
		},
		FlushInterval: -1,
	}
	if onResponse != nil {
		proxy.ModifyResponse = func(resp *http.Response) error {
			onResponse(resp)
			// A 101 body is the live duplex stream after the HTTP upgrade, not a finite
			// response body. Wrapping it in a read-only witness makes ReverseProxy reject
			// the upgrade as "non-writable body". WebSocket bytes are witnessed by the
			// protocol test itself; ordinary responses still use the bounded body witness.
			// 101 的 body 是升级后的双工活流,不是有限 HTTP 响应体。把它包成只读 witness 会让
			// ReverseProxy 以「non-writable body」拒绝升级。WebSocket 字节由协议测试本身见证;
			// 普通响应仍走有界 body witness。
			if decorate != nil && resp.StatusCode != http.StatusSwitchingProtocols && resp.Body != nil {
				resp.Body = decorate(resp, resp.Body)
			}
			if onResponseBody != nil && resp.StatusCode != http.StatusSwitchingProtocols && resp.Body != nil {
				resp.Body = &responseBodyWitness{
					ReadCloser: resp.Body,
					complete:   func(body []byte) { onResponseBody(resp, body) },
				}
			}
			return nil
		}
	} else if onResponseBody != nil || decorate != nil {
		proxy.ModifyResponse = func(resp *http.Response) error {
			if decorate != nil && resp.StatusCode != http.StatusSwitchingProtocols && resp.Body != nil {
				resp.Body = decorate(resp, resp.Body)
			}
			if onResponseBody != nil && resp.StatusCode != http.StatusSwitchingProtocols && resp.Body != nil {
				resp.Body = &responseBodyWitness{
					ReadCloser: resp.Body,
					complete:   func(body []byte) { onResponseBody(resp, body) },
				}
			}
			return nil
		}
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		r.Body = io.NopCloser(bytes.NewReader(body))
		if onRequest != nil {
			onRequest(r, body)
		}
		proxy.ServeHTTP(&flushingWriter{ResponseWriter: w}, r)
	})
}

func joinUpstreamPath(base, request string) string {
	if base == "" || base == "/" {
		return request
	}
	return strings.TrimRight(base, "/") + "/" + strings.TrimLeft(request, "/")
}

type responseBodyWitness struct {
	io.ReadCloser
	mu       sync.Mutex
	buf      bytes.Buffer
	once     sync.Once
	complete func([]byte)
}

func (w *responseBodyWitness) Read(p []byte) (int, error) {
	n, err := w.ReadCloser.Read(p)
	if n > 0 {
		w.mu.Lock()
		_, _ = w.buf.Write(p[:n])
		w.mu.Unlock()
	}
	if err == io.EOF {
		w.finish()
	}
	return n, err
}

func (w *responseBodyWitness) Close() error {
	err := w.ReadCloser.Close()
	w.finish()
	return err
}

func (w *responseBodyWitness) finish() {
	w.once.Do(func() {
		w.mu.Lock()
		body := append([]byte(nil), w.buf.Bytes()...)
		w.mu.Unlock()
		w.complete(body)
	})
}

// flushingWriter forwards Flush. Wrapping a Flusher in anything that is not one is enough to
// silently kill every SSE route behind the proxy.
//
// flushingWriter 转发 Flush。把 Flusher 包进任何**不是** Flusher 的东西,就足以静默杀死代理
// 身后的每一条 SSE 路由。
type flushingWriter struct{ http.ResponseWriter }

// Unwrap lets http.ResponseController reach optional interfaces on the real writer. ReverseProxy
// uses that path to obtain Hijacker for WebSocket upgrades; forwarding Flush alone keeps SSE alive
// but turns every duplex speech route into a 500.
//
// Unwrap 让 http.ResponseController 继续取得真实 writer 的可选接口。ReverseProxy 正是经此取得
// WebSocket upgrade 所需的 Hijacker；只转发 Flush 虽能保 SSE，却会把全部双工语音路由变成 500。
func (w *flushingWriter) Unwrap() http.ResponseWriter { return w.ResponseWriter }

func (w *flushingWriter) Flush() {
	if f, ok := w.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}
