// fetch.go — WebFetch system tool: fetches a URL and returns an
// LLM-generated summary tailored to the caller's prompt. Two-tier fetch:
//
//  1. Jina r.jina.ai reader (free public endpoint) for clean markdown.
//  2. Direct HTTP GET fallback when Jina is down / rate-limited.
//
// Content is capped at maxFetchBytes before being handed to the LLM,
// which is resolved via llmclient.ResolveForWebSummary so it picks the
// user's web_summary scenario when configured and silently falls back
// to the chat scenario otherwise.
//
// SSRF guard: hostname is resolved and rejected if any answer IP is
// private / loopback / link-local / unspecified. This is enforced before
// either Jina or the direct GET runs so an attacker can't smuggle an
// internal address by getting Jina to fetch on our behalf.
//
// fetch.go — WebFetch 系统工具：抓 URL 并返回按调用方 prompt 定制的 LLM
// 摘要。两段抓取：先 Jina r.jina.ai（免费公共端点，干净 markdown），失败
// 时回落到直 GET。内容封顶 maxFetchBytes 后交给 LLM——通过
// llmclient.ResolveForWebSummary 解析（用户配 web_summary 场景就用，没配
// 就静默 fallback 到 chat 场景）。
//
// SSRF 守卫：解析主机名，任一答案 IP 是私网/loopback/link-local/未指定即
// 拒绝；在 Jina 与直 GET 之前执行，防攻击者借 Jina 代请求探内网。
package web

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	llmclientpkg "github.com/sunweilin/forgify/backend/internal/pkg/llmclient"
)

// ── Limits & defaults ─────────────────────────────────────────────────────────

const (
	// fetchTimeout caps the wall-clock for a single fetch (Jina or direct).
	// Generous enough for slow blogs but short enough that an LLM ReAct
	// loop doesn't stall for a minute on a dead host.
	//
	// fetchTimeout 限制单次抓取（Jina 或直 GET）的墙钟；够慢博客用，又
	// 不会因死机让 ReAct 循环卡分钟级。
	fetchTimeout = 30 * time.Second

	// maxFetchBytes caps how much of the response we read. 1 MB is enough
	// for nearly all article-style pages and bounds the LLM token cost
	// when we forward content for summarisation.
	//
	// maxFetchBytes 限制读取字节数。1 MB 几乎覆盖所有文章型页面，并兜
	// 底转给 LLM 摘要的 token 成本。
	maxFetchBytes = 1 << 20

)

// jinaEndpoint is the public Jina reader. Prefixing the target URL
// with this base returns a markdown rendering of the page. No API key
// required for the free tier. Declared as var (not const) so tests can
// point it at a local httptest server.
//
// jinaEndpoint 是 Jina 公共 reader；前缀给目标 URL 后返回 markdown 渲染。
// 免费层不要 API key。声明为 var 而非 const，方便测试改指向本地 httptest。
var jinaEndpoint = "https://r.jina.ai/"

// ── Validation sentinels ──────────────────────────────────────────────────────

var (
	// ErrEmptyURL: url missing or empty.
	// ErrEmptyURL：url 缺失或为空。
	ErrEmptyURL = errors.New("url is required and must be non-empty")

	// ErrEmptyPrompt: prompt missing or empty. WebFetch always summarises;
	// without a prompt the LLM has no extraction target.
	// ErrEmptyPrompt：prompt 缺失或为空。WebFetch 必摘要，无 prompt 则
	// LLM 无提取目标。
	ErrEmptyPrompt = errors.New("prompt is required and must be non-empty")

	// ErrUnsupportedScheme: only http and https are allowed; file://,
	// gopher://, etc. would expand the SSRF surface.
	// ErrUnsupportedScheme：仅允许 http/https；file:// / gopher:// 等会
	// 扩大 SSRF 攻击面。
	ErrUnsupportedScheme = errors.New("url must use http or https scheme")
)

// ── Description & schema ──────────────────────────────────────────────────────

