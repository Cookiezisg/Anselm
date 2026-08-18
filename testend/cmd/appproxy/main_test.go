package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sync"
	"testing"
)

func TestNewHandlerFailsTargetedRequestsThenForwards(t *testing.T) {
	var mu sync.Mutex
	upstreamHits := 0
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		upstreamHits++
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"data":[]}`)
	}))
	t.Cleanup(upstream.Close)
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}

	var journalMu sync.Mutex
	var records []journalRecord
	h := newHandler(u, "/api/v1/conversations", 0, 2, http.StatusServiceUnavailable, func(r journalRecord) {
		journalMu.Lock()
		defer journalMu.Unlock()
		records = append(records, r)
	})

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/conversations?limit=30", nil)
		resp := httptest.NewRecorder()
		h.ServeHTTP(resp, req)
		if i < 2 {
			if resp.Code != http.StatusServiceUnavailable {
				t.Fatalf("request %d status = %d, want 503", i, resp.Code)
			}
			var body map[string]map[string]string
			if err := json.Unmarshal(resp.Body.Bytes(), &body); err != nil {
				t.Fatalf("request %d error envelope: %v", i, err)
			}
			if body["error"]["code"] != "RIG_INJECTED_FAILURE" {
				t.Fatalf("request %d error code = %q", i, body["error"]["code"])
			}
		} else if resp.Code != http.StatusOK {
			t.Fatalf("forwarded request status = %d, want 200", resp.Code)
		}
	}

	nonTarget := httptest.NewRecorder()
	h.ServeHTTP(nonTarget, httptest.NewRequest(http.MethodGet, "/api/v1/workspaces", nil))
	if nonTarget.Code != http.StatusOK {
		t.Fatalf("non-target status = %d, want 200", nonTarget.Code)
	}

	mu.Lock()
	hits := upstreamHits
	mu.Unlock()
	if hits != 2 {
		t.Fatalf("upstream hits = %d, want forwarded target + non-target = 2", hits)
	}

	journalMu.Lock()
	defer journalMu.Unlock()
	var failures, forwards int
	for _, r := range records {
		switch r.Event {
		case "failure":
			failures++
		case "forward":
			forwards++
		}
	}
	if failures != 2 || forwards != 1 {
		t.Fatalf("journal failure/forward = %d/%d, want 2/1", failures, forwards)
	}
}

func TestFailureBudgetIsConcurrentAndFinite(t *testing.T) {
	b := &failureBudget{remaining: 7}
	var wg sync.WaitGroup
	var mu sync.Mutex
	taken := 0
	for i := 0; i < 32; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if ok, _ := b.take(); ok {
				mu.Lock()
				taken++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if taken != 7 {
		t.Fatalf("taken = %d, want finite budget 7", taken)
	}
	if ok, _ := b.take(); ok {
		t.Fatal("budget remained after concurrent exhaustion")
	}
}
