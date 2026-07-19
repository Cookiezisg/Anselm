package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"go.uber.org/zap"
)

// TestRecover_PanicBecomesInternalError — C-err-7: a handler panic must be caught and
// rendered as a 500 INTERNAL_ERROR N1 envelope. The response must NOT leak the panic value
// or a stack frame (those go to the log only) — otherwise an attacker learns internals.
//
// TestRecover_PanicBecomesInternalError — C-err-7：handler panic 须被捕获、渲染成 500 INTERNAL_ERROR
// N1 envelope。响应绝不泄露 panic 值 / 栈帧（那些只进日志）——否则攻击者窥得内部。
func TestRecover_PanicBecomesInternalError(t *testing.T) {
	const secret = "super-secret-panic-detail-do-not-leak"
	panicking := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic(secret)
	})
	h := Recover(zap.NewNop())(panicking)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
	w := httptest.NewRecorder()

	h.ServeHTTP(w, r) // must not propagate the panic out of ServeHTTP

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("panic status = %d, want 500", w.Code)
	}
	body := w.Body.String()
	if !strings.Contains(body, "INTERNAL_ERROR") {
		t.Fatalf("body must carry the INTERNAL_ERROR wire code (N1 envelope), got %s", body)
	}
	if strings.Contains(body, secret) {
		t.Fatalf("panic detail leaked into the response body: %s", body)
	}
	if strings.Contains(strings.ToLower(body), "goroutine") || strings.Contains(body, ".go:") {
		t.Fatalf("stack trace leaked into the response body: %s", body)
	}
}

// TestRecover_PassesThroughWhenNoPanic — C-err-7: the middleware is transparent on the
// happy path — a normal handler's status + body reach the client untouched.
//
// TestRecover_PassesThroughWhenNoPanic — C-err-7：无 panic 时中间件透明——正常 handler 的状态 + body
// 原样抵达客户端。
func TestRecover_PassesThroughWhenNoPanic(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
		_, _ = w.Write([]byte("brewed"))
	})
	h := Recover(zap.NewNop())(ok)
	r := httptest.NewRequest(http.MethodGet, "/api/v1/functions", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if w.Code != http.StatusTeapot {
		t.Fatalf("passthrough status = %d, want 418", w.Code)
	}
	if w.Body.String() != "brewed" {
		t.Fatalf("passthrough body = %q, want %q", w.Body.String(), "brewed")
	}
}

// TestRecover_NilPanicValueDoesNotFabricate500 — C-err-7: recover() also returns non-nil
// for a panic(nil) in some runtimes; a genuine no-panic path (rec == nil) must leave the
// response as-is. Guards the `if rec == nil { return }` early-out.
//
// TestRecover_NilPanicValueDoesNotFabricate500 — C-err-7：真正无 panic 路径（rec == nil）须原样放行、
// 不无中生有造 500。守 `if rec == nil { return }` 早退。
func TestRecover_NilPanicValueDoesNotFabricate500(t *testing.T) {
	noop := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	h := Recover(zap.NewNop())(noop)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(http.MethodGet, "/x", nil))

	if w.Code != http.StatusNoContent {
		t.Fatalf("no-panic path status = %d, want 204 (recover must not fabricate a 500)", w.Code)
	}
}
