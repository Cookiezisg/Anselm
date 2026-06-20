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
