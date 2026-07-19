package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
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

// TestParseOffset pins the ?offset grammar (WRK-070 B4, page-number pagination): absent/blank →
// NOT offset mode (0, false, no error); a non-negative integer → (n, true); anything else
// (non-numeric, negative, float) → a loud 422 reusing FLOWRUN_LIST_INVALID_FILTER with param=offset
// in Details — an offset is just another list filter, so a bad value shares the code with a bad
// ?origin rather than minting a second one for the same class of mistake. Deliberately NOT
// ErrInvalidRequest (the 400 ?limit path): offset is flowrun-list grammar, so its rejection names
// the resource.
//
// TestParseOffset 钉 ?offset 文法（WRK-070 B4，页码分页）：缺席/空白 → **非** offset 模式（0, false,
// 无错）；非负整数 → (n, true)；其余（非数字、负数、小数）→ 大声 422、复用 FLOWRUN_LIST_INVALID_FILTER、
// Details 带 param=offset——offset 只是又一个 list 过滤，坏值与坏 ?origin 共用码、不为同类错误另铸一个。
// 刻意**不**用 ErrInvalidRequest（400 的 ?limit 路径）：offset 是 flowrun 列表文法，其拒绝须点名资源。
func TestParseOffset(t *testing.T) {
	// Absent / blank → not offset mode. 缺席/空白 → 非 offset 模式。
	for _, blank := range []string{"", "   "} {
		if n, use, err := parseOffset(blank); err != nil || use || n != 0 {
			t.Fatalf("blank %q must be (0,false,nil), got (%d,%v,%v)", blank, n, use, err)
		}
	}
	// Valid non-negative integers → (n, true). 合法非负整数。
	for raw, want := range map[string]int{"0": 0, "40": 40, "1000": 1000} {
		if n, use, err := parseOffset(raw); err != nil || !use || n != want {
			t.Fatalf("%q must be (%d,true,nil), got (%d,%v,%v)", raw, want, n, use, err)
		}
	}
	// Bad values → 422 FLOWRUN_LIST_INVALID_FILTER (not ErrInvalidRequest), param=offset in Details.
	// 坏值 → 422 FLOWRUN_LIST_INVALID_FILTER（非 ErrInvalidRequest），Details 带 param=offset。
	for _, bad := range []string{"-1", "abc", "1.5", "3x", "0x10"} {
		_, _, err := parseOffset(bad)
		if !errors.Is(err, flowrundomain.ErrInvalidListFilter) {
			t.Fatalf("%q must reject with ErrInvalidListFilter, got %v", bad, err)
		}
		var e *errorspkg.Error
		if errors.As(err, &e) {
			if e.Details["param"] != "offset" || e.Details["got"] != bad {
				t.Fatalf("%q details must carry param=offset + got, got %+v", bad, e.Details)
			}
		}
	}
}

// TestList_CursorOffsetConflict — WRK-070 B4: GET /flowruns given BOTH ?cursor and ?offset is a loud
// 422 FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT (two mutually exclusive pagination modes), and a malformed
// ?offset alone is a 422 FLOWRUN_LIST_INVALID_FILTER. Both verdicts are reached in the transport
// BEFORE any service read, so a nil service is safe (same technique as TestListFirings) — this pins
// the routing + error codes without standing up a scheduler.
//
// TestList_CursorOffsetConflict — WRK-070 B4：GET /flowruns 同时给 ?cursor 与 ?offset 是大声 422
// FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT（两种互斥分页模式），单独给畸形 ?offset 是 422
// FLOWRUN_LIST_INVALID_FILTER。两个判决都在 transport 里、任何 service 读之前作出，故 nil service 安全
// （同 TestListFirings 技法）——无需立起 scheduler 即钉住路由 + 错误码。
func TestList_CursorOffsetConflict(t *testing.T) {
	h := NewFlowrunHandler(nil, nil)
	mux := http.NewServeMux()
	h.Register(mux)

	cases := []struct {
		name, url, wantCode string
	}{
		{"both modes", "/api/v1/flowruns?cursor=abc&offset=40", "FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT"},
		{"both, malformed offset still conflict", "/api/v1/flowruns?cursor=abc&offset=nope", "FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT"},
		{"malformed offset alone", "/api/v1/flowruns?offset=-5", "FLOWRUN_LIST_INVALID_FILTER"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, tc.url, nil))
			if rec.Code != http.StatusUnprocessableEntity {
				t.Fatalf("%s: status = %d, want 422 (body %s)", tc.url, rec.Code, rec.Body)
			}
			var body struct {
				Error struct {
					Code string `json:"code"`
				} `json:"error"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("%s: envelope: %v (%s)", tc.url, err, rec.Body)
			}
			if body.Error.Code != tc.wantCode {
				t.Fatalf("%s: code = %q, want %q", tc.url, body.Error.Code, tc.wantCode)
			}
		})
	}
}
