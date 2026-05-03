// search.go — WebSearch system tool: 3-tier fallback search with no
// per-user API key required. Tries each tier in order, returning the
// first non-empty hit list:
//
//   1. SearXNG public instance pool (JSON, fastest path).
//   2. Bing HTML scrape — international users, broad coverage.
//   3. Bing CN HTML scrape — fallback for users in mainland China where
//      international Bing may be filtered.
//
// Every backend uses a 10-second per-request timeout so the worst-case
// 3-tier wall-clock stays under the chat layer's 30-second tool budget.
//
// Decision D8 (no BYOK + accept maintenance risk) is documented in
// progress-record.md; the SearXNG instance list is intentionally small
// and curated, with FORGIFY_SEARXNG_INSTANCES env override for users
// who want to point at their own instance.
//
// search.go — WebSearch 系统工具：3 层 fallback 搜索，不需要用户配 key。
// 顺序尝试，第一个非空结果即返：
//   1. SearXNG 公共实例池（JSON，最快）
//   2. Bing HTML 抓取——国际用户，覆盖广
//   3. Bing CN HTML 抓取——大陆用户兜底（国际 Bing 可能被过滤）
//
// 每后端 10s 单请求超时，让 3 层最坏墙钟在 chat 层 30s tool 预算内。
//
// 决策 D8（不要 BYOK + 接受维护风险）见 progress-record.md；SearXNG 实例
// 列表故意小且精选，`FORGIFY_SEARXNG_INSTANCES` 环境变量可覆盖。
package web

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
)

// ── Limits & defaults ─────────────────────────────────────────────────────────

const (
	// searchTimeout caps a single backend call. Three backends × 10s = 30s
	// worst case which fits comfortably inside the chat tool budget.
	//
	// searchTimeout 限制单后端调用；3 后端 × 10s = 30s 最坏，适配 chat 工具预算。
	searchTimeout = 10 * time.Second

	// defaultSearchLimit is the result count when LLM does not specify.
	// Matches what most search APIs return on a default query.
	//
	// defaultSearchLimit 是 LLM 不指定时的结果数；与多数搜索 API 默认一致。
	defaultSearchLimit = 10

	// maxSearchLimit hard cap so the LLM cannot ask for 1000 results.
	//
	// maxSearchLimit 硬上限，防 LLM 索取上千条。
	maxSearchLimit = 30

	// browserUA is a recent Chrome UA. Bing in particular returns fewer
	// results (or 403s) for blank/curl UAs.
	//
	// browserUA 是较新 Chrome UA；尤其 Bing 对空 UA 或 curl 会少返结果或 403。
	browserUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
		"AppleWebKit/537.36 (KHTML, like Gecko) " +
		"Chrome/126.0.0.0 Safari/537.36"
)

// defaultSearXNGInstances is the curated fallback pool when the env override
// is unset. Kept short and rotated periodically; users should set
// FORGIFY_SEARXNG_INSTANCES to their own instance for reliable results.
//
// defaultSearXNGInstances 是 env 覆盖未设时的精选回退池。故意短且周期更新；
// 用户应配 FORGIFY_SEARXNG_INSTANCES 指向自己的实例以获稳定结果。
var defaultSearXNGInstances = []string{
	"https://searx.be",
	"https://searx.tiekoetter.com",
	"https://searxng.online",
	"https://search.inetol.net",
}

// bingURL / bingCNURL are package vars so tests can swap them for httptest
// instances. The real endpoints are HTML search result pages.
//
// bingURL / bingCNURL 是 var 让测试能换成 httptest；线上是 HTML 结果页。
var (
	bingURL   = "https://www.bing.com/search"
	bingCNURL = "https://cn.bing.com/search"
)

// ── Validation sentinels ──────────────────────────────────────────────────────

var (
	// ErrEmptyQuery: query missing or empty.
	// ErrEmptyQuery：query 缺失或为空。
	ErrEmptyQuery = errors.New("query is required and must be non-empty")
)

// ── Description & schema ──────────────────────────────────────────────────────

const searchDescription = `Web search with 3-tier fallback (SearXNG public pool → Bing → Bing CN). No API key required.

Usage:
- ` + "`query`" + ` is the search string (treated as one phrase by the upstream engine).
- Returns JSON: {"query","source","results":[{"title","url","snippet"}],"truncated"}.
- ` + "`source`" + ` tells you which tier produced the results: "searxng", "bing", or "bing_cn".
- ` + "`limit`" + ` caps the result count (default 10, hard max 30).
- Each tier has a 10-second budget; the tool falls through if a tier returns no results or errors.
- Set the FORGIFY_SEARXNG_INSTANCES env var (comma-separated URLs) to point at your own SearXNG instance for reliable results.`

