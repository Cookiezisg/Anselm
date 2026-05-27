package router

import (
	"net/http"
	"testing"
)

func TestRecorder_RecordsHandleFunc(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	rec.HandleFunc("GET /api/v1/health", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("POST /api/v1/conversations", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("/api/v1/forge", func(w http.ResponseWriter, r *http.Request) {}) // no method = ANY

	routes := rec.List()
	if len(routes) != 3 {
		t.Fatalf("want 3 routes, got %d", len(routes))
	}
	if routes[0].Method != "GET" || routes[0].Path != "/api/v1/health" {
		t.Errorf("route 0: want GET /api/v1/health, got %s %s", routes[0].Method, routes[0].Path)
	}
	if routes[2].Method != "ANY" || routes[2].Path != "/api/v1/forge" {
		t.Errorf("route 2: want ANY /api/v1/forge, got %s %s", routes[2].Method, routes[2].Path)
	}
}

func TestRecorder_PassthroughToMux(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	called := false
	rec.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		called = true
	})

	req, _ := http.NewRequest("GET", "/ping", nil)
	mux.ServeHTTP(&noopResponseWriter{}, req)
	if !called {
		t.Error("handler not called through underlying mux")
	}
}

type noopResponseWriter struct{ h http.Header }

func (n *noopResponseWriter) Header() http.Header {
	if n.h == nil {
		n.h = http.Header{}
	}
	return n.h
}
func (n *noopResponseWriter) Write(b []byte) (int, error) { return len(b), nil }
func (n *noopResponseWriter) WriteHeader(int)             {}
