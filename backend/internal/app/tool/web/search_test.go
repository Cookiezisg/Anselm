// search_test.go — unit tests for WebSearch + Bing HTML parser. All
// network calls go through httptest servers and the package vars
// (jinaEndpoint already lives in fetch.go; bingURL / bingCNURL here)
// are swapped via test helpers. Real-internet calls are not exercised.
//
// search_test.go — WebSearch + Bing HTML 解析器单测；所有网络调用走
// httptest，包级 var（fetch.go 的 jinaEndpoint，本文件的 bingURL /
// bingCNURL）由 test helper 替换；不打真实互联网。
package web

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// ── Identity / metadata / schema ──────────────────────────────────────────────

func TestWebSearch_IdentityMethods(t *testing.T) {
	tool := newTestSearch(t)
	if tool.Name() != "WebSearch" {
		t.Errorf("Name = %q, want WebSearch", tool.Name())
	}
	if tool.Description() == "" {
		t.Error("Description should not be empty")
	}
	if len(tool.Parameters()) == 0 {
		t.Error("Parameters should not be empty")
	}
}

func TestWebSearch_StaticMetadata(t *testing.T) {
	tool := newTestSearch(t)
	if !tool.IsReadOnly() {
		t.Error("WebSearch should be read-only")
	}
	if tool.NeedsReadFirst() {
		t.Error("WebSearch should not require Read first")
	}
	if tool.RequiresWorkspace() {
		t.Error("WebSearch should not require workspace (network tool)")
	}
}

func TestWebSearch_Schema_IsParsableObject(t *testing.T) {
	var doc map[string]any
	if err := json.Unmarshal(searchSchema, &doc); err != nil {
		t.Fatalf("schema is not valid JSON: %v", err)
	}
	if doc["type"] != "object" {
		t.Errorf("schema type = %v", doc["type"])
	}
	props := doc["properties"].(map[string]any)
	for _, want := range []string{"query", "limit"} {
		if _, ok := props[want]; !ok {
			t.Errorf("schema missing property %q", want)
		}
	}
}

// ── ValidateInput ─────────────────────────────────────────────────────────────

func TestWebSearch_ValidateInput_RequiresQuery(t *testing.T) {
	tool := newTestSearch(t)
	if err := tool.ValidateInput(json.RawMessage(`{}`)); !errors.Is(err, ErrEmptyQuery) {
		t.Fatalf("want ErrEmptyQuery, got %v", err)
	}
	if err := tool.ValidateInput(json.RawMessage(`{"query":"   "}`)); !errors.Is(err, ErrEmptyQuery) {
		t.Fatalf("whitespace query should fail, got %v", err)
	}
}

func TestWebSearch_ValidateInput_RejectsNegativeLimit(t *testing.T) {
	tool := newTestSearch(t)
	if err := tool.ValidateInput(json.RawMessage(`{"query":"x","limit":-1}`)); err == nil {
		t.Fatal("expected error for negative limit")
	}
}

// ── normalize ─────────────────────────────────────────────────────────────────

func TestSearchArgs_NormalizeFillsDefaults(t *testing.T) {
	a := searchArgs{}
	a.normalize()
	if a.Limit != defaultSearchLimit {
		t.Errorf("Limit default = %d, want %d", a.Limit, defaultSearchLimit)
	}
}

func TestSearchArgs_NormalizeCapsHardLimit(t *testing.T) {
	a := searchArgs{Limit: 10_000}
	a.normalize()
	if a.Limit != maxSearchLimit {
		t.Errorf("Limit hard cap = %d, want %d", a.Limit, maxSearchLimit)
	}
}

// ── env override ──────────────────────────────────────────────────────────────

func TestResolveSearXNGInstances_UsesEnvOverride(t *testing.T) {
	t.Setenv("FORGIFY_SEARXNG_INSTANCES", "https://a.example,https://b.example, https://c.example ")
	got := resolveSearXNGInstances()
	want := []string{"https://a.example", "https://b.example", "https://c.example"}
	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d (got %v)", len(got), len(want), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("[%d] = %q, want %q", i, got[i], want[i])
		}
	}
}

func TestResolveSearXNGInstances_FallsBackToDefault(t *testing.T) {
	t.Setenv("FORGIFY_SEARXNG_INSTANCES", "")
	got := resolveSearXNGInstances()
	if len(got) != len(defaultSearXNGInstances) {
		t.Errorf("len = %d, want default %d", len(got), len(defaultSearXNGInstances))
	}
}

