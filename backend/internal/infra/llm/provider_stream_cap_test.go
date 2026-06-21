package llm

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// TestStream_TotalCapTerminatesNonConvergingStream: round-2 vision lane found a stream that emitted
// events forever without converging — each event reset the idle timer, so idle never fired, and with
// no total wall-clock cap the turn wedged in `streaming` for 15+ min, pinned CPU, and even blocked
// graceful shutdown (orphaning child processes). The non-resetting LLMStreamMaxSec must force-terminate
// such a stream with a clear provider error. Idle stays generous here so ONLY the total cap can stop it.
func TestStream_TotalCapTerminatesNonConvergingStream(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.LLMStreamMaxSec = 1 // tiny total cap
		l.Timeout.LLMIdleSec = 150    // generous idle — the stream never goes idle, it dribbles forever
		return l
	})

	// A server that streams content deltas FOREVER (never [DONE]) until the client disconnects —
	// the pathological "model keeps emitting but never converges" shape.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		fl, _ := w.(http.Flusher)
		for {
			select {
			case <-r.Context().Done():
				return
			default:
			}
			if _, err := io.WriteString(w, "data: {\"choices\":[{\"delta\":{\"content\":\"x\"}}]}\n\n"); err != nil {
				return
			}
			if fl != nil {
				fl.Flush()
			}
			time.Sleep(5 * time.Millisecond)
		}
	}))
	defer srv.Close()

	pc := &providerClient{provider: newOpenAIProvider(), http: srv.Client()}
	start := time.Now()
	var gotErr error
	for ev := range pc.Stream(context.Background(), Request{BaseURL: srv.URL, Key: "test", ModelID: "m", Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}}}) {
		if ev.Type == EventError {
			gotErr = ev.Err
			break
		}
	}
	elapsed := time.Since(start)

	if gotErr == nil {
		t.Fatal("expected a terminal EventError from the total cap — the stream never terminated (the bug)")
	}
	if !errors.Is(gotErr, ErrProviderError) {
		t.Errorf("total-cap error must be ErrProviderError, got: %v", gotErr)
	}
	if !strings.Contains(gotErr.Error(), "total budget") {
		t.Errorf("expected a 'total budget' provider error, got: %v", gotErr)
	}
	if elapsed > 5*time.Second {
		t.Errorf("the 1s total cap should have fired quickly, took %v (idle reset must not have prevented it)", elapsed)
	}
}

// TestStream_TotalCapAbortsWedgedRead pins the F152 verdict: unlike the dribbling server above (bytes
// every 5ms, so scanner.Scan returns between them and the loop re-checks ctx), this server sends the
// response HEADERS then NO body bytes and never closes — the client's body Read WEDGES inside a single
// blocking Scan(). VERDICT (this test + the HTTP/2 sibling): when the total cap fires cancel(streamCtx),
// net/http aborts the wedged Read PROMPTLY (~within the cap, both h1 and h2). So the provider's
// cancellation is self-sufficient — a "force-close the body" change is NOT needed; F152's observed ~5min
// tail (35m vs the 30m bound) is NOT a cancel-honoring bug here and needs live repro of the real
// free-tier gateway + the run's actual effective limits. This is a regression guard for that invariant.
func TestStream_TotalCapAbortsWedgedRead(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.LLMStreamMaxSec = 1 // tiny total cap
		l.Timeout.LLMIdleSec = 150    // generous idle — only the total cap can stop a wedged (non-dribbling) read
		return l
	})

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		if fl, ok := w.(http.Flusher); ok {
			fl.Flush() // deliver 200 + headers so the client enters the body read...
		}
		<-r.Context().Done() // ...then send NO body bytes and hold the connection open (half-open gateway)
	}))
	defer srv.Close()

	pc := &providerClient{provider: newOpenAIProvider(), http: srv.Client()}
	start := time.Now()
	var gotErr error
	for ev := range pc.Stream(context.Background(), Request{BaseURL: srv.URL, Key: "test", ModelID: "m", Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}}}) {
		if ev.Type == EventError {
			gotErr = ev.Err
			break
		}
	}
	elapsed := time.Since(start)

	if gotErr == nil {
		t.Fatal("a wedged stream must terminate via the total cap")
	}
	if elapsed > 5*time.Second {
		t.Fatalf("the 1s total cap did NOT promptly abort a WEDGED body read: took %v — cancel(streamCtx) does not interrupt the blocked Read; a force-close is needed (F152/F101)", elapsed)
	}
	t.Logf("wedged read aborted %v after the 1s total cap fired", elapsed)
}

// TestStream_TotalCapAbortsWedgedRead_HTTP2 repeats the wedged-read decider over HTTP/2 (the free-tier
// gateway / DeepSeek likely negotiate h2, and h2 stream cancellation — RST_STREAM over a shared conn —
// behaves differently from h1 closing the TCP conn). If the cap aborts the wedged h2 read promptly too,
// the force-close (B) is unnecessary and F152's tail is config/gateway-specific (live repro). If h2
// hangs past the cap, a force-close IS needed for h2.
func TestStream_TotalCapAbortsWedgedRead_HTTP2(t *testing.T) {
	defer limitspkg.SetProvider(limitspkg.Default)
	limitspkg.SetProvider(func() limitspkg.Limits {
		l := limitspkg.Default()
		l.Timeout.LLMStreamMaxSec = 1
		l.Timeout.LLMIdleSec = 150
		return l
	})

	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.WriteHeader(http.StatusOK)
		if fl, ok := w.(http.Flusher); ok {
			fl.Flush()
		}
		<-r.Context().Done()
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	defer srv.Close()

	client := srv.Client()
	if client.Transport.(*http.Transport).TLSClientConfig == nil {
		t.Skip("h2 client not configured")
	}
	pc := &providerClient{provider: newOpenAIProvider(), http: client}
	start := time.Now()
	var gotErr error
	for ev := range pc.Stream(context.Background(), Request{BaseURL: srv.URL, Key: "test", ModelID: "m", Messages: []LLMMessage{{Role: RoleUser, Content: "hi"}}}) {
		if ev.Type == EventError {
			gotErr = ev.Err
			break
		}
	}
	elapsed := time.Since(start)
	if gotErr == nil {
		t.Fatal("a wedged h2 stream must terminate via the total cap")
	}
	if elapsed > 5*time.Second {
		t.Fatalf("the 1s total cap did NOT promptly abort a WEDGED HTTP/2 body read: took %v — h2 cancel does not interrupt the Read; a force-close is needed (F152/F101)", elapsed)
	}
	t.Logf("wedged HTTP/2 read aborted %v after the 1s total cap fired (proto negotiated h2)", elapsed)
}
