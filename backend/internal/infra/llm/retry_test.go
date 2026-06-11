package llm

import (
	"context"
	"errors"
	"testing"
)

func TestWithRetryRetriesThenSucceeds(t *testing.T) {
	calls := 0
	out, err := withRetry(context.Background(), func() (string, error) {
		calls++
		if calls < 2 {
			return "", ErrRateLimited
		}
		return "ok", nil
	})
	if err != nil || out != "ok" {
		t.Fatalf("out=%q err=%v", out, err)
	}
	if calls != 2 {
		t.Errorf("calls = %d, want 2 (one retry)", calls)
	}
}

func TestWithRetryNonRetryableStopsImmediately(t *testing.T) {
	calls := 0
	_, err := withRetry(context.Background(), func() (string, error) {
		calls++
		return "", ErrAuthFailed
	})
	if !errors.Is(err, ErrAuthFailed) {
		t.Errorf("err = %v, want ErrAuthFailed", err)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (no retry on auth)", calls)
	}
}

func TestWithRetryExhausts(t *testing.T) {
	calls := 0
	_, err := withRetry(context.Background(), func() (string, error) {
		calls++
		return "", ErrProviderError
	})
	if !errors.Is(err, ErrProviderError) {
		t.Errorf("err = %v, want ErrProviderError", err)
	}
	if calls != retryMaxAttempts {
		t.Errorf("calls = %d, want %d", calls, retryMaxAttempts)
	}
}

func TestWithRetryCtxCancelDuringBackoff(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // already cancelled — backoff sleep returns ctx.Err immediately on attempt 2
	calls := 0
	_, err := withRetry(ctx, func() (string, error) {
		calls++
		return "", ErrRateLimited
	})
	if !errors.Is(err, context.Canceled) {
		t.Errorf("err = %v, want context.Canceled", err)
	}
	if calls != 1 {
		t.Errorf("calls = %d, want 1 (cancel cut backoff before retry)", calls)
	}
}

func TestIsRetryable(t *testing.T) {
	retryable := []error{ErrRateLimited, ErrProviderError, context.DeadlineExceeded}
	for _, e := range retryable {
		if !isRetryable(e) {
			t.Errorf("isRetryable(%v) = false, want true", e)
		}
	}
	notRetryable := []error{ErrAuthFailed, ErrBadRequest, ErrModelNotFound, context.Canceled, nil}
	for _, e := range notRetryable {
		if isRetryable(e) {
			t.Errorf("isRetryable(%v) = true, want false", e)
		}
	}
}
