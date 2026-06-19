package engine

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// fakeOpenAI serves /v1/embeddings in the OpenAI shape llama-server emits.
//
// fakeOpenAI 以 llama-server 的 OpenAI 形状服务 /v1/embeddings。
func fakeOpenAI(t *testing.T) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/embeddings" {
			http.NotFound(w, r)
			return
		}
		var req struct {
			Input []string `json:"input"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		type item struct {
			Embedding []float32 `json:"embedding"`
		}
		out := struct {
			Data []item `json:"data"`
		}{}
		for i := range req.Input {
			out.Data = append(out.Data, item{Embedding: []float32{float32(i), 1, 0}})
		}
		_ = json.NewEncoder(w).Encode(out)
	}))
}

func TestBuiltin_EmbedViaOpenAIShape(t *testing.T) {
	srv := fakeOpenAI(t)
	defer srv.Close()
	b := NewBuiltinForTest(srv.URL)
	vecs, err := b.Embed(context.Background(), []string{"你好", "world"})
	if err != nil {
		t.Fatalf("embed: %v", err)
	}
	if len(vecs) != 2 || len(vecs[0]) != 3 || vecs[1][0] != 1 {
		t.Fatalf("vectors wrong: %+v", vecs)
	}
	if st, _ := b.Status(); st != StatusReady {
		t.Fatalf("status = %s", st)
	}
	if b.Model() == "" {
		t.Fatal("model must be pinned")
	}
}

func TestBuiltin_InstallFailureRecordsError(t *testing.T) {
	b := NewBuiltin(failEnsurer{}, nil)
	if _, err := b.Embed(context.Background(), []string{"x"}); err == nil {
		t.Fatal("expected install failure")
	}
	st, lastErr := b.Status()
	if st != StatusError || !strings.Contains(lastErr, "install llama-server") {
		t.Fatalf("status = %s %q", st, lastErr)
	}
}

type failEnsurer struct{}

func (failEnsurer) EnsureTool(context.Context, string, string) (string, error) {
	return "", context.DeadlineExceeded
}

// slowEnsurer blocks EnsureTool until its ctx is cancelled — a stand-in for a
// first-demand model download in flight. Signals once it is actually inside the
// call (so the test knows ensureRunning is holding b.mu).
//
// slowEnsurer 阻塞 EnsureTool 直到 ctx 取消——模拟在飞的首用下载。进入调用即发信号
// （让测试知道 ensureRunning 已持 b.mu）。
type slowEnsurer struct {
	entered  chan struct{}
	released chan struct{}
}

func (s *slowEnsurer) EnsureTool(ctx context.Context, _, _ string) (string, error) {
	close(s.entered)
	<-ctx.Done() // unblocks only when Close cancels the install ctx (R14)
	close(s.released)
	return "", ctx.Err()
}

// TestBuiltin_CloseBoundedDuringDownload — R14: Close must return promptly even
// while ensureRunning holds b.mu across a (simulated long) first-demand download.
// Close aborts the install ctx so ensureRunning unwinds and releases b.mu; Close
// itself must not block on App.Shutdown's deadline.
func TestBuiltin_CloseBoundedDuringDownload(t *testing.T) {
	ens := &slowEnsurer{entered: make(chan struct{}), released: make(chan struct{})}
	b := NewBuiltin(ens, nil)

	// Drive ensureRunning into the download (it now holds b.mu inside EnsureTool).
	// 把 ensureRunning 推进到下载（此刻它在 EnsureTool 内持 b.mu）。
	go func() { _, _ = b.Embed(context.Background(), []string{"x"}) }()
	select {
	case <-ens.entered:
	case <-time.After(3 * time.Second):
		t.Fatal("ensureRunning never reached the download")
	}

	// Close with a deadline that is shorter than the (infinite) download. It must
	// return well within the test budget — the abort cancels the install ctx.
	// 用比（无限）下载短的 deadline 调 Close，必须在预算内返回——中止取消安装 ctx。
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	done := make(chan struct{})
	go func() { b.Close(ctx); close(done) }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Close blocked on the in-flight download (R14 unbounded shutdown)")
	}

	// The abort must have propagated: the stuck EnsureTool unblocked and returned.
	// 中止须已传播：卡住的 EnsureTool 解阻并返回。
	select {
	case <-ens.released:
	case <-time.After(3 * time.Second):
		t.Fatal("Close did not abort the in-flight install ctx (R14)")
	}
}

func TestOllama_EmbedShape(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/embed" {
			http.NotFound(w, r)
			return
		}
		var req struct {
			Input []string `json:"input"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		out := struct {
			Embeddings [][]float32 `json:"embeddings"`
		}{}
		for range req.Input {
			out.Embeddings = append(out.Embeddings, []float32{0.5, 0.5})
		}
		_ = json.NewEncoder(w).Encode(out)
	}))
	defer srv.Close()
	o := NewOllama(srv.URL, "test-model")
	vecs, err := o.Embed(context.Background(), []string{"a", "b"})
	if err != nil || len(vecs) != 2 {
		t.Fatalf("ollama embed: %v %+v", err, vecs)
	}
	if o.Model() != "ollama:test-model" {
		t.Fatalf("model = %s", o.Model())
	}
}
