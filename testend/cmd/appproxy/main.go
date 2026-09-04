// appproxy is a narrow acceptance-rig perturbation: it delays one App API path while
// transparently forwarding every request to the conductor-owned backend. The backend still owns
// its real port and the independent SSE witness connects directly to it; this process exists only
// to make an otherwise sub-frame workspace bootstrap wait observable in the real App.
//
// appproxy 是一个窄用途验收台架扰动器：只延迟一个 App API 路径，同时把所有请求透明转发给
// conductor 自己持有的 backend。backend 仍占有真实端口，独立 SSE witness 仍直连它；此进程
// 只为让真实 App 中平时小于一帧的 workspace bootstrap 等待可观察。
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/sunweilin/anselm/testend/harness/proxycore"
)

type journalRecord struct {
	TS        string `json:"ts"`
	Event     string `json:"event"`
	Method    string `json:"method,omitempty"`
	Path      string `json:"path,omitempty"`
	DelayMS   int    `json:"delayMs,omitempty"`
	Status    int    `json:"status,omitempty"`
	Remaining int    `json:"remaining,omitempty"`
	Canceled  bool   `json:"canceled,omitempty"`
	Host      string `json:"host,omitempty"`
	To        string `json:"to,omitempty"`
}

type journalWriter struct {
	mu sync.Mutex
	w  *os.File
}

func (j *journalWriter) write(r journalRecord) {
	r.TS = time.Now().UTC().Format(time.RFC3339Nano)
	b, err := json.Marshal(r)
	if err != nil {
		return
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	_, _ = j.w.Write(append(b, '\n'))
}

func delayRequest(ctx context.Context, delay time.Duration) bool {
	if delay <= 0 {
		return true
	}
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-timer.C:
		return true
	case <-ctx.Done():
		return false
	}
}

func matchesDelayPath(r *http.Request, path string) bool {
	return r.Method == http.MethodGet && r.URL.Path == path
}

type failureBudget struct {
	mu        sync.Mutex
	remaining int
}

type dropBudget struct {
	mu        sync.Mutex
	remaining int
}

type rewriteHostContextKey struct{}

type rewriteHostContext struct {
	host string
}

func (b *dropBudget) take() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.remaining <= 0 {
		return false
	}
	b.remaining--
	return true
}

func (b *dropBudget) exhausted() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.remaining == 0
}

type dropAfterBody struct {
	io.ReadCloser
	once  sync.Once
	timer *time.Timer
}

func newDropAfterBody(body io.ReadCloser, after time.Duration, write func(journalRecord), path string) io.ReadCloser {
	d := &dropAfterBody{ReadCloser: body}
	d.timer = time.AfterFunc(after, func() {
		write(journalRecord{Event: "drop", Path: path, DelayMS: int(after / time.Millisecond), Canceled: true})
		_ = d.Close()
	})
	return d
}

func (d *dropAfterBody) Close() error {
	var err error
	d.once.Do(func() {
		d.timer.Stop()
		err = d.ReadCloser.Close()
	})
	return err
}

func (b *failureBudget) take() (bool, int) {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.remaining <= 0 {
		return false, 0
	}
	b.remaining--
	return true, b.remaining
}

func injectedError(w http.ResponseWriter, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write([]byte("{\"error\":{\"code\":\"RIG_INJECTED_FAILURE\",\"message\":\"acceptance rig injected a transient failure\"}}\n"))
}

