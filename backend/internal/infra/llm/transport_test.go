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

func TestClassifyHTTPError_GatewayContextReasonIsTyped(t *testing.T) {
	err := classifyHTTPError(http.StatusBadRequest, []byte(`{"error":{"code":"UPSTREAM_REJECTED","message":"safe","details":{"reason":"context_length"}}}`))
	if !IsContextLengthError(err) {
		t.Fatalf("gateway context rejection lost typed reason: %T %v", err, err)
	}
	if strings.Contains(err.Error(), "safe") {
		t.Fatalf("provider/gateway message leaked through typed rejection: %v", err)
	}
}

func TestClassifyHTTPError_NeverLeaksProviderBodyWhenUnclassified(t *testing.T) {
	secretEcho := `{"error":{"message":"request contained sk-super-secret and private prompt text"}}`
	for _, status := range []int{http.StatusBadRequest, http.StatusUnauthorized, http.StatusInternalServerError} {
		err := classifyHTTPError(status, []byte(secretEcho))
		if strings.Contains(err.Error(), "sk-super-secret") || strings.Contains(err.Error(), "private prompt text") {
			t.Fatalf("status %d leaked provider body: %v", status, err)
		}
	}
}

func TestClassifyHTTPError_RequestBodyTooLargeIsNotContext(t *testing.T) {
	err := classifyHTTPError(http.StatusRequestEntityTooLarge, []byte(`{"error":{"code":"REQUEST_BODY_TOO_LARGE","message":"request body exceeds the configured size limit"}}`))
	if IsContextLengthError(err) {
		t.Fatalf("transport body cap was misclassified as model context: %v", err)
	}
	var rejected *RequestRejectedError
	if !errors.As(err, &rejected) || rejected.Reason != RejectionRequestBodyTooLarge {
		t.Fatalf("body cap reason = %T %v", err, err)
	}
}

func TestStreamProviderError_RecognizesContextWithoutLeakingProviderText(t *testing.T) {
	err := streamProviderError("", "input too large: sk-super-secret and private prompt text")
	if !IsContextLengthError(err) {
		t.Fatalf("stream context rejection lost typed reason: %T %v", err, err)
	}
	if strings.Contains(err.Error(), "sk-super-secret") || strings.Contains(err.Error(), "private prompt text") {
		t.Fatalf("stream provider text leaked through typed rejection: %v", err)
	}

	err = streamProviderError("", "arbitrary upstream failure with sk-super-secret")
	if !errors.Is(err, ErrProviderError) || strings.Contains(err.Error(), "sk-super-secret") {
		t.Fatalf("unclassified stream error must stay sanitized provider error: %v", err)
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

// 429 carries two opposite meanings on the managed gateway: a transient rate limit (retryable) and
// a depleted monthly allowance (not). Classifying both as ErrRateLimited made an exhausted quota
// burn three retries and then tell the user "too many requests" — the one message that suggests
// waiting will help, when nothing will until the month rolls over.
//
// 受管网关的 429 同时承载两种相反含义:瞬时限流(可重试)与本月额度耗尽(不可)。把两者都归成
// ErrRateLimited,会让配额耗尽白烧三次重试,然后告诉用户「请求太频繁」——偏偏是那句暗示「等等就好」的话,
// 而在跨月之前等多久都没用。
func TestClassifyHTTPError_429SeparatesRateLimitFromExhaustedQuota(t *testing.T) {
	cases := []struct {
		name string
		body string
		want error
	}{
		{"transient rate limit", `{"error":{"code":"RATE_LIMITED"}}`, ErrRateLimited},
		{"upstream busy", `{"error":{"code":"UPSTREAM_BUSY"}}`, ErrRateLimited},
		{"monthly quota gone", `{"error":{"code":"QUOTA_EXHAUSTED"}}`, ErrQuotaExhausted},
		{"install cap reached", `{"error":{"code":"INSTALL_CAP_REACHED"}}`, ErrQuotaExhausted},
		// An unknown code must keep the status's default meaning: a new gateway code silently
		// becoming non-retryable would be its own bug. 未知码保留状态码默认含义。
		{"unknown code", `{"error":{"code":"SOMETHING_NEW"}}`, ErrRateLimited},
		{"unparseable body", `not json`, ErrRateLimited},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := classifyHTTPError(429, []byte(tc.body))
			if !errors.Is(err, tc.want) {
				t.Fatalf("classify(429, %s) = %v, want %v", tc.body, err, tc.want)
			}
		})
	}

	// The retry policy is the thing that actually differs; assert it, not just the sentinel.
	// 真正有区别的是重试策略;断言它,而不只是断言哨兵值。
	if isRetryable(classifyHTTPError(429, []byte(`{"error":{"code":"QUOTA_EXHAUSTED"}}`))) {
		t.Fatal("an exhausted allowance must not be retried")
	}
	if !isRetryable(classifyHTTPError(429, []byte(`{"error":{"code":"RATE_LIMITED"}}`))) {
		t.Fatal("a transient rate limit must stay retryable")
	}
}
