package webhook

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"go.uber.org/zap"

	triggerinfra "github.com/sunweilin/anselm/backend/internal/infra/trigger"
)

func cfg(path string) map[string]any { return map[string]any{"path": path, "method": "POST"} }

// TestRegisterUnregisterReRegister_NoPanic: the core R8 invariant — re-registering a path that was
// previously unregistered must NOT panic. The old per-trigger mux.HandleFunc would have hit the
// stdlib "multiple registrations for <pattern>" panic; the single catch-all makes it safe.
//
// TestRegisterUnregisterReRegister_NoPanic：R8 核心不变式——重注册一个已注销过的路径不得 panic。
// 旧的 per-trigger mux.HandleFunc 会触发 stdlib「multiple registrations for <pattern>」panic；
// 单 catch-all 使之安全。
func TestRegisterUnregisterReRegister_NoPanic(t *testing.T) {
	mux := http.NewServeMux()
	l := New(mux, zap.NewNop(), func(string, triggerinfra.Activity) error { return nil })

	if err := l.Register("trg_1", "ws_1", cfg("hook")); err != nil {
		t.Fatalf("first Register: %v", err)
	}
	l.Unregister("trg_1")
	// This is the line that previously panicked the stdlib mux on a duplicate pattern.
	if err := l.Register("trg_1", "ws_1", cfg("hook")); err != nil {
		t.Fatalf("re-Register after Unregister: %v", err)
	}
}

// TestMux_HasSingleStableCatchAll: registering many distinct paths must not grow the mux — exactly
// one route (the catch-all prefix) is ever mounted, regardless of how many triggers/paths churn.
//
// TestMux_HasSingleStableCatchAll：注册多个不同路径不得撑大 mux——无论多少 trigger/path 翻动，只挂一条路由（catch-all 前缀）。
func TestMux_HasSingleStableCatchAll(t *testing.T) {
	mux := http.NewServeMux()
	l := New(mux, zap.NewNop(), func(string, triggerinfra.Activity) error { return nil })

	// The catch-all is mounted in New: a request under the prefix with no registry entry 404s
	// (route exists, registry miss), proving the route is present and stable.
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/trg_x/never", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("unregistered path under catch-all should 404, got %d", rec.Code)
	}

	// Churn many distinct paths; each must register cleanly (no duplicate-pattern panic), because
	// none of them touches the mux at all — only the registry map.
	for _, p := range []string{"a", "b", "c/d", "e"} {
		if err := l.Register("trg_"+p, "ws_1", cfg(p)); err != nil {
			t.Fatalf("Register %q: %v", p, err)
		}
	}
	// Re-registering New on the SAME mux would panic if the prefix were already taken twice; a
	// second New here would, so instead we assert the prefix is claimed exactly once by routing
	// a fresh unregistered request again (still 404 — route present, not duplicated/removed).
	rec2 := httptest.NewRecorder()
	mux.ServeHTTP(rec2, httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/trg_y/none", nil))
	if rec2.Code != http.StatusNotFound {
		t.Fatalf("catch-all should still 404 a miss after churn, got %d", rec2.Code)
	}
}

