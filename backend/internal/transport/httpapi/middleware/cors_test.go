package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// corsNext returns a terminal handler + a flag recording whether the request reached it.
//
// corsNext 返回一个终端 handler 及记录请求是否抵达它的标志位。
func corsNext() (http.Handler, *bool) {
	called := false
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})
	return h, &called
}

// TestCORS_WhitelistedOriginGetsACAO — C-sec-8: a whitelisted browser origin (the dev
// server ports) must receive Access-Control-Allow-Origin echoing the exact origin plus
// Vary:Origin (so caches key on origin), and the request must still reach next.
//
// TestCORS_WhitelistedOriginGetsACAO — C-sec-8：白名单浏览器 origin（dev 端口）须收到回显精确
// origin 的 ACAO + Vary:Origin（让缓存按 origin 分键），且请求仍抵达 next。
func TestCORS_WhitelistedOriginGetsACAO(t *testing.T) {
	for _, origin := range []string{
		"http://localhost:5173",
		"http://localhost:3000",
		"http://127.0.0.1:5173",
		"http://127.0.0.1:3000",
	} {
		next, called := corsNext()
		h := CORS(DefaultCORSConfig())(next)
		r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
		r.Header.Set("Origin", origin)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if got := w.Header().Get("Access-Control-Allow-Origin"); got != origin {
			t.Fatalf("origin %q: ACAO = %q, want exact echo", origin, got)
		}
		if vary := w.Header().Get("Vary"); !strings.Contains(vary, "Origin") {
			t.Fatalf("origin %q: Vary = %q, want to contain Origin", origin, vary)
		}
		if !*called {
			t.Fatalf("origin %q: a simple (non-preflight) request must still reach next", origin)
		}
	}
}

// TestCORS_NonWhitelistedOriginNoACAO — C-sec-8: an origin outside the strict whitelist
// (no "*") must NOT get an ACAO header — the browser then blocks the response — yet the
// request still passes through (CORS is advisory response headers, not a server-side gate).
//
// TestCORS_NonWhitelistedOriginNoACAO — C-sec-8：白名单外 origin（无 "*"）绝不加 ACAO——浏览器随后
// 拦截响应——但请求仍透传（CORS 是建议性响应头，不是服务端门）。
func TestCORS_NonWhitelistedOriginNoACAO(t *testing.T) {
	for _, origin := range []string{
		"http://evil.example.com",
		"https://localhost:5173", // scheme mismatch — https not whitelisted
		"http://localhost:9999",  // wrong port
		"http://localhost",       // no port
		"null",
	} {
		next, called := corsNext()
		h := CORS(DefaultCORSConfig())(next)
		r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
		r.Header.Set("Origin", origin)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
			t.Fatalf("non-whitelisted origin %q must not get ACAO, got %q", origin, got)
		}
		if !*called {
			t.Fatalf("origin %q: request must still pass through", origin)
		}
	}
}

// TestCORS_NoOriginPassesThrough — C-sec-8: a same-origin / non-browser request (no Origin
// header) is a direct passthrough with no CORS headers added.
//
// TestCORS_NoOriginPassesThrough — C-sec-8：同源 / 非浏览器请求（无 Origin 头）直通、不加任何 CORS 头。
func TestCORS_NoOriginPassesThrough(t *testing.T) {
	next, called := corsNext()
	h := CORS(DefaultCORSConfig())(next)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil) // no Origin
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if !*called {
		t.Fatal("no-Origin request must pass through to next")
	}
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("no-Origin request must not get ACAO, got %q", got)
	}
	if got := w.Header().Get("Vary"); got != "" {
		t.Fatalf("no-Origin request must not get Vary, got %q", got)
	}
}

