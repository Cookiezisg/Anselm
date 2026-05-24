package router

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func newTestDeps() Deps {
	return Deps{Log: zap.NewNop()}
}

func TestRouter_HealthEndpointReturnsEnvelope(t *testing.T) {
	h := New(newTestDeps())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/health", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d, want 200", rec.Code)
	}

	var env struct {
		Data struct {
			Status string `json:"status"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatalf("response not JSON: %v", err)
	}
	if env.Data.Status != "ok" {
		t.Errorf("status: got %q, want ok", env.Data.Status)
	}
}

func TestRouter_UnknownPathReturnsEnvelope404(t *testing.T) {
	h := New(newTestDeps())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/totally-nonexistent", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status: got %d, want 404", rec.Code)
	}
	if strings.Contains(rec.Body.String(), "404 page not found") {
		t.Errorf("leaked Go's default 404 body: %s", rec.Body.String())
	}
	var env struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatalf("body not JSON: %v", err)
	}
	if env.Error.Code != "NOT_FOUND" {
		t.Errorf("error code: got %q, want NOT_FOUND", env.Error.Code)
	}
}

func TestRouter_CORSPreflightWorks(t *testing.T) {
	h := New(newTestDeps())
	req := httptest.NewRequest("OPTIONS", "/api/v1/health", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	req.Header.Set("Access-Control-Request-Method", "GET")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("preflight status: got %d, want 204", rec.Code)
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5173" {
		t.Errorf("CORS middleware not wired: missing Allow-Origin")
	}
}

func TestRouter_CORSHeaderPresentOnHealthRequest(t *testing.T) {
	h := New(newTestDeps())
	req := httptest.NewRequest("GET", "/api/v1/health", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status: got %d, want 200", rec.Code)
	}
	if rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5173" {
		t.Errorf("missing Allow-Origin on passed-through request")
	}
}

func TestRouter_NoHeader_NonExemptPath_Returns401(t *testing.T) {
	// With UserService nil and no X-Forgify-User-ID header, /api/v1/* must
	// 401 (UNAUTH_NO_USER) — no silent fallback.
	called := false
	testHandler := http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		called = true
	})
	h := applyChain(testHandler, newTestDeps())
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/api/v1/conversations", nil))

	if called {
		t.Error("inner handler should NOT run when no user identified")
	}
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "UNAUTH_NO_USER") {
		t.Errorf("missing UNAUTH_NO_USER code; got %s", rec.Body.String())
	}
}

func TestRouter_HeaderPresent_StampsCtx(t *testing.T) {
	// With UserService nil, IdentifyUser accepts the header verbatim
	// (no validation). RequireUser then sees a user in ctx and passes through.
	var gotID string
	testHandler := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotID, _ = reqctxpkg.GetUserID(r.Context())
	})
	h := applyChain(testHandler, newTestDeps())
	req := httptest.NewRequest("GET", "/api/v1/conversations", nil)
	req.Header.Set("X-Forgify-User-ID", "u_real")
	h.ServeHTTP(httptest.NewRecorder(), req)

	if gotID != "u_real" {
		t.Errorf("userID = %q, want u_real", gotID)
	}
}

func TestRouter_UsersCRUD_ExemptFromRequireUser(t *testing.T) {
	// /api/v1/users must work pre-onboarding — onboarding calls POST /users
	// before any user exists.
	called := false
	testHandler := http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		called = true
	})
	h := applyChain(testHandler, newTestDeps())
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/api/v1/users", nil))

	if !called {
		t.Error("/api/v1/users should bypass RequireUser even without a user header")
	}
}

func TestRouter_Health_ExemptFromRequireUser(t *testing.T) {
	called := false
	testHandler := http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		called = true
	})
	h := applyChain(testHandler, newTestDeps())
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/api/v1/health", nil))

	if !called {
		t.Error("/api/v1/health should bypass RequireUser")
	}
}

func TestRouter_LocaleInjectedIntoHandlerContext(t *testing.T) {
	var gotLocale reqctxpkg.Locale
	testHandler := http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotLocale = reqctxpkg.GetLocale(r.Context())
	})

	h := applyChain(testHandler, newTestDeps())
	req := httptest.NewRequest("GET", "/anything", nil)
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	h.ServeHTTP(httptest.NewRecorder(), req)

	if gotLocale != reqctxpkg.LocaleEn {
		t.Errorf("locale: got %q, want %q", gotLocale, reqctxpkg.LocaleEn)
	}
}
