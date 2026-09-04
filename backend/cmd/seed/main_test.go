package main

import (
	"net/http"
	"testing"
)

func TestWithAuthOptionalBearer(t *testing.T) {
	original := *authToken
	t.Cleanup(func() { *authToken = original })

	*authToken = "sidecar-token"
	req, err := http.NewRequest(http.MethodGet, "http://127.0.0.1/health", nil)
	if err != nil {
		t.Fatal(err)
	}
	withAuth(req)
	if got := req.Header.Get("Authorization"); got != "Bearer sidecar-token" {
		t.Fatalf("Authorization = %q, want Bearer sidecar-token", got)
	}

	*authToken = ""
	req, err = http.NewRequest(http.MethodGet, "http://127.0.0.1/health", nil)
	if err != nil {
		t.Fatal(err)
	}
	withAuth(req)
	if got := req.Header.Get("Authorization"); got != "" {
		t.Fatalf("Authorization = %q, want empty for dev seed", got)
	}
}
