package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	userdomain "github.com/sunweilin/forgify/backend/internal/domain/user"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// fakeResolver — in-memory UserResolver for auth-middleware unit tests.
//
// fakeResolver:auth middleware 单测用的内存 UserResolver。
type fakeResolver struct {
	users map[string]*userdomain.User
}

func (r *fakeResolver) Get(_ context.Context, id string) (*userdomain.User, error) {
	if u, ok := r.users[id]; ok {
		return u, nil
	}
	return nil, errors.New("not found")
}

// ── IdentifyUser ─────────────────────────────────────────────────────────

func TestIdentifyUser_HeaderPresent_StampsCtx(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_alice": {ID: "u_alice"},
	}}
	var gotID string
	var gotOK bool
	handler := IdentifyUser(resolver)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotID, gotOK = reqctxpkg.GetUserID(r.Context())
	}))
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(HeaderUserID, "u_alice")
	handler.ServeHTTP(httptest.NewRecorder(), req)
	if !gotOK || gotID != "u_alice" {
		t.Errorf("ctx user = %q (ok=%v), want %q", gotID, gotOK, "u_alice")
	}
}

func TestIdentifyUser_HeaderMissing_LeavesCtxEmpty(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_alice": {ID: "u_alice"},
	}}
	var gotOK bool
	handler := IdentifyUser(resolver)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		_, gotOK = reqctxpkg.GetUserID(r.Context())
	}))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/x", nil))
	if gotOK {
		t.Error("ctx should NOT have user when header missing (no fallback)")
	}
}

func TestIdentifyUser_UnknownHeader_LeavesCtxEmpty(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_alice": {ID: "u_alice"},
	}}
	var gotOK bool
	handler := IdentifyUser(resolver)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		_, gotOK = reqctxpkg.GetUserID(r.Context())
	}))
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(HeaderUserID, "u_nope")
	handler.ServeHTTP(httptest.NewRecorder(), req)
	if gotOK {
		t.Error("ctx should NOT have user when header refers to unknown id (no demote to first-user)")
	}
}

func TestIdentifyUser_QueryFallback_ForSSE(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_sse": {ID: "u_sse"},
	}}
	var gotID string
	handler := IdentifyUser(resolver)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotID, _ = reqctxpkg.GetUserID(r.Context())
	}))
	// EventSource cannot set custom headers → SSE falls back to ?userID= query.
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/eventlog?userID=u_sse", nil))
	if gotID != "u_sse" {
		t.Errorf("query-param userID not honored: got %q", gotID)
	}
}

func TestIdentifyUser_NilResolver_StampsHeaderWithoutValidation(t *testing.T) {
	// Belt-and-suspenders: if no resolver supplied, IdentifyUser still stamps
	// whatever header was sent. Used by integration/early-boot scenarios.
	var gotID string
	handler := IdentifyUser(nil)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotID, _ = reqctxpkg.GetUserID(r.Context())
	}))
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(HeaderUserID, "u_whatever")
	handler.ServeHTTP(httptest.NewRecorder(), req)
	if gotID != "u_whatever" {
		t.Errorf("nil resolver should accept header verbatim: got %q", gotID)
	}
}

// ── RequireUser ──────────────────────────────────────────────────────────

func TestRequireUser_NoCtxUser_Returns401(t *testing.T) {
	// RequireUser without IdentifyUser running first → ctx has no user → 401.
	called := false
	handler := RequireUser(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		called = true
	}))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))

	if called {
		t.Error("inner handler should NOT be invoked when ctx has no user")
	}
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "UNAUTH_NO_USER") {
		t.Errorf("body should contain UNAUTH_NO_USER code; got %s", rec.Body.String())
	}
}

func TestRequireUser_WithCtxUser_PassesThrough(t *testing.T) {
	called := false
	handler := RequireUser(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusTeapot)
	}))
	req := httptest.NewRequest("GET", "/x", nil)
	req = req.WithContext(reqctxpkg.SetUserID(req.Context(), "u_present"))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if !called {
		t.Error("inner handler should run when ctx has user")
	}
	if rec.Code != http.StatusTeapot {
		t.Errorf("status = %d, want 418", rec.Code)
	}
}

func TestIdentifyUserPlusRequireUser_HappyPath_200(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_real": {ID: "u_real"},
	}}
	called := false
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := reqctxpkg.GetUserID(r.Context())
		if !ok || uid != "u_real" {
			t.Errorf("inner: ctx user = %q ok=%v, want u_real", uid, ok)
		}
		called = true
		w.WriteHeader(http.StatusOK)
	})
	stack := IdentifyUser(resolver)(RequireUser(inner))
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(HeaderUserID, "u_real")
	rec := httptest.NewRecorder()
	stack.ServeHTTP(rec, req)

	if !called {
		t.Error("inner handler should run on happy path")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 200", rec.Code)
	}
}

func TestIdentifyUserPlusRequireUser_StaleHeader_401(t *testing.T) {
	resolver := &fakeResolver{users: map[string]*userdomain.User{
		"u_real": {ID: "u_real"},
	}}
	called := false
	stack := IdentifyUser(resolver)(RequireUser(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		called = true
	})))
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set(HeaderUserID, "u_stale")
	rec := httptest.NewRecorder()
	stack.ServeHTTP(rec, req)

	if called {
		t.Error("inner handler should NOT run with stale id (no first-user demote)")
	}
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", rec.Code)
	}
}

// ── InjectUserID (test-only helper) ──────────────────────────────────────

func TestInjectUserID_StampsFixedTestUser(t *testing.T) {
	var gotID string
	var gotOK bool
	handler := InjectUserID(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
		gotID, gotOK = reqctxpkg.GetUserID(r.Context())
	}))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/x", nil))
	if !gotOK || gotID != "test-user" {
		t.Errorf("ctx user = %q ok=%v, want 'test-user'", gotID, gotOK)
	}
}

func TestInjectUserID_DoesNotAffectResponse(t *testing.T) {
	handler := InjectUserID(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
		_, _ = w.Write([]byte("brew"))
	}))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest("GET", "/x", nil))
	if rec.Code != http.StatusTeapot {
		t.Errorf("status = %d, want 418", rec.Code)
	}
	if rec.Body.String() != "brew" {
		t.Errorf("body = %q, want brew", rec.Body.String())
	}
}
