package approval

import (
	"errors"
	"testing"
	"time"
)

func TestValidateForm(t *testing.T) {
	cases := []struct {
		name, template, timeout, behavior string
		want                              error
	}{
		{"empty template", "", "", "", ErrInvalidTemplate},
		{"whitespace template", "   ", "", "", ErrInvalidTemplate},
		{"ok no timeout", "批准?", "", "", nil},
		{"timeout no behavior", "批准?", "30d", "", ErrInvalidTimeout},
		{"timeout bad behavior", "批准?", "30d", "maybe", ErrInvalidTimeout},
		{"timeout ok reject", "批准?", "30d", "reject", nil},
		{"timeout ok approve", "批准?", "2h", "approve", nil},
		{"timeout bad duration", "批准?", "30x", "reject", ErrInvalidTimeout},
		// F60: an explicitly-set zero-duration timeout would never fire (run parks forever) — reject it.
		{"timeout zero seconds", "批准?", "0s", "reject", ErrInvalidTimeout},
		{"timeout zero ms", "批准?", "0ms", "approve", ErrInvalidTimeout},
	}
	for _, c := range cases {
		if err := ValidateForm(c.template, c.timeout, c.behavior); !errors.Is(err, c.want) {
			t.Errorf("%s: got %v, want %v", c.name, err, c.want)
		}
	}
}

func TestParseTimeout(t *testing.T) {
	okCases := []struct {
		in   string
		want time.Duration
	}{
		{"", 0},
		{"30d", 30 * 24 * time.Hour},
		{"2w", 2 * 7 * 24 * time.Hour},
		{"2h", 2 * time.Hour},
		{"90m", 90 * time.Minute},
	}
	for _, c := range okCases {
		got, err := ParseTimeout(c.in)
		if err != nil || got != c.want {
			t.Errorf("ParseTimeout(%q) = %v, %v; want %v, nil", c.in, got, err, c.want)
		}
	}
	for _, bad := range []string{"30x", "abc", "-5d", "d"} {
		if _, err := ParseTimeout(bad); err == nil {
			t.Errorf("ParseTimeout(%q) expected error", bad)
		}
	}
}

// TestDeadlineFrom pins the single timeout-resolution semantic shared by the CheckTimeouts sweep
// and the inbox wire deadline (工单④): parkedAt + timeout when set; ok=false for "" (never times
// out) and for unparseable values (mirrors ParseTimeout's err/0 skip).
func TestDeadlineFrom(t *testing.T) {
	parked := time.Date(2026, 7, 16, 10, 0, 0, 0, time.UTC)

	if got, ok := (&Version{Timeout: "30d"}).DeadlineFrom(parked); !ok || !got.Equal(parked.Add(30*24*time.Hour)) {
		t.Errorf("30d: got %v ok=%v", got, ok)
	}
	if got, ok := (&Version{Timeout: "2h"}).DeadlineFrom(parked); !ok || !got.Equal(parked.Add(2*time.Hour)) {
		t.Errorf("2h: got %v ok=%v", got, ok)
	}
	for _, timeout := range []string{"", "30x", "abc"} {
		if _, ok := (&Version{Timeout: timeout}).DeadlineFrom(parked); ok {
			t.Errorf("Timeout=%q must yield no deadline", timeout)
		}
	}
}

func TestIsValidTimeoutBehavior(t *testing.T) {
	for _, b := range []string{"reject", "approve", "fail"} {
		if !IsValidTimeoutBehavior(b) {
			t.Errorf("IsValidTimeoutBehavior(%q) = false, want true", b)
		}
	}
	for _, b := range []string{"", "maybe", "yes"} {
		if IsValidTimeoutBehavior(b) {
			t.Errorf("IsValidTimeoutBehavior(%q) = true, want false", b)
		}
	}
}