var searchSchema = json.RawMessage(`{
	"type": "object",
	"required": ["query"],
	"properties": {
		"query": {
			"type": "string",
			"description": "Search query string."
		},
		"limit": {
			"type": "number",
			"description": "Maximum results to return (default 10, hard max 30)."
		}
	}
}`)

// ── Args ──────────────────────────────────────────────────────────────────────

type searchArgs struct {
	Query string `json:"query"`
	Limit int    `json:"limit"`
}

func (a *searchArgs) normalize() {
	if a.Limit == 0 {
		a.Limit = defaultSearchLimit
	}
	if a.Limit > maxSearchLimit {
		a.Limit = maxSearchLimit
	}
}

// ── Output ────────────────────────────────────────────────────────────────────

// searchResult is one hit. Field shapes match what an LLM expects from a
// search API; we never leak engine-specific extras.
//
// searchResult 是一条命中；字段形态对齐 LLM 对搜索 API 的期望，不漏后端内部。
type searchResult struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}

type searchResponse struct {
	Query     string         `json:"query"`
	Source    string         `json:"source"` // "searxng" / "bing" / "bing_cn"
	Results   []searchResult `json:"results"`
	Truncated bool           `json:"truncated"`
}

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// WebSearch implements the WebSearch system tool. It carries a per-tool
// http.Client (shorter timeout than fetchClient) and the resolved
// SearXNG instance list.
//
// WebSearch struct 是 WebSearch 系统工具；自带短超时 http.Client 与解析后
// 的 SearXNG 实例列表。
type WebSearch struct {
	httpClient *http.Client
	instances  []string
}

// Identity --------------------------------------------------------------------

func (t *WebSearch) Name() string                { return "WebSearch" }
func (t *WebSearch) Description() string         { return searchDescription }
func (t *WebSearch) Parameters() json.RawMessage { return searchSchema }

// Static metadata -------------------------------------------------------------

func (t *WebSearch) IsReadOnly() bool        { return true }
func (t *WebSearch) NeedsReadFirst() bool    { return false }
func (t *WebSearch) RequiresWorkspace() bool { return false }

// Args-dependent hooks --------------------------------------------------------

// ValidateInput rejects empty queries and negative limits pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 query 与负 limit。
func (t *WebSearch) ValidateInput(args json.RawMessage) error {
	var a searchArgs
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("WebSearch.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.Query) == "" {
		return ErrEmptyQuery
	}
	if a.Limit < 0 {
		return errors.New("limit must be non-negative")
	}
	return nil
}

func (t *WebSearch) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute walks the 3-tier fallback ladder, returning the first non-empty
// result list as JSON. Network failures and zero-result responses both
// trigger the next tier.
//
// Execute 走 3 层 fallback 阶梯，第一个非空结果列表作 JSON 返回。
// 网络失败与零结果都会触发下一层。
func (t *WebSearch) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("WebSearch.Execute: %w", err)
	}
	args.normalize()

	tiers := []struct {
		name string
		run  func(context.Context, string) ([]searchResult, error)
	}{
		{"searxng", t.runSearXNG},
		{"bing", t.runBing},
		{"bing_cn", t.runBingCN},
	}

	var lastErr error
	for _, tier := range tiers {
		if ctx.Err() != nil {
			break
		}
		results, err := tier.run(ctx, args.Query)
		if err != nil {
			lastErr = fmt.Errorf("%s: %w", tier.name, err)
			continue
		}
		if len(results) == 0 {
			continue
		}
		return marshalSearchResponse(args, tier.name, results)
	}

	if lastErr != nil {
		return fmt.Sprintf("All search backends failed. Last error: %v", lastErr), nil
	}
	return fmt.Sprintf("No results for %q across SearXNG, Bing, and Bing CN.", args.Query), nil
}

// marshalSearchResponse caps to args.Limit, sets the truncated flag, and
// JSON-encodes the response.
//
// marshalSearchResponse 截到 args.Limit、置 truncated、JSON 编码。
func marshalSearchResponse(args searchArgs, source string, results []searchResult) (string, error) {
	truncated := false
	if len(results) > args.Limit {
		results = results[:args.Limit]
		truncated = true
	}
	body, err := json.MarshalIndent(searchResponse{
		Query:     args.Query,
		Source:    source,
		Results:   results,
		Truncated: truncated,
	}, "", "  ")
	if err != nil {
		return "", fmt.Errorf("WebSearch.Execute: marshal: %w", err)
	}
	return string(body), nil
}