func newHandler(
	upstream *url.URL,
	delayPath string,
	delay time.Duration,
	failCount int,
	failStatus int,
	dropAfter time.Duration,
	dropCount int,
	failAfterDropCount int,
	failAfterDropDelay time.Duration,
	upstreamAuthToken string,
	upstreamAuthPath string,
	dropWorkspaceHeaderCount int,
	rewriteHostPath string,
	rewriteHostName string,
	rewriteHostCount int,
	rewritePathFrom string,
	rewritePathTo string,
	rewritePathCount int,
	rewriteMethodPath string,
	rewriteMethodFrom string,
	rewriteMethodTo string,
	rewriteMethodCount int,
	write func(journalRecord),
) http.Handler {
	failures := &failureBudget{remaining: failCount}
	drops := &dropBudget{remaining: dropCount}
	workspaceHeaderDrops := &dropBudget{remaining: dropWorkspaceHeaderCount}
	postDropFailures := &failureBudget{remaining: failAfterDropCount}
	rewriteHosts := &dropBudget{remaining: rewriteHostCount}
	rewritePaths := &dropBudget{remaining: rewritePathCount}
	rewriteMethods := &dropBudget{remaining: rewriteMethodCount}
	proxy := proxycore.HandlerWithResponseBodyPolicyAndRewrite(upstream, func(r *http.Request, _ []byte) {
		targeted := matchesDelayPath(r, delayPath)
		record := journalRecord{Event: "request", Method: r.Method, Path: r.URL.Path}
		if targeted {
			record.DelayMS = int(delay / time.Millisecond)
		}
		write(record)
		if !targeted {
			return
		}
		if delayRequest(r.Context(), delay) {
			write(journalRecord{Event: "forward", Method: r.Method, Path: r.URL.Path, DelayMS: record.DelayMS})
		} else {
			write(journalRecord{Event: "canceled", Method: r.Method, Path: r.URL.Path, DelayMS: record.DelayMS, Canceled: true})
		}
	}, nil, nil, func(resp *http.Response, body io.ReadCloser) io.ReadCloser {
		if resp.Request != nil {
			if shouldDrop, _ := resp.Request.Context().Value(dropContextKey{}).(bool); shouldDrop {
				return newDropAfterBody(body, dropAfter, write, resp.Request.URL.Path)
			}
		}
		return body
	}, func(pr *httputil.ProxyRequest) {
		if override, ok := pr.In.Context().Value(rewriteHostContextKey{}).(rewriteHostContext); ok {
			pr.Out.Host = override.host
		}
	})

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if matchesDelayPath(r, delayPath) &&
			r.Header.Get("X-Anselm-Workspace-ID") != "" &&
			workspaceHeaderDrops.take() {
			r.Header.Del("X-Anselm-Workspace-ID")
			write(journalRecord{Event: "workspace_header_dropped", Method: r.Method, Path: r.URL.Path})
		}
		if upstreamAuthToken != "" {
			r.Header.Del("Authorization")
			if r.URL.Path == upstreamAuthPath {
				r.Header.Set("Authorization", "Bearer "+upstreamAuthToken)
			}
		}
		if rewriteHostPath != "" && r.URL.Path == rewriteHostPath && rewriteHosts.take() {
			r = r.WithContext(context.WithValue(r.Context(), rewriteHostContextKey{}, rewriteHostContext{host: rewriteHostName}))
			write(journalRecord{Event: "host_rewritten", Method: r.Method, Path: r.URL.Path, Host: rewriteHostName})
		}
		if rewritePathFrom != "" && r.URL.Path == rewritePathFrom && rewritePaths.take() {
			originalPath := r.URL.Path
			r.URL.Path = rewritePathTo
			r.URL.RawPath = ""
			r.RequestURI = r.URL.RequestURI()
			write(journalRecord{Event: "path_rewritten", Method: r.Method, Path: originalPath, To: rewritePathTo})
		}
		if rewriteMethodPath != "" && r.URL.Path == rewriteMethodPath && r.Method == rewriteMethodFrom && rewriteMethods.take() {
			originalMethod := r.Method
			r.Method = rewriteMethodTo
			write(journalRecord{Event: "method_rewritten", Method: originalMethod, Path: r.URL.Path, To: rewriteMethodTo})
		}
		if matchesDelayPath(r, delayPath) {
			if taken, remaining := failures.take(); taken {
				write(journalRecord{
					Event:   "request",
					Method:  r.Method,
					Path:    r.URL.Path,
					DelayMS: int(delay / time.Millisecond),
				})
				if !delayRequest(r.Context(), delay) {
					write(journalRecord{Event: "canceled", Method: r.Method, Path: r.URL.Path, DelayMS: int(delay / time.Millisecond), Canceled: true})
					return
				}
				write(journalRecord{
					Event:     "failure",
					Method:    r.Method,
					Path:      r.URL.Path,
					DelayMS:   int(delay / time.Millisecond),
					Status:    failStatus,
					Remaining: remaining,
				})
				injectedError(w, failStatus)
				return
			}
			if failAfterDropCount > 0 && drops.exhausted() {
				if taken, remaining := postDropFailures.take(); taken {
					if !delayRequest(r.Context(), failAfterDropDelay) {
						write(journalRecord{Event: "canceled_after_drop", Method: r.Method, Path: r.URL.Path, DelayMS: int(failAfterDropDelay / time.Millisecond), Canceled: true})
						return
					}
					write(journalRecord{Event: "failure_after_drop", Method: r.Method, Path: r.URL.Path, Status: failStatus, Remaining: remaining})
					injectedError(w, failStatus)
					return
				}
			}
		}
		if dropAfter > 0 && matchesDelayPath(r, delayPath) && drops.take() {
			r = r.WithContext(context.WithValue(r.Context(), dropContextKey{}, true))
			write(journalRecord{Event: "drop_armed", Method: r.Method, Path: r.URL.Path, DelayMS: int(dropAfter / time.Millisecond)})
		}
		proxy.ServeHTTP(w, r)
	})
}

type dropContextKey struct{}