const fetchDescription = `Fetches a URL and returns an LLM-generated summary tailored to your prompt.

Usage:
- ` + "`url`" + ` must be an absolute http or https URL.
- ` + "`prompt`" + ` describes what to extract or summarise from the page (e.g. "What does this paper conclude?", "List every API endpoint mentioned").
- The tool fetches the URL (Jina reader for clean markdown when available, direct HTTP GET fallback), caps content at 1 MB, then asks the configured summary model to answer your prompt against that content.
- Summarisation uses the user's "web_summary" model scenario if configured; otherwise it falls back to the main "chat" scenario, so this works out of the box.
- Private / loopback / link-local addresses are blocked for safety (no fetching localhost or RFC 1918 ranges).
- Each fetch is capped at 30 seconds.`

var fetchSchema = json.RawMessage(`{
	"type": "object",
	"required": ["url", "prompt"],
	"properties": {
		"url": {
			"type": "string",
			"description": "Absolute http or https URL to fetch."
		},
		"prompt": {
			"type": "string",
			"description": "What to extract or summarise from the page content."
		}
	}
}`)

// ── Tool struct & 9 methods ───────────────────────────────────────────────────

// WebFetch implements the WebFetch system tool.
//
// WebFetch struct 是 WebFetch 系统工具。picker / keys / factory 解析
// summary LLM；http.Client 用包级 fetchClient（30s timeout）。
type WebFetch struct {
	picker  modeldomain.ModelPicker
	keys    apikeydomain.KeyProvider
	factory *llminfra.Factory
}

// Identity --------------------------------------------------------------------

func (t *WebFetch) Name() string                { return "WebFetch" }
func (t *WebFetch) Description() string         { return fetchDescription }
func (t *WebFetch) Parameters() json.RawMessage { return fetchSchema }

// Static metadata -------------------------------------------------------------

func (t *WebFetch) IsReadOnly() bool        { return true }
func (t *WebFetch) NeedsReadFirst() bool    { return false }
func (t *WebFetch) RequiresWorkspace() bool { return false }

// Args-dependent hooks --------------------------------------------------------

// ValidateInput rejects empty url/prompt and non-http(s) schemes pre-Execute.
//
// ValidateInput 在 Execute 前拒绝空 url / prompt / 非 http(s) scheme。
func (t *WebFetch) ValidateInput(args json.RawMessage) error {
	var a struct {
		URL    string `json:"url"`
		Prompt string `json:"prompt"`
	}
	if err := json.Unmarshal(args, &a); err != nil {
		return fmt.Errorf("WebFetch.ValidateInput: %w", err)
	}
	if strings.TrimSpace(a.URL) == "" {
		return ErrEmptyURL
	}
	if strings.TrimSpace(a.Prompt) == "" {
		return ErrEmptyPrompt
	}
	u, err := url.Parse(a.URL)
	if err != nil {
		return fmt.Errorf("WebFetch.ValidateInput: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return ErrUnsupportedScheme
	}
	return nil
}

func (t *WebFetch) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}

// ── Execute ───────────────────────────────────────────────────────────────────

