package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// TestSearchRejectsAmbiguousFilters pins the transport boundary: malformed filters must be
// actionable 422s before the service is touched, rather than silently changing the user's scope.
//
// TestSearchRejectsAmbiguousFilters 钉住 transport 边界：畸形过滤必须在触达 service 前变成可行动的
// 422，不能静默改变用户的搜索范围。
func TestSearchRejectsAmbiguousFilters(t *testing.T) {
	h := NewSearchHandler(nil, nil)
	mux := http.NewServeMux()
	h.Register(mux)
	cases := []struct {
		name, url, wantCode, wantParam string
	}{
		{name: "invalid after", url: "/api/v1/search?q=probe&updatedAfter=tomorrow", wantCode: "SEARCH_INVALID_WINDOW", wantParam: "updatedAfter"},
		{name: "invalid before", url: "/api/v1/search?q=probe&updatedBefore=2026-99-99T00:00:00Z", wantCode: "SEARCH_INVALID_WINDOW", wantParam: "updatedBefore"},
		{name: "inverted window", url: "/api/v1/search?q=probe&updatedAfter=2026-08-02T00:00:00Z&updatedBefore=2026-08-01T00:00:00Z", wantCode: "SEARCH_INVALID_WINDOW", wantParam: "updatedAfter/updatedBefore"},
		{name: "invalid archived flag", url: "/api/v1/search?q=probe&includeArchived=maybe", wantCode: "SEARCH_INVALID_INCLUDE_ARCHIVED", wantParam: "includeArchived"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, tc.url, nil))
			if rec.Code != http.StatusUnprocessableEntity {
				t.Fatalf("status = %d, want 422 (body %s)", rec.Code, rec.Body)
			}
			var body struct {
				Error struct {
					Code    string         `json:"code"`
					Details map[string]any `json:"details"`
				} `json:"error"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("decode error envelope: %v (%s)", err, rec.Body)
			}
			if body.Error.Code != tc.wantCode {
				t.Fatalf("code = %q, want %q (body %s)", body.Error.Code, tc.wantCode, rec.Body)
			}
			if got := body.Error.Details["param"]; got != tc.wantParam {
				t.Fatalf("details.param = %v, want %q (body %s)", got, tc.wantParam, rec.Body)
			}
		})
	}
}

func TestParseSearchFilters(t *testing.T) {
	for _, tc := range []struct {
		raw  string
		want bool
	}{
		{raw: "", want: true},
		{raw: "true", want: true},
		{raw: "FALSE", want: false},
	} {
		got, err := parseSearchIncludeArchived(tc.raw)
		if err != nil || got != tc.want {
			t.Errorf("parseSearchIncludeArchived(%q) = %v, %v; want %v, nil", tc.raw, got, err, tc.want)
		}
	}
	after, before, err := parseSearchWindow("2026-08-01T00:00:00+08:00", "2026-08-01T00:00:00+08:00")
	if err != nil || after == nil || before == nil || !after.Equal(*before) || after.Location() != time.UTC {
		t.Fatalf("equal offset bounds must normalize to one inclusive UTC instant: after=%v before=%v err=%v", after, before, err)
	}
}
