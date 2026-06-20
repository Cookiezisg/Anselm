package handlers

import "testing"

// TestGCOlderThanDays — F-sandbox-gc-zero (round-8 revertchurn): an explicit olderThanDays=0 must be
// honored as "reclaim all idle now" (the manual remedy for freshly-orphaned venvs), NOT silently
// coerced to the 30-day default. Empty / negative / garbage still fall back to 30.
func TestGCOlderThanDays(t *testing.T) {
	cases := []struct {
		raw  string
		want int
	}{
		{"0", 0},    // honored: force-reclaim all idle (was silently coerced to 30)
		{"7", 7},    // explicit positive
		{"30", 30},  // explicit default
		{"", 30},    // unset → default
		{"-5", 30},  // negative ignored → default
		{"abc", 30}, // non-numeric ignored → default
	}
	for _, c := range cases {
		if got := gcOlderThanDays(c.raw); got != c.want {
			t.Errorf("gcOlderThanDays(%q) = %d, want %d", c.raw, got, c.want)
		}
	}
}
