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
	"net"
	"net/http"
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
	TS       string `json:"ts"`
	Event    string `json:"event"`
	Method   string `json:"method,omitempty"`
	Path     string `json:"path,omitempty"`
	DelayMS  int    `json:"delayMs,omitempty"`
	Canceled bool   `json:"canceled,omitempty"`
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

func newHandler(upstream *url.URL, delayPath string, delay time.Duration, write func(journalRecord)) http.Handler {
	return proxycore.Handler(upstream, func(r *http.Request, _ []byte) {
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
	}, nil)
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8790", "local listen address")
	upstream := flag.String("upstream", "", "backend origin, e.g. http://127.0.0.1:8742 (required)")
	delayPath := flag.String("delay-path", "/api/v1/workspaces", "exact request path to delay")
	delayMS := flag.Int("delay-ms", 0, "delay for the exact path in milliseconds")
	out := flag.String("out", "", "JSONL journal path (required)")
	flag.Parse()
	if *upstream == "" || *out == "" || *delayPath == "" || *delayMS < 0 {
		fmt.Fprintln(os.Stderr, "appproxy: -upstream, -out, -delay-path and non-negative -delay-ms are required")
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
	w.write(journalRecord{Event: "ready", Path: *delayPath, DelayMS: *delayMS})

	handler := newHandler(u, *delayPath, delay, w.write)

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
