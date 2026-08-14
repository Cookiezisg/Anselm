package llm

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestQuotaClient_FetchSuccess(t *testing.T) {
	// The public install id marks the request for proof signing, the path is
	// baseURL+/quota, and the gateway body maps field-for-field into QuotaResult.
	var gotAuth, gotPath string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth, gotPath = r.Header.Get("X-Anselm-Install-ID"), r.URL.Path
		_, _ = w.Write([]byte(`{"limit":5000,"used":1200,"remaining":3800,"resetAt":"2026-07-01T00:00:00Z","available":true}`))
	}))
	defer srv.Close()

	res, err := NewQuotaClient(http.DefaultClient).Fetch(context.Background(), srv.URL+"/v1", "ins_test")
	if err != nil {
		t.Fatal(err)
	}
	if gotAuth != "ins_test" {
		t.Errorf("install id = %q, want ins_test", gotAuth)
	}
	if gotPath != "/v1/quota" {
		t.Errorf("path = %q, want /v1/quota", gotPath)
	}
	if res.Limit != 5000 || res.Used != 1200 || res.Remaining != 3800 || res.ResetAt != "2026-07-01T00:00:00Z" || !res.Available {
		t.Errorf("res = %+v, mismatch", res)
	}
}

func TestQuotaClient_NonOKMapsAuthFailed(t *testing.T) {
	// Gateway 401 INVALID_INSTALL → ErrAuthFailed via classifyHTTPError, not a
	// silent zero quota that would mislead the settings gauge.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":{"code":"INVALID_INSTALL"}}`))
	}))
	defer srv.Close()

	if _, err := NewQuotaClient(http.DefaultClient).Fetch(context.Background(), srv.URL+"/v1", "ins_bad"); !errors.Is(err, ErrAuthFailed) {
		t.Fatalf("err = %v, want ErrAuthFailed", err)
	}
}

func TestQuotaClient_TransportFailureMapsProviderError(t *testing.T) {
	// A gateway outage is a recoverable upstream condition. It must reach the HTTP layer as the
	// structured 502/LLM_PROVIDER_ERROR path, not as an unmapped 500 that leaves the settings card
	// with a stale green quota.
	srv := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {}))
	baseURL := srv.URL + "/v1"
	srv.Close()

	if _, err := NewQuotaClient(http.DefaultClient).Fetch(context.Background(), baseURL, "ins_offline"); !errors.Is(err, ErrProviderError) {
		t.Fatalf("transport failure = %v, want ErrProviderError", err)
	}
}

func TestQuotaClient_MalformedBaseURLMapsProviderError(t *testing.T) {
	if _, err := NewQuotaClient(http.DefaultClient).Fetch(context.Background(), "://bad", "ins_bad"); !errors.Is(err, ErrProviderError) {
		t.Fatalf("malformed base URL = %v, want ErrProviderError", err)
	}
}
