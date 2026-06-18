package cron

import (
	"testing"
	"time"
)

// TestNextAfter — W1 (iteration loop): NextAfter projects a cron trigger's next scheduled fire so
// the UI can show "next fire in N". It must compute the first tick strictly after the given time
// using ParseStandard semantics, and error on an invalid expression.
func TestNextAfter(t *testing.T) {
	base := time.Date(2026, 6, 18, 10, 0, 0, 0, time.UTC)

	// "every day at 09:00" — from 10:00 the next fire is 09:00 tomorrow.
	next, err := NextAfter("0 9 * * *", base)
	if err != nil {
		t.Fatalf("NextAfter daily: %v", err)
	}
	want := time.Date(2026, 6, 19, 9, 0, 0, 0, time.UTC)
	if !next.Equal(want) {
		t.Errorf("daily next = %v, want %v", next, want)
	}

	// "every minute" — strictly after base, so 10:01.
	next2, err := NextAfter("* * * * *", base)
	if err != nil {
		t.Fatalf("NextAfter minutely: %v", err)
	}
	if !next2.After(base) || next2.Sub(base) > time.Minute {
		t.Errorf("minutely next = %v, want within (base, base+1m]", next2)
	}

	if _, err := NextAfter("not a cron", base); err == nil {
		t.Fatal("an invalid expression must error")
	}
}
