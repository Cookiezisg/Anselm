package engine

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
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