// Execute performs the SSRF check, two-tier fetch, content cap, then asks
// the summary LLM to answer the caller's prompt against the fetched
// content. All network failures and SSRF rejections are returned as
// LLM-friendly strings (not Go errors) so the LLM can recover.
//
// Execute 做 SSRF 检查 → 两段抓取 → 内容截断 → summary LLM 按 prompt 回答。
// 网络失败与 SSRF 拒绝返友好字符串（不返 Go err），让 LLM 可恢复。
func (t *WebFetch) Execute(ctx context.Context, argsJSON string) (string, error) {
	var args struct {
		URL    string `json:"url"`
		Prompt string `json:"prompt"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return "", fmt.Errorf("WebFetch.Execute: %w", err)
	}

	parsed, err := url.Parse(args.URL)
	if err != nil {
		return fmt.Sprintf("Invalid URL %q: %v", args.URL, err), nil
	}
	if reason := guardHostname(parsed.Hostname()); reason != "" {
		return reason, nil
	}

	content, err := fetchContent(ctx, args.URL)
	if err != nil {
		return fmt.Sprintf("Failed to fetch %s: %v", args.URL, err), nil
	}
	if strings.TrimSpace(content) == "" {
		return fmt.Sprintf("Fetched %s but body was empty.", args.URL), nil
	}

	summary, err := t.summarise(ctx, args.URL, args.Prompt, content)
	if err != nil {
		// LLM-side failure: surface a clear message but include raw content
		// truncated so the LLM still has something to reason over.
		// LLM 端失败：返清晰消息，附截断后的原文让 LLM 仍可推理。
		return fmt.Sprintf("Summarisation failed (%v). Raw content (first 4 KB):\n\n%s",
			err, truncate(content, 4096)), nil
	}
	return summary, nil
}

// ── Network helpers ───────────────────────────────────────────────────────────

// fetchClient is a process-wide http.Client with the per-request timeout
// baked in. Reused so we don't pay the connection-pool warmup on every
// call.
//
// fetchClient 是进程级 http.Client，超时已内置；复用避免每次重建。
var fetchClient = &http.Client{Timeout: fetchTimeout}

// fetchContent runs the two-tier fetch: Jina first, direct GET fallback.
// Returns the raw body (capped) on success.
//
// fetchContent 跑两段抓取：先 Jina，失败 fallback 直 GET；成功返截断后正文。
func fetchContent(ctx context.Context, target string) (string, error) {
	if body, err := fetchViaJina(ctx, target); err == nil {
		return body, nil
	} else if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		// Don't retry on caller-driven cancellation.
		// 调用方主动取消时不重试。
		return "", err
	}
	return fetchDirect(ctx, target)
}

// fetchViaJina prepends the Jina reader prefix and asks for markdown.
// JINA_API_KEY enables the higher rate-limit tier when set.
//
// fetchViaJina 加 Jina reader 前缀并请求 markdown；JINA_API_KEY 设了走
// 高速率档。
func fetchViaJina(ctx context.Context, target string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, jinaEndpoint+target, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Accept", "text/markdown")
	req.Header.Set("User-Agent", "ForgifyWebFetch/1.0")
	if k := strings.TrimSpace(os.Getenv("JINA_API_KEY")); k != "" {
		req.Header.Set("Authorization", "Bearer "+k)
	}
	return doRequest(req)
}

// fetchDirect performs a plain HTTP GET on target. Useful when Jina is
// unavailable or returns an error; the LLM gets less-clean content but
// the workflow keeps moving.
//
// fetchDirect 直接 HTTP GET；Jina 不可用时让流程继续，LLM 收到的内容
// 不那么干净但能用。
func fetchDirect(ctx context.Context, target string) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "ForgifyWebFetch/1.0")
	return doRequest(req)
}

// doRequest sends req via fetchClient, enforces the byte cap, and returns
// the body. Non-2xx statuses become errors so the caller can decide
// whether to fall back.
//
// doRequest 用 fetchClient 发起 req，强制 byte cap，返 body；非 2xx 报错
// 让调用方决定是否 fallback。
func doRequest(req *http.Request) (string, error) {
	resp, err := fetchClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("http status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxFetchBytes))
	if err != nil {
		return "", err
	}
	return string(body), nil
}

// ── SSRF guard ────────────────────────────────────────────────────────────────

// guardHostname returns an empty string when the hostname is safe to
// fetch; otherwise it returns an LLM-facing rejection message.
//
// Both bare IP literals and resolvable names are checked. For names we
// resolve all addresses and reject if ANY answer falls in a denied range
// — this defeats DNS-rebinding tricks at the policy level (we don't
// pin the IP to the actual TCP connection, but a malicious name can no
// longer pass through with a public+private answer pair).
//
// guardHostname 安全则返空串；否则返 LLM 友好的拒绝消息。
//
// 裸 IP 与可解析域名都检查。域名解析所有地址，任一落入禁区即拒——从
// 策略上挫败 DNS rebinding（虽未把 IP 锁到 TCP 连接，但带"公网+私网"双
// 答案的恶意名字过不去）。
func guardHostname(host string) string {
	if host == "" {
		return "URL has no host."
	}
	host = strings.ToLower(strings.TrimSuffix(host, "."))
	if host == "localhost" || host == "ip6-localhost" || host == "ip6-loopback" {
		return "Refusing to fetch loopback host: " + host
	}
	if ip := net.ParseIP(host); ip != nil {
		if reason := classifyIP(ip); reason != "" {
			return reason
		}
		return ""
	}
	ips, err := net.LookupIP(host)
	if err != nil {
		// Unresolvable host — fail cleanly (the fetch would fail anyway,
		// but a clear message helps the LLM retry with a different URL).
		// 不可解析的主机——干净失败，让 LLM 看到清晰消息以便换 URL 重试。
		return fmt.Sprintf("Cannot resolve host %s: %v", host, err)
	}
	for _, ip := range ips {
		if reason := classifyIP(ip); reason != "" {
			return reason
		}
	}
	return ""
}

// classifyIP returns a rejection message when the IP is in a denied
// range (loopback / private / link-local / unspecified / multicast).
// Returns empty string for safe public addresses.
//
// classifyIP 在禁区返拒绝消息（loopback / 私网 / link-local / 未指定 /
// multicast）；公网安全地址返空串。
func classifyIP(ip net.IP) string {
	switch {
	case ip.IsLoopback():
		return "Refusing to fetch loopback address: " + ip.String()
	case ip.IsPrivate():
		return "Refusing to fetch private address: " + ip.String()
	case ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast():
		return "Refusing to fetch link-local address: " + ip.String()
	case ip.IsUnspecified():
		return "Refusing to fetch unspecified address: " + ip.String()
	case ip.IsMulticast():
		return "Refusing to fetch multicast address: " + ip.String()
	}
	return ""
}

// ── Summarisation ─────────────────────────────────────────────────────────────

// summarise resolves the web_summary LLM (with chat fallback) and asks
// it to answer prompt against content. Content is included verbatim
// inside delimiters so the model can quote precisely.
//
// summarise 解析 web_summary LLM（带 chat fallback），让它按 prompt 回答
// content；content 用界定符包起原样附上，便于模型精确引用。
func (t *WebFetch) summarise(ctx context.Context, source, prompt, content string) (string, error) {
	bundle, err := llmclientpkg.ResolveForWebSummary(ctx, t.picker, t.keys, t.factory)
	if err != nil {
		return "", err
	}
	body := buildSummaryPrompt(source, prompt, content)
	out, err := llminfra.Generate(ctx, bundle.Client, llminfra.Request{
		ModelID:  bundle.ModelID,
		Key:      bundle.Key,
		BaseURL:  bundle.BaseURL,
		Messages: []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: body}},
	})
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

// buildSummaryPrompt produces the user message the summarisation model
// receives. Stable layout helps the model anchor its response.
//
// buildSummaryPrompt 生成给摘要模型的 user message；稳定排版帮助模型锚定。
func buildSummaryPrompt(source, prompt, content string) string {
	return fmt.Sprintf(`You are summarising web content fetched on the user's behalf.

Source URL: %s

User's request: %s

Below is the fetched content (it may be markdown rendered by Jina or raw HTML):

<<<CONTENT_BEGIN>>>
%s
<<<CONTENT_END>>>

Answer the user's request directly based on the content above. If the content does not contain the requested information, say so clearly.`,
		source, prompt, content)
}

// truncate returns s capped at n bytes with an indicator suffix when cut.
//
// truncate 截到 n 字节，截断时附指示后缀。
func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "\n\n...[truncated]"
}

// ── Compile-time checks ───────────────────────────────────────────────────────

var _ toolapp.Tool = (*WebFetch)(nil)