// ── SearXNG backend (Tier 1) ──────────────────────────────────────────────────

// runSearXNG queries instances in random order until one responds. Random
// ordering spreads load across the public pool — sequential would always
// hammer the first one.
//
// runSearXNG 随机顺序遍历实例直到一个响应；随机分散公共池负载，顺序会
// 总打第一个。
func (t *WebSearch) runSearXNG(ctx context.Context, query string) ([]searchResult, error) {
	pool := append([]string(nil), t.instances...)
	rand.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })

	var lastErr error
	for _, base := range pool {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		results, err := t.querySearXNG(ctx, base, query)
		if err == nil && len(results) > 0 {
			return results, nil
		}
		if err != nil {
			lastErr = err
		}
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, nil
}

// querySearXNG hits a single instance's JSON endpoint and parses its
// reply. Only the (title, url, content) fields are kept; SearXNG-specific
// metadata (engine, score, …) is discarded so the LLM sees a clean list.
//
// querySearXNG 打一个实例的 JSON 端点并解析；只保留 (title, url, content)，
// 丢弃 SearXNG 专属元数据，让 LLM 看到干净列表。
func (t *WebSearch) querySearXNG(ctx context.Context, base, query string) ([]searchResult, error) {
	u, err := url.Parse(strings.TrimRight(base, "/") + "/search")
	if err != nil {
		return nil, err
	}
	q := u.Query()
	q.Set("q", query)
	q.Set("format", "json")
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", browserUA)

	resp, err := t.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("http status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxFetchBytes))
	if err != nil {
		return nil, err
	}

	var raw struct {
		Results []struct {
			Title   string `json:"title"`
			URL     string `json:"url"`
			Content string `json:"content"`
		} `json:"results"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, fmt.Errorf("decode searxng json: %w", err)
	}
	out := make([]searchResult, 0, len(raw.Results))
	for _, r := range raw.Results {
		if r.URL == "" {
			continue
		}
		out = append(out, searchResult{
			Title:   strings.TrimSpace(r.Title),
			URL:     r.URL,
			Snippet: strings.TrimSpace(r.Content),
		})
	}
	return out, nil
}

// ── Bing backends (Tiers 2 + 3) ───────────────────────────────────────────────

// runBing scrapes www.bing.com.
//
// runBing 抓 www.bing.com。
func (t *WebSearch) runBing(ctx context.Context, query string) ([]searchResult, error) {
	return t.scrapeBing(ctx, bingURL, query)
}

// runBingCN scrapes cn.bing.com — same DOM structure, different region.
//
// runBingCN 抓 cn.bing.com——DOM 结构同，区域不同。
func (t *WebSearch) runBingCN(ctx context.Context, query string) ([]searchResult, error) {
	return t.scrapeBing(ctx, bingCNURL, query)
}

// scrapeBing fetches the Bing search page and extracts results from
// `<li class="b_algo">` blocks. Bing's HTML changes occasionally — this
// is best-effort; if Bing rewrites their layout, we fall through to the
// next tier (or all-failed).
//
// scrapeBing 抓 Bing 搜索页，从 `<li class="b_algo">` 块提取结果。
// Bing HTML 偶有变动——尽力而为；如果 Bing 重写布局，落到下一层（或全失败）。
func (t *WebSearch) scrapeBing(ctx context.Context, base, query string) ([]searchResult, error) {
	u, err := url.Parse(base)
	if err != nil {
		return nil, err
	}
	q := u.Query()
	q.Set("q", query)
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", browserUA)
	req.Header.Set("Accept", "text/html,application/xhtml+xml")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7")

	resp, err := t.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("http status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxFetchBytes))
	if err != nil {
		return nil, err
	}
	return parseBingHTML(string(body))
}

// ── env override helper ───────────────────────────────────────────────────────

// resolveSearXNGInstances honours FORGIFY_SEARXNG_INSTANCES (comma-separated)
// and falls back to the curated default list when unset.
//
// resolveSearXNGInstances 优先 FORGIFY_SEARXNG_INSTANCES 环境变量
// （逗号分隔），未设走精选默认列表。
func resolveSearXNGInstances() []string {
	if raw := strings.TrimSpace(os.Getenv("FORGIFY_SEARXNG_INSTANCES")); raw != "" {
		parts := strings.Split(raw, ",")
		out := make([]string, 0, len(parts))
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" {
				out = append(out, p)
			}
		}
		if len(out) > 0 {
			return out
		}
	}
	return append([]string(nil), defaultSearXNGInstances...)
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*WebSearch)(nil)
