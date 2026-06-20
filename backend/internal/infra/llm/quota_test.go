package llm

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestQuotaClient_FetchSuccess(t *testing.T) {
	// The gwk_ token rides Authorization: Bearer (same scheme as chat), the path is baseURL+/quota,
	// and the gateway body maps field-for-field into QuotaResult.
	var gotAuth, gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth, gotPath = r.Header.Get("Authorization"), r.URL.Path
		_, _ = w.Write([]byte(`{"limit":5000,"used":1200,"remaining":3800,"resetAt":"2026-07-01T00:00:00Z","available":true}`))
	}))
	defer srv.Close()

	res, err := NewQuotaClient().Fetch(context.Background(), srv.URL+"/v1", "gwk_secret")
	if err != nil {
		t.Fatal(err)
	}
	if gotAuth != "Bearer gwk_secret" {
		t.Errorf("auth = %q, want Bearer gwk_secret", gotAuth)
	}
	if gotPath != "/v1/quota" {
		t.Errorf("path = %q, want /v1/quota", gotPath)
	}
	if res.Limit != 5000 || res.Used != 1200 || res.Remaining != 3800 || res.ResetAt != "2026-07-01T00:00:00Z" || !res.Available {
		t.Errorf("res = %+v, mismatch", res)
	}
}

func TestQuotaClient_NonOKMapsAuthFailed(t *testing.T) {
	// Gateway 401 INVALID_TOKEN (stale/banned install) → ErrAuthFailed via classifyHTTPError, not a
	// silent zero quota that would mislead the settings gauge.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":{"code":"INVALID_TOKEN"}}`))
	}))
	defer srv.Close()

	if _, err := NewQuotaClient().Fetch(context.Background(), srv.URL+"/v1", "gwk_bad"); !errors.Is(err, ErrAuthFailed) {
		t.Fatalf("err = %v, want ErrAuthFailed", err)
	}
}