// ── End-to-end via Execute (3-tier dispatch) ──────────────────────────────────

func TestExecute_TierSearXNG_ReturnsResults(t *testing.T) {
	srx := newSearXNGServer(t, []searchResult{
		{Title: "Go Programming", URL: "https://go.dev", Snippet: "Build simple, secure, scalable systems."},
		{Title: "Effective Go", URL: "https://go.dev/doc/effective_go", Snippet: "Tips for writing clear, idiomatic Go code."},
	})
	defer srx.Close()

	tool := newTestSearchWith(t, []string{srx.URL})
	out := runSearch(t, tool, `{"query":"golang","limit":5}`)

	if out.Source != "searxng" {
		t.Errorf("source = %q, want searxng", out.Source)
	}
	if len(out.Results) != 2 {
		t.Errorf("results len = %d, want 2", len(out.Results))
	}
	if out.Truncated {
		t.Error("truncated should be false (under limit)")
	}
}

func TestExecute_TierBing_FiresWhenSearXNGEmpty(t *testing.T) {
	emptySrx := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"results":[]}`))
	}))
	defer emptySrx.Close()

	bing := newBingServer(t, sampleBingHTML)
	defer bing.Close()

	tool := newTestSearchWith(t, []string{emptySrx.URL})
	withBingURLs(t, bing.URL, "https://unused")
	out := runSearch(t, tool, `{"query":"go"}`)

	if out.Source != "bing" {
		t.Errorf("source = %q, want bing (SearXNG was empty)", out.Source)
	}
	if len(out.Results) == 0 {
		t.Errorf("expected Bing-parsed results, got 0")
	}
}

func TestExecute_TierBingCN_FiresWhenBingFails(t *testing.T) {
	emptySrx := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"results":[]}`))
	}))
	defer emptySrx.Close()

	deadBing := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusInternalServerError)
	}))
	defer deadBing.Close()

	bingCN := newBingServer(t, sampleBingHTML)
	defer bingCN.Close()

	tool := newTestSearchWith(t, []string{emptySrx.URL})
	withBingURLs(t, deadBing.URL, bingCN.URL)
	out := runSearch(t, tool, `{"query":"go"}`)

	if out.Source != "bing_cn" {
		t.Errorf("source = %q, want bing_cn", out.Source)
	}
	if len(out.Results) == 0 {
		t.Error("expected Bing CN-parsed results")
	}
}

func TestExecute_AllBackendsFail_FriendlyMessage(t *testing.T) {
	deadSrx := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusInternalServerError)
	}))
	defer deadSrx.Close()

	deadBing := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "down", http.StatusInternalServerError)
	}))
	defer deadBing.Close()

	tool := newTestSearchWith(t, []string{deadSrx.URL})
	withBingURLs(t, deadBing.URL, deadBing.URL)
	body, err := tool.Execute(context.Background(), `{"query":"unrecoverable"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(body, "All search backends failed") {
		t.Errorf("expected friendly all-failed message, got: %q", body)
	}
}

func TestExecute_AppliesLimitAndSetsTruncated(t *testing.T) {
	many := make([]searchResult, 0, 8)
	for i := 0; i < 8; i++ {
		many = append(many, searchResult{Title: "t", URL: "https://example.com/", Snippet: "s"})
	}
	srx := newSearXNGServer(t, many)
	defer srx.Close()

	tool := newTestSearchWith(t, []string{srx.URL})
	out := runSearch(t, tool, `{"query":"x","limit":3}`)
	if !out.Truncated {
		t.Error("truncated should be true (8 > 3)")
	}
	if len(out.Results) != 3 {
		t.Errorf("results len = %d, want 3", len(out.Results))
	}
}

func TestExecute_HonoursContextCancellation(t *testing.T) {
	slow := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(200 * time.Millisecond)
		_, _ = w.Write([]byte(`{"results":[]}`))
	}))
	defer slow.Close()

	tool := newTestSearchWith(t, []string{slow.URL})
	withBingURLs(t, slow.URL, slow.URL)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	body, err := tool.Execute(ctx, `{"query":"x"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	// On cancelled ctx Execute either short-circuits (no-results path) or
	// reports the failure; both are acceptable as long as it returned.
	// 取消的 ctx 下要么走 no-results 短路要么报失败；只要 return 即可。
	if body == "" {
		t.Error("expected some response body even on cancellation")
	}
}

// ── Bing HTML parser ──────────────────────────────────────────────────────────

const sampleBingHTML = `
<!DOCTYPE html>
<html>
<body>
<ol id="b_results">
	<li class="b_algo">
		<h2><a href="https://go.dev">The Go Programming Language</a></h2>
		<div class="b_caption">
			<p>Build simple, secure, scalable systems with Go.</p>
		</div>
	</li>
	<li class="b_pagination"><span>page</span></li>
	<li class="b_algo">
		<h2><a href="https://pkg.go.dev/net/http">net/http package - pkg.go.dev</a></h2>
		<div class="b_caption"><p>Package http provides HTTP client and server   implementations.</p></div>
	</li>
	<li class="b_algo">
		<h2></h2>
		<div class="b_caption"><p>missing url, should be skipped</p></div>
	</li>
</ol>
</body>
</html>`

func TestParseBingHTML_ExtractsResults(t *testing.T) {
	results, err := parseBingHTML(sampleBingHTML)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("len = %d, want 2 (third b_algo has no url)", len(results))
	}
	if results[0].Title != "The Go Programming Language" {
		t.Errorf("results[0].Title = %q", results[0].Title)
	}
	if results[0].URL != "https://go.dev" {
		t.Errorf("results[0].URL = %q", results[0].URL)
	}
	if !strings.Contains(results[0].Snippet, "scalable systems") {
		t.Errorf("results[0].Snippet = %q", results[0].Snippet)
	}
	// Whitespace collapsing: "implementations." after multi-space inner.
	// 空白压缩验证。
	if !strings.Contains(results[1].Snippet, "implementations.") || strings.Contains(results[1].Snippet, "  ") {
		t.Errorf("results[1].Snippet not properly collapsed: %q", results[1].Snippet)
	}
}

