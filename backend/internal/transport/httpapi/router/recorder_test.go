package router

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRecorder_RecordsHandleFunc(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	rec.HandleFunc("GET /api/v1/health", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("POST /api/v1/conversations", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("/api/v1/forge", func(w http.ResponseWriter, r *http.Request) {}) // no method = ANY

	routes := rec.List()
	want := []Route{
		{Method: "GET", Path: "/api/v1/health"},
		{Method: "POST", Path: "/api/v1/conversations"},
		{Method: "ANY", Path: "/api/v1/forge"},
	}
	if len(routes) != len(want) {
		t.Fatalf("want %d routes, got %d", len(want), len(routes))
	}
	for _, w := range want {
		found := false
		for _, r := range routes {
			if r.Method == w.Method && r.Path == w.Path {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("expected route %s %s not found in %+v", w.Method, w.Path, routes)
		}
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
	mux.ServeHTTP(httptest.NewRecorder(), req)
	if !called {
		t.Error("handler not called through underlying mux")
	}
}

func TestRecorder_HandleAlsoRecords(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	rec.Handle("DELETE /api/v1/things/{id}", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	routes := rec.List()
	if len(routes) != 1 || routes[0].Method != "DELETE" || routes[0].Path != "/api/v1/things/{id}" {
		t.Errorf("want [DELETE /api/v1/things/{id}], got %+v", routes)
	}
}

func TestRecorder_ListReturnsSnapshot(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	rec.HandleFunc("GET /one", func(w http.ResponseWriter, r *http.Request) {})
	snap := rec.List()
	rec.HandleFunc("GET /two", func(w http.ResponseWriter, r *http.Request) {})
	if len(snap) != 1 {
		t.Errorf("snapshot should still be 1 after a later registration, got %d", len(snap))
	}
}
