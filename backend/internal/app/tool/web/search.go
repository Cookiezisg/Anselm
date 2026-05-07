// search.go — WebSearch system tool: 3-tier routing (BYOK → MCP → Bing CN).
//
// Routing priority:
//  1. BYOK: iterate apikeydomain.SearchProviderPriority (brave, serper,
//     tavily, bocha) — first configured key whose call returns non-empty
//     wins. Per-provider failures fall through with warn log.
//  2. MCP: if user installed the duckduckgo-search MCP server (V1
//     marketplace entry), route the query through it. Connection failures
//     fall through with warn log; "not configured" falls through silently.
//  3. Bing CN: HTML scrape of cn.bing.com — works in mainland China without
//     VPN and outside China too. The "no setup, no key" safety net.
//
// Each backend has a 10-second per-request timeout. If all 3 tiers return
// empty / fail, the tool surfaces a clear error to the LLM.
//
// search.go ——WebSearch 系统工具：3 层路由（BYOK → MCP → Bing CN）。
//
// 路由优先级：
//  1. BYOK：按 apikeydomain.SearchProviderPriority 顺序遍历（brave / serper /
//     tavily / bocha）—— 第一个配了 key 且调用返非空的胜出。per-provider 失败
//     log warn 并降级。
//  2. MCP：用户装了 duckduckgo-search MCP server（V1 marketplace 条目）就
//     路由过去。连接失败 warn log 降级；未配置静默降级。
//  3. Bing CN：cn.bing.com HTML 抓取——国内免 VPN + 国外也能用，"零配置零 key"
//     安全网。
//
// 每后端 10s 单请求超时。3 层全空/失败时给 LLM 清楚的报错。
package web

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"

	"go.uber.org/zap"
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

// bingCNURL is package var so tests can swap it for an httptest instance.
// The real endpoint is the cn.bing.com HTML search results page.
//
// bingCNURL 是 var 让测试能换 httptest；线上是 cn.bing.com HTML 结果页。
var bingCNURL = "https://cn.bing.com/search"

// ── Validation sentinels ──────────────────────────────────────────────────────

var (
	// ErrEmptyQuery: query missing or empty.
	// ErrEmptyQuery：query 缺失或为空。
	ErrEmptyQuery = errors.New("query is required and must be non-empty")
)

// ── Description & schema ──────────────────────────────────────────────────────

const searchDescription = `Web search. Routes to the first available source: configured BYOK provider (Brave / Serper / Tavily / Bocha), then duckduckgo-search MCP server (if installed), then a built-in Bing CN scrape as the no-key fallback.

Usage:
- ` + "`query`" + ` is the search string (treated as one phrase by the upstream engine).
- Returns JSON: {"query","source","results":[{"title","url","snippet"}],"truncated"}.
- ` + "`source`" + ` tells you which backend produced the results: "brave" / "serper" / "tavily" / "bocha" / "mcp" / "bing_cn".
- ` + "`limit`" + ` caps the result count (default 10, hard max 30).
- Each backend has a 10-second budget; the tool falls through if a backend returns no results or errors.
- Configure a search-category API key in Settings → API Keys for higher-quality results; the no-key Bing CN fallback works in mainland China without a VPN.`

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
	Source    string         `json:"source"` // "brave" / "serper" / "tavily" / "bocha" / "mcp" / "bing_cn"
	Results   []searchResult `json:"results"`
	Truncated bool           `json:"truncated"`
}

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// WebSearch implements the WebSearch system tool. Carries:
//   - httpClient: short-timeout client shared by all backends
//   - keys: BYOK lookup for search-category providers (apikey domain)
//   - mcpRouter: optional port to delegate to a connected MCP search server
//   - log: structured logger for per-tier fall-through traces
//
// WebSearch struct 是 WebSearch 系统工具；持短超时 httpClient、apikey 域的
// BYOK 查询 keys、可选 MCP 路由 mcpRouter、log 用于 per-tier 降级追踪。
type WebSearch struct {
	httpClient *http.Client
	keys       apikeydomain.KeyProvider
	mcpRouter  MCPSearchRouter
	log        *zap.Logger
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

// Execute walks the BYOK → MCP → Bing CN routing ladder. Returns the first
// non-empty result list as JSON. Per-tier failures + zero-result responses
// both trigger the next tier; warns are logged for "tried and failed" but
// not for "not configured" cases (the silent BYOK miss is the normal path
// for users who never set a key).
//
// Execute 走 BYOK → MCP → Bing CN 路由阶梯。第一个非空结果作 JSON 返。
// per-tier 失败 + 零结果都触发下一层；"试了挂"走 warn log，"未配置"静默
// （用户从没配 key 时这是正常路径）。
func (t *WebSearch) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args searchArgs
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("WebSearch.Execute: %w", err)
	}
	args.normalize()

	// Tier 1: BYOK iterate.
	if t.keys != nil {
		for _, provider := range apikeydomain.SearchProviderPriority {
			if ctx.Err() != nil {
				break
			}
			results, source, ok := t.tryBYOKProvider(ctx, provider, args.Query, args.Limit)
			if ok && len(results) > 0 {
				return marshalSearchResponse(args, source, results)
			}
		}
	}

	// Tier 2: MCP duckduckgo-search.
	if ctx.Err() == nil && t.mcpRouter != nil {
		results, err := t.runMCPSearch(ctx, args.Query, args.Limit)
		switch {
		case errors.Is(err, ErrMCPSearchUnavailable):
			// Silent fall-through — MCP search server simply not installed.
			// 静默降级——MCP 搜索 server 未装。
		case err != nil:
			t.warnf("WebSearch MCP backend failed; falling through", err)
		case len(results) > 0:
			return marshalSearchResponse(args, "mcp", results)
		}
	}

	// Tier 3: Bing CN scrape.
	if ctx.Err() == nil {
		results, err := t.scrapeBingCN(ctx, args.Query)
		if err != nil {
			t.warnf("WebSearch Bing CN scrape failed", err)
		} else if len(results) > 0 {
			return marshalSearchResponse(args, "bing_cn", results)
		}
	}

	return fmt.Sprintf("No results for %q across configured BYOK providers, MCP, and Bing CN. "+
		"Add a search-category API key in Settings → API Keys (Brave / Serper / Tavily / Bocha) "+
		"or install the duckduckgo-search MCP server for higher-quality results.", args.Query), nil
}

