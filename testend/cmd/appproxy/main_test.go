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
	h := newHandler(u, "/api/v1/conversations", 0, 2, http.StatusServiceUnavailable, 0, 0, 0, 0, "", "", 0, "", "", 0, "", "", 0, "", "", "", 0, func(r journalRecord) {
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

func TestNewHandlerInjectsAuthOnlyOnConfiguredPath(t *testing.T) {
	var got []string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = append(got, r.Header.Get("Authorization"))
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(upstream.Close)
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}

	h := newHandler(u, "/never", 0, 0, http.StatusServiceUnavailable, 0, 0, 0, 0, "edge-token", "/api/v1/health", 0, "", "", 0, "", "", 0, "", "", "", 0, func(journalRecord) {})
	for _, path := range []string{"/api/v1/health", "/api/v1/workspaces"} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.Header.Set("Authorization", "Bearer stale")
		resp := httptest.NewRecorder()
		h.ServeHTTP(resp, req)
		if resp.Code != http.StatusOK {
			t.Fatalf("%s status = %d, want 200", path, resp.Code)
		}
	}
	if len(got) != 2 || got[0] != "Bearer edge-token" || got[1] != "" {
		t.Fatalf("upstream authorization = %#v, want health token then empty", got)
	}
}

func TestNewHandlerDropsWorkspaceHeaderWhenConfigured(t *testing.T) {
	var gotHeader, gotAuthorization string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotHeader = r.Header.Get("X-Anselm-Workspace-ID")
		gotAuthorization = r.Header.Get("Authorization")
		w.WriteHeader(http.StatusOK)
	}))
	t.Cleanup(upstream.Close)
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}

	h := newHandler(u, "/api/v1/conversations", 0, 0, http.StatusServiceUnavailable, 0, 0, 0, 0, "", "", 1, "", "", 0, "", "", 0, "", "", "", 0, func(journalRecord) {})
	req := httptest.NewRequest(http.MethodGet, "/api/v1/conversations", nil)
	req.Header.Set("X-Anselm-Workspace-ID", "ws-should-not-cross")
	req.Header.Set("Authorization", "Bearer app-token")
	resp := httptest.NewRecorder()
	h.ServeHTTP(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", resp.Code)
	}
	if gotHeader != "" {
		t.Fatalf("upstream workspace header = %q, want absent", gotHeader)
	}
	if gotAuthorization != "Bearer app-token" {
		t.Fatalf("unrelated authorization header = %q, want preserved", gotAuthorization)
	}
}

func TestNewHandlerRewritesUpstreamHostWithFiniteTargetedBudget(t *testing.T) {
	var gotHosts []string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotHosts = append(gotHosts, r.Host)
		w.WriteHeader(http.StatusForbidden)
	}))
	t.Cleanup(upstream.Close)
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}

	var records []journalRecord
	h := newHandler(u, "/api/v1/conversations", 0, 0, http.StatusServiceUnavailable, 0, 0, 0, 0, "", "", 0, "/api/v1/conversations", "evil.example.com", 1, "", "", 0, "", "", "", 0, func(r journalRecord) {
		records = append(records, r)
	})
	for i := 0; i < 2; i++ {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/conversations", nil)
		resp := httptest.NewRecorder()
		h.ServeHTTP(resp, req)
		if resp.Code != http.StatusForbidden {
			t.Fatalf("request %d status = %d, want 403", i, resp.Code)
		}
	}
	if len(gotHosts) != 2 || gotHosts[0] != "evil.example.com" || gotHosts[1] == "evil.example.com" {
		t.Fatalf("upstream hosts = %#v, want one rewritten then canonical upstream host", gotHosts)
	}
	var rewritten int
	for _, r := range records {
		if r.Event == "host_rewritten" && r.Host == "evil.example.com" {
			rewritten++
		}
	}
	if rewritten != 1 {
		t.Fatalf("host_rewritten records = %d, want 1", rewritten)
	}
}

func TestNewHandlerRewritesPathAndMethodWithFiniteBudgets(t *testing.T) {
	type request struct {
		method string
		path   string
	}
	var got []request
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got = append(got, request{method: r.Method, path: r.URL.Path})
		if r.Method == http.MethodPut {
			w.Header().Set("Allow", "GET, HEAD")
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		w.WriteHeader(http.StatusNotFound)
	}))
	t.Cleanup(upstream.Close)
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	var records []journalRecord
	h := newHandler(u, "/api/v1/conversations", 0, 0, http.StatusServiceUnavailable, 0, 0, 0, 0, "", "", 0, "", "", 0, "/api/v1/conversations", "/api/v1/rig-unknown", 1, "/api/v1/conversations", http.MethodGet, http.MethodPut, 1, func(r journalRecord) {
		records = append(records, r)
	})

	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/conversations?limit=30", nil)
		resp := httptest.NewRecorder()
		h.ServeHTTP(resp, req)
		wantStatus := http.StatusNotFound
		if i == 1 {
			wantStatus = http.StatusMethodNotAllowed
		}
		if resp.Code != wantStatus {
			t.Fatalf("request %d status = %d, want %d", i, resp.Code, wantStatus)
		}
	}
	want := []request{{http.MethodGet, "/api/v1/rig-unknown"}, {http.MethodPut, "/api/v1/conversations"}, {http.MethodGet, "/api/v1/conversations"}}
	if len(got) != len(want) {
		t.Fatalf("upstream requests = %#v, want %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("upstream request %d = %#v, want %#v", i, got[i], want[i])
		}
	}
	var pathRewrites, methodRewrites int
	for _, r := range records {
		pathRewrites += boolInt(r.Event == "path_rewritten")
		methodRewrites += boolInt(r.Event == "method_rewritten")
	}
	if pathRewrites != 1 || methodRewrites != 1 {
		t.Fatalf("rewrite journal counts = path %d/method %d, want 1/1", pathRewrites, methodRewrites)
	}
}

func boolInt(v bool) int {
	if v {
		return 1
	}
	return 0
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