func main() {
	listen := flag.String("listen", "127.0.0.1:8790", "local listen address")
	upstream := flag.String("upstream", "", "backend origin, e.g. http://127.0.0.1:8742 (required)")
	delayPath := flag.String("delay-path", "/api/v1/workspaces", "exact request path to delay")
	delayMS := flag.Int("delay-ms", 0, "delay for the exact path in milliseconds")
	failCount := flag.Int("fail-count", 0, "number of targeted requests to fail before forwarding")
	dropAfterMS := flag.Int("drop-after-ms", 0, "close the first drop-count targeted response streams after this many milliseconds")
	dropCount := flag.Int("drop-count", 0, "number of targeted response streams to close after drop-after-ms")
	failAfterDropCount := flag.Int("fail-after-drop-count", 0, "number of targeted requests to fail after the drop budget is exhausted")
	failAfterDropDelayMS := flag.Int("fail-after-drop-delay-ms", 0, "delay those post-drop failures without delaying the initial stream")
	upstreamAuthToken := flag.String("upstream-auth-token", "", "inject this bearer only on upstream-auth-path")
	upstreamAuthPath := flag.String("upstream-auth-path", "", "exact path receiving upstream-auth-token")
	dropWorkspaceHeaderCount := flag.Int("drop-workspace-header-count", 0, "remove X-Anselm-Workspace-ID for this many requests (acceptance perturbation)")
	rewriteHostPath := flag.String("rewrite-host-path", "", "exact request path whose upstream Host header is rewritten (acceptance perturbation)")
	rewriteHostName := flag.String("rewrite-host", "", "Host header sent upstream for rewrite-host-path (acceptance perturbation)")
	rewriteHostCount := flag.Int("rewrite-host-count", 0, "number of targeted requests whose upstream Host header is rewritten")
	rewritePathFrom := flag.String("rewrite-path-from", "", "exact request path whose upstream path is rewritten (acceptance perturbation)")
	rewritePathTo := flag.String("rewrite-path-to", "", "upstream path used by rewrite-path-from (acceptance perturbation)")
	rewritePathCount := flag.Int("rewrite-path-count", 0, "number of targeted requests whose upstream path is rewritten")
	rewriteMethodPath := flag.String("rewrite-method-path", "", "exact request path whose method is rewritten (acceptance perturbation)")
	rewriteMethodFrom := flag.String("rewrite-method-from", "", "request method selected for rewrite-method-path")
	rewriteMethodTo := flag.String("rewrite-method-to", "", "upstream method used by rewrite-method-path")
	rewriteMethodCount := flag.Int("rewrite-method-count", 0, "number of targeted requests whose method is rewritten")
	failStatus := flag.Int("fail-status", http.StatusServiceUnavailable, "HTTP status for injected failures")
	out := flag.String("out", "", "JSONL journal path (required)")
	flag.Parse()
	if *upstream == "" || *out == "" || *delayPath == "" || *delayMS < 0 || *failCount < 0 || *dropAfterMS < 0 || *dropCount < 0 || *failAfterDropCount < 0 || *failAfterDropDelayMS < 0 || *dropWorkspaceHeaderCount < 0 || *rewriteHostCount < 0 || *rewritePathCount < 0 || *rewriteMethodCount < 0 || (*rewriteHostCount > 0 && (*rewriteHostPath == "" || *rewriteHostName == "")) || (*rewritePathCount > 0 && (*rewritePathFrom == "" || *rewritePathTo == "")) || (*rewriteMethodCount > 0 && (*rewriteMethodPath == "" || *rewriteMethodFrom == "" || *rewriteMethodTo == "")) || *failStatus < 400 || *failStatus > 599 || (*upstreamAuthToken != "" && *upstreamAuthPath == "") {
		fmt.Fprintln(os.Stderr, "appproxy: -upstream, -out, -delay-path, non-negative delay/failure/drop values, and fail-status 400..599 are required")
		os.Exit(2)
	}
	u, err := url.Parse(strings.TrimRight(*upstream, "/"))
	if err != nil || u.Scheme == "" || u.Host == "" {
		fmt.Fprintf(os.Stderr, "appproxy: bad upstream %q\n", *upstream)
		os.Exit(2)
	}
	journal, err := os.OpenFile(*out, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "appproxy: open journal: %v\n", err)
		os.Exit(1)
	}
	defer journal.Close()
	w := &journalWriter{w: journal}
	delay := time.Duration(*delayMS) * time.Millisecond
	w.write(journalRecord{Event: "ready", Path: *delayPath, DelayMS: *delayMS, Status: *failStatus, Remaining: *failCount})

	handler := newHandler(u, *delayPath, delay, *failCount, *failStatus, time.Duration(*dropAfterMS)*time.Millisecond, *dropCount, *failAfterDropCount, time.Duration(*failAfterDropDelayMS)*time.Millisecond, *upstreamAuthToken, *upstreamAuthPath, *dropWorkspaceHeaderCount, *rewriteHostPath, *rewriteHostName, *rewriteHostCount, *rewritePathFrom, *rewritePathTo, *rewritePathCount, *rewriteMethodPath, *rewriteMethodFrom, *rewriteMethodTo, *rewriteMethodCount, w.write)

	server := &http.Server{Addr: *listen, Handler: handler}
	listener, err := net.Listen("tcp", *listen)
	if err != nil {
		fmt.Fprintf(os.Stderr, "appproxy: listen %s: %v\n", *listen, err)
		os.Exit(1)
	}
	w.write(journalRecord{Event: "listening"})

	serveErr := make(chan error, 1)
	go func() { serveErr <- server.Serve(listener) }()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(signals)
	select {
	case <-signals:
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_ = server.Shutdown(ctx)
		cancel()
	case err := <-serveErr:
		if err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "appproxy: serve: %v\n", err)
			os.Exit(1)
		}
	}
}
