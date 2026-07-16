package handlers

import (
	"errors"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestParseSince pins the ?since grammar: RFC3339 absolute, Go duration look-back, <n>d days
// look-back, absent → zero (app default), everything else a loud FLOWRUN_STATS_INVALID_SINCE.
func TestParseSince(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)

	t.Run("absent → zero time (app applies the default)", func(t *testing.T) {
		got, err := parseSince("", now)
		if err != nil || !got.IsZero() {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("RFC3339 absolute", func(t *testing.T) {
		got, err := parseSince("2026-07-01T08:30:00Z", now)
		if err != nil || !got.Equal(time.Date(2026, 7, 1, 8, 30, 0, 0, time.UTC)) {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("Go duration look-back", func(t *testing.T) {
		got, err := parseSince("24h", now)
		if err != nil || !got.Equal(now.Add(-24*time.Hour)) {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("<n>d days look-back", func(t *testing.T) {
		got, err := parseSince("7d", now)
		if err != nil || !got.Equal(now.Add(-7*24*time.Hour)) {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	for _, bad := range []string{"gremlin", "-24h", "0h", "0d", "-3d", "d", "2026-13-99"} {
		t.Run("rejects "+bad, func(t *testing.T) {
			if _, err := parseSince(bad, now); !errors.Is(err, flowrundomain.ErrStatsInvalidSince) {
				t.Fatalf("%q must reject with ErrStatsInvalidSince, got %v", bad, err)
			}
		})
	}
}

// TestParseListTime pins the ?startedAfter / ?startedBefore grammar (工单⑥): absent → zero time
// (unbounded), RFC3339 → UTC-normalized (an offset-carrying bound must compare right against
// UTC-stored rows), everything else — including parseSince's duration forms, deliberately NOT
// accepted here — a loud FLOWRUN_LIST_INVALID_FILTER.
func TestParseListTime(t *testing.T) {
	t.Run("absent → zero time (unbounded)", func(t *testing.T) {
		got, err := parseListTime("", "startedAfter")
		if err != nil || !got.IsZero() {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("RFC3339 UTC", func(t *testing.T) {
		got, err := parseListTime("2026-07-01T08:30:00Z", "startedAfter")
		if err != nil || !got.Equal(time.Date(2026, 7, 1, 8, 30, 0, 0, time.UTC)) {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("offset normalized to UTC", func(t *testing.T) {
		got, err := parseListTime("2026-07-01T16:30:00+08:00", "startedBefore")
		if err != nil || !got.Equal(time.Date(2026, 7, 1, 8, 30, 0, 0, time.UTC)) || got.Location() != time.UTC {
			t.Fatalf("got %v (loc %v) err=%v", got, got.Location(), err)
		}
	})
	for _, bad := range []string{"gremlin", "24h", "7d", "2026-07-01", "2026-13-99T00:00:00Z", "1626397800"} {
		t.Run("rejects "+bad, func(t *testing.T) {
			if _, err := parseListTime(bad, "startedAfter"); !errors.Is(err, flowrundomain.ErrInvalidListFilter) {
				t.Fatalf("%q must reject with ErrInvalidListFilter, got %v", bad, err)
			}
		})
	}
}

// TestParseRecentN mirrors ParsePage's limit semantics: absent → 0 (app default), non-numeric
// or <1 → ErrInvalidRequest; the upper clamp is the app service's.
func TestParseRecentN(t *testing.T) {
	if n, err := parseRecentN(""); err != nil || n != 0 {
		t.Fatalf("absent: n=%d err=%v", n, err)
	}
	if n, err := parseRecentN("15"); err != nil || n != 15 {
		t.Fatalf("valid: n=%d err=%v", n, err)
	}
	for _, bad := range []string{"abc", "0", "-3", "1.5"} {
		if _, err := parseRecentN(bad); !errors.Is(err, errorspkg.ErrInvalidRequest) {
			t.Fatalf("%q must reject with ErrInvalidRequest, got %v", bad, err)
		}
	}
}
