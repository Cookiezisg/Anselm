package middleware

import (
	"bufio"
	"fmt"
	"net"
	"net/http"
	"strings"
	"time"

	"go.uber.org/zap"
)

// RequestLogger logs one line per request; must sit INSIDE Recover for 500 visibility.
//
// RequestLogger 每请求一行日志；必须在 Recover 内层才能看到 500 状态。
func RequestLogger(log *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := newStatusRecorder(w)

			next.ServeHTTP(rec, r)

			log.Info("http request",
				zap.String("method", r.Method),
				zap.String("path", safeLogPath(r.URL.Path)),
				zap.Int("status", rec.status),
				zap.Int("bytes", rec.bytes),
				zap.Int64("elapsed_ms", time.Since(start).Milliseconds()),
			)
		})
	}
}

func safeLogPath(path string) string {
	const playbackPrefix = "/api/v1/attachment-playback/"
	if strings.HasPrefix(path, playbackPrefix) {
		return playbackPrefix + "<redacted>"
	}
	return path
}

// statusRecorder wraps ResponseWriter to capture status + bytes for logging; Flush is
// delegated so SSE streams through the logger middleware.
//
// statusRecorder 包装 ResponseWriter 记录状态码 + 字节数；Flush 委托底层，让 SSE 穿透 logger。
type statusRecorder struct {
	http.ResponseWriter
	status      int
	bytes       int
	wroteHeader bool
}

func newStatusRecorder(w http.ResponseWriter) *statusRecorder {
	return &statusRecorder{ResponseWriter: w, status: http.StatusOK}
}

func (r *statusRecorder) WriteHeader(code int) {
	if r.wroteHeader {
		return
	}
	r.wroteHeader = true
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if !r.wroteHeader {
		r.wroteHeader = true
	}
	n, err := r.ResponseWriter.Write(b)
	r.bytes += n
	return n, err
}

func (r *statusRecorder) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Hijack forwards the underlying Hijacker. A wrapper that hides it turns EVERY WebSocket route into
// a plain-text 500: gorilla's Upgrade needs to take over the TCP connection, asks the writer for
// http.Hijacker, and finds this struct instead of the real thing. Found live (E 真机验收 0725):
// /speech/asr answered "Internal Server Error" with no log line from any handler — the request died
// inside Upgrade, in front of all of them. Flush got delegated for SSE when this recorder was born;
// Hijack is the same obligation for WS.
//
// Hijack 转发底层的 Hijacker。包装层藏住它,**每一条 WebSocket 路由**都会变成裸文本 500:gorilla 的
// Upgrade 需要接管 TCP 连接,向 writer 要 http.Hijacker,结果拿到的是本结构体而非真身。真机验收(0725)
// 实地撞上:/speech/asr 答「Internal Server Error」,且任何 handler 都没留一行日志——请求死在 Upgrade
// 里、死在它们全部的前面。这个 recorder 出生时就为 SSE 委托了 Flush;Hijack 是对 WS 的同一义务。
func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hj, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("middleware.statusRecorder: underlying ResponseWriter does not support hijacking")
	}
	return hj.Hijack()
}