// TestDispatch_HitsRightRegistryEntry: a POST to a registered path reaches its registration (202 +
// fires the right triggerID); an unregistered sibling under the same prefix 404s.
//
// TestDispatch_HitsRightRegistryEntry：POST 到已注册路径命中其 registration（202 + fire 正确 triggerID）；
// 同前缀下未注册的兄弟路径 404。
func TestDispatch_HitsRightRegistryEntry(t *testing.T) {
	mux := http.NewServeMux()
	var firedMu sync.Mutex
	var fired []string
	firedList := func() []string {
		firedMu.Lock()
		defer firedMu.Unlock()
		return append([]string(nil), fired...)
	}
	// The report is synchronous through the durable-ack boundary; the mutex keeps this helper safe
	// if the listener implementation changes its dispatch strategy again.
	// report 在 durable ACK 边界前同步完成；保留 mutex，使 listener 将来改变派发策略时 helper 仍安全。
	l := New(mux, zap.NewNop(), func(triggerID string, a triggerinfra.Activity) error {
		if a.Fired {
			firedMu.Lock()
			fired = append(fired, triggerID)
			firedMu.Unlock()
		}
		return nil
	})
	if err := l.Register("trg_a", "ws_1", cfg("alpha")); err != nil {
		t.Fatalf("Register a: %v", err)
	}
	if err := l.Register("trg_b", "ws_1", cfg("beta")); err != nil {
		t.Fatalf("Register b: %v", err)
	}

	// Hit trg_a's path → 202 accepted, dispatched to trg_a.
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, webhookFullPath("trg_a", "alpha"), strings.NewReader(`{}`)))
	if rec.Code != http.StatusAccepted {
		t.Fatalf("registered path should 202, got %d", rec.Code)
	}
	if len(firedList()) != 1 {
		t.Fatalf("report must finish before 202, got %v", firedList())
	}
	if got := firedList(); got[0] != "trg_a" {
		t.Fatalf("dispatched to %q, want trg_a", got[0])
	}

	// Unregister trg_a → its path now 404s via registry miss, the catch-all route untouched.
	l.Unregister("trg_a")
	rec2 := httptest.NewRecorder()
	mux.ServeHTTP(rec2, httptest.NewRequest(http.MethodPost, webhookFullPath("trg_a", "alpha"), strings.NewReader(`{}`)))
	if rec2.Code != http.StatusNotFound {
		t.Fatalf("unregistered path should 404, got %d", rec2.Code)
	}

	// trg_b still dispatches correctly after the sibling churned.
	rec3 := httptest.NewRecorder()
	mux.ServeHTTP(rec3, httptest.NewRequest(http.MethodPost, webhookFullPath("trg_b", "beta"), strings.NewReader(`{}`)))
	if rec3.Code != http.StatusAccepted {
		t.Fatalf("trg_b path should still 202, got %d", rec3.Code)
	}
	if len(firedList()) != 2 {
		t.Fatalf("second report must finish before 202, got %v", firedList())
	}
	if got := firedList(); got[1] != "trg_b" {
		t.Fatalf("second dispatch to %q, want trg_b", got[1])
	}
}

// TestDispatch_DoesNotAcknowledgeBeforeReportReturns pins the crash boundary: a webhook 202 is
// an acknowledgement of durable acceptance, not merely receipt by an in-memory goroutine.
//
// TestDispatch_DoesNotAcknowledgeBeforeReportReturns 固定崩溃边界：webhook 的 202 是 durable 接收成功，
// 不是「某个内存 goroutine 已经收到了」的假确认。
func TestDispatch_DoesNotAcknowledgeBeforeReportReturns(t *testing.T) {
	mux := http.NewServeMux()
	reportEntered := make(chan struct{})
	releaseReport := make(chan struct{})
	l := New(mux, zap.NewNop(), func(string, triggerinfra.Activity) error {
		close(reportEntered)
		<-releaseReport
		return nil
	})
	if err := l.Register("trg_blocked", "ws_1", cfg("blocked")); err != nil {
		t.Fatalf("Register: %v", err)
	}

	rec := httptest.NewRecorder()
	done := make(chan struct{})
	go func() {
		mux.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, webhookFullPath("trg_blocked", "blocked"), strings.NewReader(`{}`)))
		close(done)
	}()
	select {
	case <-reportEntered:
	case <-time.After(time.Second):
		t.Fatal("report was not entered")
	}
	select {
	case <-done:
		t.Fatal("webhook acknowledged before report returned")
	case <-time.After(20 * time.Millisecond):
	}
	close(releaseReport)
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("webhook did not acknowledge after report returned")
	}
	if rec.Code != http.StatusAccepted {
		t.Fatalf("successful durable report should return 202, got %d", rec.Code)
	}
}

func waitFor(t *testing.T, cond func() bool) {
	t.Helper()
	for i := 0; i < 500; i++ {
		if cond() {
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatal("condition not met in time")
}
