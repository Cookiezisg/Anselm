package llm

import (
	"errors"
	"net/http"
	"strings"
	"testing"
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
	err := scanSSELines(r, func(p []byte) bool {
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
	_ = scanSSELines(r, func(p []byte) bool {
		got = append(got, string(p))
		return len(got) < 2 // stop after 2
	})
	if len(got) != 2 {
		t.Errorf("early stop yielded %d, want 2", len(got))
	}
}