// TestCORS_PreflightReturns204WithHeaders — C-sec-8: a whitelisted preflight (OPTIONS +
// Access-Control-Request-Method) short-circuits with 204 and carries Allow-Methods,
// Allow-Headers, and Max-Age — and does NOT reach next (preflight is answered by the mw).
//
// TestCORS_PreflightReturns204WithHeaders — C-sec-8：白名单 preflight（OPTIONS + ACRM）短路返 204，
// 带 Allow-Methods / Allow-Headers / Max-Age，且不抵达 next（preflight 由中间件应答）。
func TestCORS_PreflightReturns204WithHeaders(t *testing.T) {
	next, called := corsNext()
	h := CORS(DefaultCORSConfig())(next)
	r := httptest.NewRequest(http.MethodOptions, "/api/v1/functions", nil)
	r.Header.Set("Origin", "http://localhost:5173")
	r.Header.Set("Access-Control-Request-Method", "POST")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if w.Code != http.StatusNoContent {
		t.Fatalf("preflight status = %d, want 204", w.Code)
	}
	if *called {
		t.Fatal("preflight must be answered by the middleware, not reach next")
	}
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5173" {
		t.Fatalf("preflight ACAO = %q, want echo", got)
	}
	if m := w.Header().Get("Access-Control-Allow-Methods"); !strings.Contains(m, "POST") || !strings.Contains(m, "OPTIONS") {
		t.Fatalf("preflight Allow-Methods = %q, want to include POST + OPTIONS", m)
	}
	if hd := w.Header().Get("Access-Control-Allow-Headers"); !strings.Contains(hd, "Content-Type") || !strings.Contains(hd, HeaderWorkspaceID) {
		t.Fatalf("preflight Allow-Headers = %q, want Content-Type + %s", hd, HeaderWorkspaceID)
	}
	if age := w.Header().Get("Access-Control-Max-Age"); age != "86400" { // 24h
		t.Fatalf("preflight Max-Age = %q, want 86400 (24h)", age)
	}
}

// TestCORS_PreflightFromNonWhitelistedOriginFallsThrough — C-sec-8: an OPTIONS preflight
// from an un-whitelisted origin is NOT short-circuited (origin gate rejects before the
// preflight branch) — no ACAO, passes to next.
//
// TestCORS_PreflightFromNonWhitelistedOriginFallsThrough — C-sec-8：非白名单 origin 的 OPTIONS
// preflight 不被短路（origin 门先于 preflight 分支拒绝）——无 ACAO，透传 next。
func TestCORS_PreflightFromNonWhitelistedOriginFallsThrough(t *testing.T) {
	next, called := corsNext()
	h := CORS(DefaultCORSConfig())(next)
	r := httptest.NewRequest(http.MethodOptions, "/api/v1/functions", nil)
	r.Header.Set("Origin", "http://evil.example.com")
	r.Header.Set("Access-Control-Request-Method", "POST")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("non-whitelisted preflight must not get ACAO, got %q", got)
	}
	if !*called {
		t.Fatal("non-whitelisted OPTIONS must fall through to next (not answered as preflight)")
	}
}

// TestCORS_WhitelistedOptionsWithoutRequestMethodIsNotPreflight — C-sec-8: a bare OPTIONS
// (no Access-Control-Request-Method) from a whitelisted origin is a real request, not a
// preflight: it gets ACAO but is NOT short-circuited to 204 — it reaches next.
//
// TestCORS_WhitelistedOptionsWithoutRequestMethodIsNotPreflight — C-sec-8：白名单 origin 的裸 OPTIONS
// （无 ACRM）是真请求非 preflight：得 ACAO 但不短路成 204——抵达 next。
func TestCORS_WhitelistedOptionsWithoutRequestMethodIsNotPreflight(t *testing.T) {
	next, called := corsNext()
	h := CORS(DefaultCORSConfig())(next)
	r := httptest.NewRequest(http.MethodOptions, "/api/v1/functions", nil)
	r.Header.Set("Origin", "http://localhost:5173") // no Access-Control-Request-Method
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5173" {
		t.Fatalf("bare OPTIONS from whitelisted origin should still get ACAO, got %q", got)
	}
	if w.Header().Get("Access-Control-Allow-Methods") != "" {
		t.Fatal("bare OPTIONS is not a preflight — must not carry Allow-Methods")
	}
	if !*called {
		t.Fatal("bare OPTIONS (no ACRM) must reach next, not be answered as preflight")
	}
}
