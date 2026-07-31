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
)

// Handler builds the pass-through handler. onRequest sees every request with its full body
// (the body is re-wound before forwarding); onResponse, when non-nil, sees each upstream
// response header before the body streams (status capture without buffering).
//
// Handler 造直通处理器。onRequest 看到每个请求与完整 body(转发前已回卷);onResponse 非 nil 时
// 在 body 开始流之前看到每个上游响应头(捕获状态码而不缓冲)。
func Handler(upstream *url.URL, onRequest func(r *http.Request, body []byte), onResponse func(resp *http.Response)) http.Handler {
	proxy := &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.Out.URL.Scheme = upstream.Scheme
			pr.Out.URL.Host = upstream.Host
			pr.Out.Host = upstream.Host
		},
		FlushInterval: -1,
	}
	if onResponse != nil {
		proxy.ModifyResponse = func(resp *http.Response) error {
			onResponse(resp)
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

// flushingWriter forwards Flush. Wrapping a Flusher in anything that is not one is enough to
// silently kill every SSE route behind the proxy.
//
// flushingWriter 转发 Flush。把 Flusher 包进任何**不是** Flusher 的东西,就足以静默杀死代理
// 身后的每一条 SSE 路由。
type flushingWriter struct{ http.ResponseWriter }

func (w *flushingWriter) Flush() {
	if f, ok := w.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}
