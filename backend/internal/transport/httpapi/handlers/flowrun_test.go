package handlers

import (
	"errors"
	"testing"
	"time"

	flowrundomain "github.com/sunweilin/anselm/backend/internal/domain/flowrun"
	triggerdomain "github.com/sunweilin/anselm/backend/internal/domain/trigger"
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

// TestParseListTime pins the window-bound grammar shared by ?startedAfter/?startedBefore (工单⑥)
// and ?createdAfter/?createdBefore (工单⑭): absent → zero time (unbounded), RFC3339 → UTC-normalized
// (an offset-carrying bound must compare right against UTC-stored rows), everything else — including
// parseSince's duration forms, deliberately NOT accepted here — a loud 422.
func TestParseListTime(t *testing.T) {
	t.Run("absent → zero time (unbounded)", func(t *testing.T) {
		got, err := parseListTime("", "startedAfter", flowrundomain.ErrInvalidListFilter)
		if err != nil || !got.IsZero() {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("RFC3339 UTC", func(t *testing.T) {
		got, err := parseListTime("2026-07-01T08:30:00Z", "startedAfter", flowrundomain.ErrInvalidListFilter)
		if err != nil || !got.Equal(time.Date(2026, 7, 1, 8, 30, 0, 0, time.UTC)) {
			t.Fatalf("got %v err=%v", got, err)
		}
	})
	t.Run("offset normalized to UTC", func(t *testing.T) {
		got, err := parseListTime("2026-07-01T16:30:00+08:00", "startedBefore", flowrundomain.ErrInvalidListFilter)
		if err != nil || !got.Equal(time.Date(2026, 7, 1, 8, 30, 0, 0, time.UTC)) || got.Location() != time.UTC {
			t.Fatalf("got %v (loc %v) err=%v", got, got.Location(), err)
		}
	})
	for _, bad := range []string{"gremlin", "24h", "7d", "2026-07-01", "2026-13-99T00:00:00Z", "1626397800"} {
		t.Run("rejects "+bad, func(t *testing.T) {
			if _, err := parseListTime(bad, "startedAfter", flowrundomain.ErrInvalidListFilter); !errors.Is(err, flowrundomain.ErrInvalidListFilter) {
				t.Fatalf("%q must reject with ErrInvalidListFilter, got %v", bad, err)
			}
		})
	}
	// The shared parser must wear the CALLER's sentinel: /firings must never answer a bad
	// ?createdAfter by naming the flowrun list (工单⑭).
	// 共享 parser 必须戴**调用方**的 sentinel：/firings 绝不能拿 flowrun 列表的码去答一个坏的
	// ?createdAfter（工单⑭）。
	t.Run("caller's sentinel, not the parser's", func(t *testing.T) {
		_, err := parseListTime("gremlin", "createdAfter", triggerdomain.ErrInvalidFiringFilter)
		if !errors.Is(err, triggerdomain.ErrInvalidFiringFilter) {
			t.Fatalf("firings must reject with ErrInvalidFiringFilter, got %v", err)
		}
		if errors.Is(err, flowrundomain.ErrInvalidListFilter) {
			t.Fatalf("a /firings filter error must NOT name the flowrun list: %v", err)
		}
		var e *errorspkg.Error
		if !errors.As(err, &e) || e.Details["param"] != "createdAfter" || e.Details["got"] != "gremlin" {
			t.Fatalf("details must carry the offending param + value, got %+v", err)
		}
	})
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