func TestParseBingHTML_EmptyDoc_NoResults(t *testing.T) {
	results, err := parseBingHTML("<html><body></body></html>")
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestParseBingHTML_FallsBackToFirstPWhenCaptionMissing(t *testing.T) {
	// Bing has been observed dropping the b_caption wrapper; ensure the
	// fallback "first <p> in li" path still grabs the snippet.
	// Bing 偶尔丢 b_caption 包装；确保 fallback "li 内首个 <p>" 仍能抓到 snippet。
	html := `
<html><body><li class="b_algo">
	<h2><a href="https://x.example">Example</a></h2>
	<p>direct paragraph snippet</p>
</li></body></html>`
	results, err := parseBingHTML(html)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(results) != 1 || results[0].Snippet != "direct paragraph snippet" {
		t.Errorf("fallback failed: %+v", results)
	}
}

// ── Test helpers ──────────────────────────────────────────────────────────────

func newTestSearch(t *testing.T) *WebSearch {
	t.Helper()
	return newTestSearchWith(t, defaultSearXNGInstances)
}

func newTestSearchWith(t *testing.T, instances []string) *WebSearch {
	t.Helper()
	return &WebSearch{
		httpClient: &http.Client{Timeout: 2 * time.Second},
		instances:  instances,
	}
}

// withBingURLs swaps bingURL / bingCNURL for the duration of the test.
//
// withBingURLs 测试期间替换 bingURL / bingCNURL。
func withBingURLs(t *testing.T, bing, bingCN string) {
	t.Helper()
	prevBing, prevCN := bingURL, bingCNURL
	bingURL, bingCNURL = bing, bingCN
	t.Cleanup(func() { bingURL, bingCNURL = prevBing, prevCN })
}

func newSearXNGServer(t *testing.T, results []searchResult) *httptest.Server {
	t.Helper()
	var hits int32
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		// Re-shape to the SearXNG JSON form (content == snippet).
		// 改塑成 SearXNG JSON 形（content == snippet）。
		shaped := struct {
			Results []struct {
				Title   string `json:"title"`
				URL     string `json:"url"`
				Content string `json:"content"`
			} `json:"results"`
		}{}
		for _, r := range results {
			shaped.Results = append(shaped.Results, struct {
				Title   string `json:"title"`
				URL     string `json:"url"`
				Content string `json:"content"`
			}{Title: r.Title, URL: r.URL, Content: r.Snippet})
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(shaped)
	}))
}

func newBingServer(t *testing.T, htmlBody string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(htmlBody))
	}))
}

func runSearch(t *testing.T, tool *WebSearch, args string) searchResponse {
	t.Helper()
	body, err := tool.Execute(context.Background(), args)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var out searchResponse
	if err := json.Unmarshal([]byte(body), &out); err != nil {
		t.Fatalf("decode response (raw=%q): %v", body, err)
	}
	return out
}