// tryBYOKProvider attempts one BYOK search call. Returns (results, source,
// true) on success; (nil, "", false) when the provider has no configured
// key OR the call failed (latter logged at warn). source is the provider
// name on success so the response payload tells the LLM which backend
// produced the results.
//
// tryBYOKProvider 试调一个 BYOK 搜索。成功 (results, source, true)；provider
// 无 key 或调用失败 (nil, "", false)；后者 warn log。source 是成功时的 provider
// 名让响应载荷告诉 LLM 是哪个后端给的结果。
func (t *WebSearch) tryBYOKProvider(ctx context.Context, provider, query string, limit int) ([]searchResult, string, bool) {
	creds, err := t.keys.ResolveCredentials(ctx, provider)
	if err != nil {
		// ErrNotFoundForProvider is the silent path. Other errors (e.g.
		// decryption fail) are still silent here — the next tier covers it.
		// ErrNotFoundForProvider 是静默路径；其他错误（如解密失败）这里也静默
		// ——下层兜。
		return nil, "", false
	}

	baseURL := strings.TrimRight(creds.BaseURL, "/")
	if baseURL == "" {
		// Defensive — meta.DefaultBaseURL should be merged by the
		// keyProvider. Fall through.
		// 防御——meta.DefaultBaseURL 应由 keyProvider 合并。降级。
		return nil, "", false
	}

	var (
		results []searchResult
		runErr  error
	)
	switch provider {
	case "brave":
		results, runErr = t.searchBrave(ctx, baseURL, creds.Key, query, limit)
	case "serper":
		results, runErr = t.searchSerper(ctx, baseURL, creds.Key, query, limit)
	case "tavily":
		results, runErr = t.searchTavily(ctx, baseURL, creds.Key, query, limit)
	case "bocha":
		results, runErr = t.searchBocha(ctx, baseURL, creds.Key, query, limit)
	default:
		// Defensive — providers list and switch must stay in sync.
		// 防御——providers 列表与 switch 必须同步。
		return nil, "", false
	}
	if runErr != nil {
		t.warnf(fmt.Sprintf("WebSearch BYOK %q failed; falling through", provider), runErr)
		// Surface 401/403 to apikey domain so the UI badge flips invalid.
		// 把 401/403 通知 apikey 域让 UI 徽章翻 invalid。
		t.markInvalidIfAuthErr(ctx, provider, runErr)
		return nil, "", false
	}
	return results, provider, true
}

// markInvalidIfAuthErr surfaces 401/403 errors from BYOK calls back to the
// apikey domain so the UI status flips. Best-effort: failure to mark
// is logged at debug only.
//
// markInvalidIfAuthErr 把 BYOK 401/403 通知 apikey 域让 UI 状态翻转。
// best-effort：marker 失败 debug log。
func (t *WebSearch) markInvalidIfAuthErr(ctx context.Context, provider string, err error) {
	msg := err.Error()
	if !strings.Contains(msg, "HTTP 401") && !strings.Contains(msg, "HTTP 403") {
		return
	}
	if t.keys == nil {
		return
	}
	// MarkInvalid expects ctx with userID; reqctx middleware always stamps
	// it for HTTP-driven calls. detached context retains the user ID so
	// background invocations work too.
	// MarkInvalid 期望 ctx 含 userID；HTTP 路径走 middleware；detached ctx 留
	// userID 让后台调用也能 mark。
	uid, _ := reqctxpkg.GetUserID(ctx)
	mctx := ctx
	if uid != "" {
		mctx = reqctxpkg.SetUserID(context.Background(), uid)
	}
	if merr := t.keys.MarkInvalid(mctx, provider, msg); merr != nil {
		t.debugf(fmt.Sprintf("MarkInvalid for %q failed", provider), merr)
	}
}

// warnf logs at warn level when t.log is non-nil; nil log = silent (tests).
//
// warnf 当 t.log 非空时 warn log；nil log 静默（测试）。
func (t *WebSearch) warnf(msg string, err error) {
	if t.log == nil {
		return
	}
	t.log.Warn(msg, zap.Error(err))
}

func (t *WebSearch) debugf(msg string, err error) {
	if t.log == nil {
		return
	}
	t.log.Debug(msg, zap.Error(err))
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

// ── Bing CN scrape (no-key fallback) ──────────────────────────────────────────

// scrapeBingCN fetches cn.bing.com search results and parses them via the
// shared parseBingHTML helper (search_bing.go). Bing's HTML changes
// occasionally — best-effort; if the layout shifts the result set will
// shrink to zero and the LLM gets the "no results" message.
//
// scrapeBingCN 抓 cn.bing.com 搜索结果并经 parseBingHTML（search_bing.go）解
// 析。Bing HTML 偶有变动——尽力；layout 变化会让结果集变 0，LLM 拿到"无结果"。
func (t *WebSearch) scrapeBingCN(ctx context.Context, query string) ([]searchResult, error) {
	u, err := url.Parse(bingCNURL)
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

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*WebSearch)(nil)
