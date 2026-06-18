package llm

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestClassifyHTTPError(t *testing.T) {
	cases := []struct {
		status int
		want   error
	}{
		{http.StatusUnauthorized, ErrAuthFailed},
		{http.StatusForbidden, ErrAuthFailed},
		{http.StatusTooManyRequests, ErrRateLimited},
		{http.StatusBadRequest, ErrBadRequest},
		{http.StatusNotFound, ErrModelNotFound},
		{http.StatusInternalServerError, ErrProviderError},
		{http.StatusServiceUnavailable, ErrProviderError},
	}
	for _, c := range cases {
		err := classifyHTTPError(c.status, []byte("upstream said no"))
		if !errors.Is(err, c.want) {
			t.Errorf("status %d → %v, want sentinel %v", c.status, err, c.want)
		}
	}
}

func TestScanSSELines(t *testing.T) {
	r := strings.NewReader(
		"data: {\"a\":1}\n\n" +
			": this is a comment\n\n" +
			"event: ping\n\n" +
			"data: {\"b\":2}\n\n" +
			"data: [DONE]\n\n" +
			"data: {\"c\":3}\n\n", // after [DONE] — must be ignored
	)
	var got []string
	err := scanSSELines(context.Background(), r, func(p []byte) bool {
		got = append(got, string(p))
		return true
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0] != `{"a":1}` || got[1] != `{"b":2}` {
		t.Errorf("scanSSELines yielded %v, want [{a:1} {b:2}]", got)
	}
}

func TestScanSSELinesEarlyStop(t *testing.T) {
	r := strings.NewReader("data: 1\n\ndata: 2\n\ndata: 3\n\n")
	var got []string
	_ = scanSSELines(context.Background(), r, func(p []byte) bool {
		got = append(got, string(p))
		return len(got) < 2 // stop after 2
	})
	if len(got) != 2 {
		t.Errorf("early stop yielded %d, want 2", len(got))
	}
}

// keepAliveReader emits SSE comment/keep-alive lines forever and never EOFs — the shape of an
// upstream that holds the connection open while "thinking" without sending a data: token.
type keepAliveReader struct{}

func (keepAliveReader) Read(p []byte) (int, error) { return copy(p, []byte(": keep-alive\n")), nil }

// TestScanSSELines_CtxCancelBreaksKeepAliveDribble — F33/F12: a stream that only dribbles keep-alive
// comment lines (never a data: line) must NOT trap scanSSELines once ctx is cancelled. Before the
// fix, fn (where ctx was checked) was never called for comment lines, so the idle-timer's cancel
// could not land and the turn hung forever in `streaming`. Now the scan loop itself honours ctx.
func TestScanSSELines_CtxCancelBreaksKeepAliveDribble(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // the idle timer (or a user stop) has fired
	done := make(chan error, 1)
	go func() { done <- scanSSELines(ctx, keepAliveReader{}, func([]byte) bool { return true }) }()
	select {
	case err := <-done:
		if err == nil {
			t.Fatal("scanSSELines on a cancelled ctx must return its ctx error, got nil")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("scanSSELines hung on a keep-alive stream with a cancelled ctx (F33 regression)")
	}
}
