package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"
)

func TestMatchesDelayPathIsExactButIgnoresQuery(t *testing.T) {
	r := httptest.NewRequest("GET", "http://127.0.0.1/api/v1/workspaces?cursor=next", nil)
	if !matchesDelayPath(r, "/api/v1/workspaces") {
		t.Fatal("query string should not change the target path")
	}
	if matchesDelayPath(httptest.NewRequest("POST", "http://127.0.0.1/api/v1/workspaces", nil), "/api/v1/workspaces") {
		t.Fatal("non-GET requests must not be delayed")
	}
	if matchesDelayPath(httptest.NewRequest("GET", "http://127.0.0.1/api/v1/workspaces/1", nil), "/api/v1/workspaces") {
		t.Fatal("workspace subresource must not be delayed")
	}
}

func TestNewHandlerDelaysOnlyTheExactPath(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(r.URL.Path))
	}))
	defer upstream.Close()
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	var records []journalRecord
	proxy := httptest.NewServer(newHandler(u, "/api/v1/workspaces", 25*time.Millisecond, func(r journalRecord) {
		records = append(records, r)
	}))
	defer proxy.Close()

	start := time.Now()
	resp, err := http.Get(proxy.URL + "/api/v1/workspaces/1")
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if elapsed := time.Since(start); elapsed >= 20*time.Millisecond {
		t.Fatalf("non-target path was delayed: %s", elapsed)
	}
	start = time.Now()
	resp, err = http.Get(proxy.URL + "/api/v1/workspaces?cursor=next")
	if err != nil {
		t.Fatal(err)
	}
	_ = resp.Body.Close()
	if elapsed := time.Since(start); elapsed < 20*time.Millisecond {
		t.Fatalf("target path was not delayed: %s", elapsed)
	}
	if len(records) != 3 || records[0].Event != "request" || records[1].Event != "request" || records[2].Event != "forward" {
		t.Fatalf("unexpected journal records: %#v", records)
	}
}

func TestDelayRequestWaitsForConfiguredDuration(t *testing.T) {
	start := time.Now()
	if !delayRequest(context.Background(), 25*time.Millisecond) {
		t.Fatal("delay unexpectedly canceled")
	}
	if elapsed := time.Since(start); elapsed < 20*time.Millisecond {
		t.Fatalf("delay returned too early: %s", elapsed)
	}
}

func TestDelayRequestCanBeCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if delayRequest(ctx, time.Second) {
		t.Fatal("canceled delay reported success")
	}
}

func TestDelayRequestZeroIsImmediate(t *testing.T) {
	if !delayRequest(context.Background(), 0) {
		t.Fatal("zero delay should be successful")
	}
}
