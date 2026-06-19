package bootstrap

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"go.uber.org/zap"
)

// TestRegisterDebug_DevOnly: dev mounts /debug/stats (a runtime snapshot) + pprof; non-dev mounts
// nothing (the endpoints must not exist when ANSELM_DEV is off).
func TestRegisterDebug_DevOnly(t *testing.T) {
	mux := http.NewServeMux()
	registerDebug(mux, true, zap.NewNop())

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest("GET", "/debug/stats", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("dev /debug/stats: code %d", rec.Code)
	}
	var stats map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &stats); err != nil {
		t.Fatalf("stats not json: %v", err)
	}
	if _, ok := stats["goroutines"]; !ok {
		t.Fatalf("stats missing goroutines: %v", stats)
	}

	rec2 := httptest.NewRecorder()
	mux.ServeHTTP(rec2, httptest.NewRequest("GET", "/debug/pprof/", nil))
	if rec2.Code != http.StatusOK {
		t.Fatalf("dev /debug/pprof/: code %d", rec2.Code)
	}

	prod := http.NewServeMux()
	registerDebug(prod, false, zap.NewNop())
	rec3 := httptest.NewRecorder()
	prod.ServeHTTP(rec3, httptest.NewRequest("GET", "/debug/stats", nil))
	if rec3.Code != http.StatusNotFound {
		t.Fatalf("non-dev /debug/stats should be 404, got %d", rec3.Code)
	}
}
