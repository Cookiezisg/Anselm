# Web Tools — V1.2 详设计

**Phase**：5（System Tool 第二代 web 批次）
**状态**：✅ 实现完成（2026-05-04，W1-W4）
**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../../../CLAUDE.md`](../../../CLAUDE.md) §S18 — Tool 接口规约
- [`./chat.md`](./chat.md) §4.4 — 系统工具完整目录
- [`./model.md`](./model.md) — `utility` scenario 定义（WebFetch 摘要走此 scenario）
- 实现包：`backend/internal/app/tool/web/`

---

## 1. 一句话

LLM 上网两件套：**WebFetch**（抓 URL → LLM 摘要 → 返答案）+ **WebSearch**（BYOK → MCP 两层路由）。WebFetch 共享 SSRF 守卫（拒 loopback / 私网 / link-local + **逐跳重定向校验**）+ 30 秒墙钟。WebSearch 由用户提供搜索 API key（brave / serper / tavily / bocha）或装 duckduckgo-search MCP server——**无 HTML 抓取兜底**（屎山拯救计划 #4 全删）。WebFetch 摘要走 **utility scenario**（2026-05-28 model selection redesign 后；原 `web_summary` scenario + chat fallback 双删）。

---

## 2. 端到端推演（设计原则 #5）

### WebFetch 路径

```
触发源：LLM 调 WebFetch(url, prompt)
  → ValidateInput: url + prompt 非空 / scheme ∈ {http,https}
  → Execute:
      url.Parse → guardHostname(host)            // SSRF 守卫（DNS rebinding 防御）
      fetchContent(ctx, url):
        Tier 1: fetchViaJina(jinaEndpoint+url) → 干净 markdown
        Tier 2 (Jina 失败 / 非 ctx 取消): fetchDirect(url) → 原始 HTML
        // fetchClient 带 CheckRedirect = ssrfCheckRedirect → 每跳重新校验
      content 截到 1 MiB
      summarise(ctx, url, prompt, content):
        llmclient.ResolveUtility → bundle (utility scenario，2026-05-28 redesign 后)
        Generate(prompt + 内容片段)
      → tool_result：摘要文本
```

### WebSearch 路径

```
触发源：LLM 调 WebSearch(query)
  → ValidateInput: query 非空 / limit ≥0
  → 2 层路由 ladder:
      Tier 1: BYOK — 按 apikeydomain.SearchProviderPriority 顺序遍历
              brave / serper / tavily / bocha；ResolveCredentials 拿到 key
              即调对应 API（search_byok.go）；
              401/403 → ErrAuthFailed + markInvalidIfAuthErr 联动 apikey.MarkInvalid（detached ctx）
              429   → ErrRateLimited
              其他 5xx/4xx → ErrUpstreamHTTP
              缺 key / 失败 → warn log 落下一个 provider
      ctx.Err() 检查（取消则中断切换）
      Tier 2: MCP — 检查 mcpRouter 已注入 + duckduckgo-search server 已 ready；
              路由 MCPSearchRouter.CallSearchTool(ctx, query, limit)；
              ErrMCPSearchUnavailable / 无配置 → debug log 降级
              parseMCPSearchResults 接受 {"results":[...]} / 裸 array / raw blob 兜底
      每 BYOK provider 10 秒墙钟；任一 tier 返非空 results 即终止
  → 都空时返 LLM-actionable 提示：配 BYOK key 或装 duckduckgo-search MCP（无 HTML scrape 兜底说明）
  → JSON: {query, source(brave|serper|tavily|bocha|mcp), results[{title,url,snippet}], truncated}
```

**端到端跨 domain 依赖**：
- `pkg/llmclient.ResolveUtility`（仅 WebFetch）：解析 utility model scenario，缺配置 → 422 `MODEL_NOT_CONFIGURED`（onboarding 应已写 3 行，正常路径不会触发）
- `domain/model.ScenarioUtility` + `ModelPicker.PickForUtility`（共享 utility scenario，11 个 callsite 之一）
- `domain/apikey.KeyProvider`（解析 LLM 摘要 key + WebSearch 的 BYOK key + MarkInvalid 联动）
- `domain/apikey.SearchProviderPriority`（WebSearch BYOK 顺序：brave / serper / tavily / bocha）
- `infra/llm.Factory.Build`（构造 LLM client）
- `app/tool/web.MCPSearchRouter`（端口；main.go 注入 `*mcpapp.Service` 适配）
- env: `JINA_API_KEY`（可选，WebFetch 升速率档）
- 第三方：`golang.org/x/net/html`（HTML 解析；当前仅 WebFetch 走 Jina markdown / 直 GET HTML 摘要时用得上）
- 无 HTML scraper（屎山拯救计划 #4 删 SearXNG / Bing 国际 / Bing CN 三层）
- 无 DB / SSE / HTTP API

---

## 3. 关键决策

| 决策 | 选择 | 理由 |
|---|---|---|
| WebFetch 抓取策略 | **两段：Jina r.jina.ai → 直 GET fallback** | Jina 把任意网页转干净 markdown（免费层无 key），直 GET 兜底 Jina 限流 / down |
| WebFetch 摘要 LLM | 走 **utility scenario**（2026-05-28 redesign 后；与 autoTitle / compaction / search rerank / env-fix 共享一档）| 工具内部 LLM 活儿统一 utility 档；用户在 Settings 里配 utility 模型即可控成本（Haiku / 4o-mini 等）；onboarding 已写 3 行 → utility 一定有配置，无 fallback 需求 |
| **WebSearch 路由策略** | **BYOK → MCP 两层**，**无 HTML 抓取兜底** | 屎山拯救计划 #4 (2026-05-07)：原 SearXNG / Bing 国际 / Bing CN 三层 HTML 抓取全是假兜底——2025 现代 Bing/DDG 全部 JS 渲染，curl 拿不到结果。dogfood 实测后**全部删除**，替换为 BYOK→MCP 两层路由。两层失败时返 LLM-actionable 提示用户配 BYOK key 或装 duckduckgo-search MCP |
| 搜索 provider 列表 | brave / serper / tavily / **bocha** | bocha 是博查 API，国产搜索（国内免 VPN，海外慢）；priority 顺序写在 `apikeydomain.SearchProviderPriority` |
| MCP 路由 server 名 | hardcoded "duckduckgo-search" | V1 marketplace 唯一搜索类 MCP；将来真有第二个时升级到 Capability-based discovery |
| 401/403 → MarkInvalid 联动 | BYOK provider 返认证失败时 `keys.MarkInvalid(provider, err)` 让 UI 角标翻红 | 用户能立刻在 API Keys 页看到哪个 search key 坏了；用 detached ctx 写终态（§S9 模式）|
| SSRF 守卫策略 | **解析所有 IP，任一禁区即拒**（DNS rebinding 防御）+ **逐跳重定向校验** | 单纯入口校验会被 302→localhost 绕过（**Tool 自检 batch 1 修的真 bug**）；现 `fetchClient.CheckRedirect = ssrfCheckRedirect` 每跳重跑 |
| 重定向跳数上限 | 10 | Go 默认值；超过即 `stopped after 10 redirects` |
| 单请求 byte cap | 1 MiB | 几乎覆盖所有文章型页面；摘要 LLM 的 token 成本可控 |
| 单后端超时 | WebFetch 30s / WebSearch 10s × 单 BYOK provider | 30s 单 fetch 给慢博客留空间；BYOK 顺序遍历 4 个 provider 各 10s（无配置的 provider 立即跳过，无墙钟惩罚）|
| User-Agent | Chrome 桌面 UA | 部分 endpoint 对空 UA / curl UA 返更少结果 / 403 |
| Image / PDF 抓取 | **v1 不实现**——仅 markdown / 文本 | description 不写未实现内容 |

---

## 4. 工具规约

### 4.1 WebFetch（`backend/internal/app/tool/web/fetch.go`）

**Args**：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `url` | string | ✅ | 绝对 http/https URL |
| `prompt` | string | ✅ | 摘要指令（"概括要点"/"列出 API"等）|

**返回**：摘要 LLM 的回答字符串。

**特殊情况**：
- Validate 失败 → Go err（chat 转 tool_result）
- SSRF 拒 → `Refusing to fetch loopback address: 127.0.0.1`（或 private/link-local/unspecified/multicast 对应文案）
- 重定向到禁区 → `Failed to fetch <url>: redirect blocked: Refusing to fetch loopback...`
- 超时 / 网络错 → `Failed to fetch <url>: <err>`
- 双 tier 都失败 → 同上（最后一个 err）
- 空 body → `Fetched <url> but body was empty.`
- 摘要 LLM 失败 → `Summarisation failed (<err>). Raw content (first 4 KB):\n\n<truncated>`（兜底返原文 4KB 让 LLM 不至于完全没信息）

**静态元数据**：`IsReadOnly=true` / `NeedsReadFirst=false` / `RequiresWorkspace=false`（**网络工具不碰文件系统**）

**ValidateInput** sentinels：
- `ErrEmptyURL` / `ErrEmptyPrompt`
- `ErrUnsupportedScheme` — 仅允许 http/https（拒 file:// / ftp:// / gopher://，扩大 SSRF 攻击面）

### 4.2 WebSearch（`search.go`）

**Args**：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `query` | string | ✅ | 搜索词 |
| `limit` | number | | 默认 10；硬上限 30 |

**返回**（JSON）：
```json
{
  "query": "golang",
  "source": "brave",
  "results": [
    {"title": "Go", "url": "https://go.dev", "snippet": "Build simple..."}
  ],
  "truncated": false
}
```

- `source`：`"brave"` / `"serper"` / `"tavily"` / `"bocha"` / `"mcp"` —— 让 LLM 知道走的哪 tier
- `truncated`：`true` 表示原始结果数 > limit
- 双 tier 都无可用 / 都返 0 结果 → **多行 LLM-actionable 提示**，告诉 LLM 让用户去：(a) API Keys 页配一个搜索 provider key（brave / serper / tavily / bocha 任一），(b) 或在 MCP 页装 `duckduckgo-search` MCP server。文案显式说明"无 HTML scrape 兜底"以免 LLM 困惑为啥连不上

**Sentinels（HTTP-status-classified，已登记 errmap）**：
- `webtool.ErrAuthFailed` — BYOK provider 返 401 / 403 → wire `WEBSEARCH_AUTH_FAILED`；同时触发 `keys.MarkInvalid(provider, ...)` 终态写
- `webtool.ErrRateLimited` — provider 返 429 → wire `WEBSEARCH_RATE_LIMITED`
- `webtool.ErrUpstreamHTTP` — provider 返其他 5xx / 4xx → wire `WEBSEARCH_UPSTREAM_HTTP`
- `webtool.ErrMCPSearchUnavailable` — 内部 sentinel（无 MCP search server 已连接）；调用方落下层，不上抛 handler

**静态元数据**：`IsReadOnly=true` / `NeedsReadFirst=false` / `RequiresWorkspace=false`

**ValidateInput** sentinels：
- `ErrEmptyQuery` — query 缺 / 空 / 仅空白
- limit < 0 → `errors.New("limit must be non-negative")`

### 4.3 WebTools 工厂

```go
// app/tool/web/web.go
func WebTools(
    picker modeldomain.ModelPicker,    // WebFetch 摘要 LLM 决策
    keys apikeydomain.KeyProvider,     // BYOK key 解析 + MarkInvalid 联动
    factory *llminfra.Factory,         // WebFetch 摘要 LLM 客户端工厂
    mcpRouter MCPSearchRouter,         // WebSearch MCP tier — main.go 注 mcpapp.Service 适配器；nil 时 MCP tier 静默跳过
    log *zap.Logger,                   // WebSearch 走 BYOK / MCP fallback 时打 warn / debug
) []toolapp.Tool {
    return []toolapp.Tool{
        newWebFetch(picker, keys, factory),
        newWebSearch(keys, mcpRouter, log),
    }
}
```

调用方按 §S13 嵌套子包别名规则导入为 `webtool`。

### 4.3.1 MCPSearchRouter 端口

```go
// app/tool/web/search_mcp.go — web 包持端口
type MCPSearchRouter interface {
    // CallSearchTool delegates a query to a connected MCP search server
    // and returns the raw tool result string. Returns
    // ErrMCPSearchUnavailable when no MCP search server is configured.
    //
    // CallSearchTool 委派 query 给已连接 MCP 搜索 server，返原始 tool result
    // 字符串。无配置/未连接返 ErrMCPSearchUnavailable，调用方落下层。
    CallSearchTool(ctx context.Context, query string, limit int) (string, error)
}

var ErrMCPSearchUnavailable = errors.New("mcp search server unavailable")
```

**理由**：web 包持端口避免循环依赖（`web` 不 import `app/mcp`）。装配方向：`mcpapp.Service` 实现 `MCPSearchRouter` 的适配代码写在 main.go，注入给 `WebTools(...)`。这是 hexagonal-style 的 port/adapter 形态——port 在消费方（web），adapter 在主程序（main.go）。

---

## 5. 实现要点

### 5.1 SSRF 守卫（`guardHostname` + `classifyIP`）

**两层防御**：

```go
func guardHostname(host string) string {
    // (1) 字面 loopback 名拒
    if host ∈ {"localhost", "ip6-localhost", "ip6-loopback"} { return reject }

    // (2) 裸 IP 字面：classifyIP 检测
    if ip := net.ParseIP(host); ip != nil {
        return classifyIP(ip)  // loopback / private / link-local / unspecified / multicast
    }

    // (3) 域名：解析所有 IP，任一禁区即拒（DNS rebinding 策略级防御）
    ips, _ := net.LookupIP(host)
    for _, ip := range ips {
        if reason := classifyIP(ip); reason != "" { return reason }
    }
    return ""  // safe
}
```

**已知局限**：不绑定 IP 到 TCP 连接（pinning 需要自定义 Dialer，复杂度大）。带"公网 + 私网双答案"的恶意域名挡住了；高速 DNS 翻转攻击（请求时翻转 IP）理论上仍可能。

### 5.2 重定向逐跳校验（**Tool 自检 batch 1 加固**）

```go
var fetchClient = &http.Client{
    Timeout:       fetchTimeout,
    CheckRedirect: ssrfCheckRedirect,
}

func ssrfCheckRedirect(req *http.Request, via []*http.Request) error {
    if len(via) >= 10 { return errors.New("stopped after 10 redirects") }
    if reason := guardHostname(req.URL.Hostname()); reason != "" {
        return fmt.Errorf("redirect blocked: %s", reason)
    }
    return nil
}
```

**为啥重要**：`http.Client` 默认跟随 302/301 不做任何安全校验。修复前公网 URL → 302 → `http://localhost` 能绕过入口的 `guardHostname`。Tool 自检 batch 1 加 CheckRedirect 后每跳重跑（详 fetch_test.go 4 个回归测试）。

### 5.3 摘要 LLM 解析（`llmclient.ResolveUtility`，2026-05-28 redesign 后）

```go
// pkg/llmclient/llmclient.go
func ResolveUtility(ctx, picker, keys, factory) (*Bundle, error) {
    apiKeyID, modelID, err := picker.PickForUtility(ctx)
    if err != nil { return nil, err }   // ErrNotConfigured → 422 MODEL_NOT_CONFIGURED
    return finishResolve(ctx, apiKeyID, modelID, keys, factory)
}
```

**无 fallback 链**：2026-05-28 redesign 把 utility 提到独立默认配置（onboarding 时 3 行 PUT 已写齐 dialogue/utility/agent）；任一 scenario 缺行 = onboarding 没完成 = 422 引导用户去 Settings 配。原 `ResolveForWebSummary` 的"web_summary 找不到就 fallback chat" 双删——产品未上线无升级路径，严格 422 更清楚。

### 5.4 BYOK provider 路由（`search_byok.go`）

```go
// WebSearch.Execute 主体
for _, provider := range apikeydomain.SearchProviderPriority {
    // brave / serper / tavily / bocha
    results, source, ok := t.tryBYOKProvider(ctx, provider, query, limit)
    if ok {
        return marshalSearchResponse(args, source, results), nil
    }
}
// 所有 BYOK 都不可用 → 落 MCP tier
```

`tryBYOKProvider`：
- `keys.ResolveCredentials(ctx, provider)` 拿 key；无 key → 跳到下一个 provider（不算失败，没墙钟惩罚）
- 调对应 endpoint：
  - `brave` → `GET https://api.search.brave.com/res/v1/web/search?q=...`，header `X-Subscription-Token`
  - `serper` → `POST https://google.serper.dev/search`，header `X-API-KEY`，body `{"q": query}`
  - `tavily` → `POST https://api.tavily.com/search`，body `{"api_key": key, "query": query}`
  - `bocha` → `POST https://api.bochaai.com/v1/web-search`，header `Authorization: Bearer`
- HTTP 状态码分类：
  - 401 / 403 → `ErrAuthFailed`，且调 `markInvalidIfAuthErr` 联动 apikey 域
  - 429 → `ErrRateLimited`
  - 其他 5xx / 4xx → `ErrUpstreamHTTP`
- 解析返结果非空 → 返 `(results, provider, true)`；空或错 → 返 `(_, _, false)` 让调用方进下一个

### 5.5 MCP tier（`search_mcp.go`）

```go
func (t *WebSearch) runMCPSearch(ctx, query, limit) ([]searchResult, error) {
    if t.mcpRouter == nil {
        return nil, ErrMCPSearchUnavailable
    }
    raw, err := t.mcpRouter.CallSearchTool(ctx, query, limit)
    if err != nil {
        return nil, err
    }
    return parseMCPSearchResults(raw), nil
}
```

`parseMCPSearchResults`：
- 接受 `{"results":[...]}` 形（最常见）
- 接受**裸 array** 形（兜底）
- 都解析失败时**最后 fallback**：把 raw blob 当 1 个 result 的 snippet（让 LLM 至少看到原文，而非全空——降级路径）

### 5.6 401/403 → MarkInvalid 联动（`markInvalidIfAuthErr`）

```go
func (t *WebSearch) markInvalidIfAuthErr(ctx, provider string, err error) {
    if !errors.Is(err, ErrAuthFailed) {
        return
    }
    // detached ctx：上游 cancel 不能让 invalid 标记丢失
    detached := reqctxpkg.SetUserID(context.Background(), uid)
    _ = t.keys.MarkInvalid(detached, provider, err.Error())
    t.warnf("websearch: provider key marked invalid", err)
}
```

让用户在 API Keys 页看到角标翻红。

---

## 6. 安全边界

| 防线 | 覆盖 | 局限 |
|---|---|---|
| **Schema scheme 校验** | 拒 file:// / ftp:// / gopher:// | data: / blob: 也不允许（默认拒非 http/https）|
| **SSRF guardHostname** | loopback / 私网 RFC1918 / link-local / unspecified / multicast | 不 pin IP 到 TCP 连接（可被高速 DNS 翻转攻击；非威胁模型核心）|
| **CheckRedirect 逐跳** | 防 302→localhost 绕过（**batch 1 修的真 bug**）| 跳数硬上限 10 |
| **byte cap 1 MiB** | 防摘要 LLM token 爆炸 + 内存 OOM | 大文章长尾被截断（LLM 看到部分内容也能摘要）|
| **30 秒 fetchTimeout** | 防慢服务器把 ReAct 循环卡分钟 | 真大文件下载会被砍 |
| **utility scenario 严格 422** | 用户 onboarding 完成后 utility 必有配置；无配置 = onboarding 异常 = 友好 422 引导（pre-2026-05-28 redesign 是 web_summary → chat 透明 fallback；删 fallback 后行为更可预测）|
| **WebSearch BYOK→MCP** | 零 HTML scrape，零 placeholder fallback——失败时直接告知用户配 BYOK 或装 MCP | 用户首次用 WebSearch 时大概率没 key + 没装 MCP，会看到 actionable 提示而非"假装搜索 0 结果"；这是有意决策（屎山拯救计划 #4） |
| **WebSearch BYOK 401/403 → MarkInvalid** | 用户立刻看到 search key 失效；不需自己排查 | 联动走 detached ctx 终态写（上游 cancel 不能让 invalid 标记丢失）|
| **JINA_API_KEY 是 env 不是 BYOK config** | 不强制；用户想升速率档自己设 | 没设走免费层（够用）|

---

## 7. 测试覆盖

| 层 | 文件 | 测试数 | 覆盖 |
|---|---|---|---|
| WebFetch | `backend/internal/app/tool/web/fetch_test.go` | 24 | identity / 静态 metadata / schema / Validate × 5 / classifyIP 公网 + 5 类禁区 / guardHostname 名 + IP / Jina 优先 + 直 GET fallback / 双失败 / 取消 / byte cap / Execute SSRF short-circuit × 2 / **CheckRedirect 拒 loopback / 拒私网 / 公网通过 / 10 跳上限**（batch 1 加固）/ truncate / buildSummaryPrompt |
| WebSearch | `search_test.go` | — | identity / 静态 metadata / schema / Validate × 2 / normalize / 4 BYOK provider 各成功 / 401 → ErrAuthFailed + MarkInvalid 联动 / 429 → ErrRateLimited / 5xx → ErrUpstreamHTTP / BYOK 全部缺失 → MCP tier / MCP `{"results":[...]}` / MCP 裸 array / MCP raw-blob 兜底 / MCP 缺失 → ErrMCPSearchUnavailable / 双 tier 都空 → actionable 多行提示 / ctx cancel 中断 BYOK→MCP 切换 |
| Pipeline | `backend/test/web/` | 2 场景 | LLM ↔ tool 端到端：WebFetchBlocksLoopback / WebSearchRejectsEmptyQuery（11s）|

---

## 8. 与其他 domain 的关系

| 关系 | 说明 |
|---|---|
| **model** | WebFetch 走 `ScenarioUtility` —— 2026-05-28 redesign 后与 autoTitle / compaction / search rerank / env-fix 共享 utility 档；`ModelPicker.PickForUtility` 是入口 |
| **apikey** | WebFetch 通过 `KeyProvider.ResolveCredentialsByID`（llmclient.finishResolve 调用）拿摘要 LLM 凭据；WebSearch 通过 `apikeydomain.SearchProviderPriority` + `ResolveCredentials` 拿 BYOK key + `MarkInvalid` 联动 401/403 失效 |
| **infra/llm** | WebFetch 用 `llminfra.Factory.Build` 构造摘要 client，`Generate` helper 跑非流式调用 |
| **pkg/llmclient** | `ResolveUtility(ctx, picker, keys, factory)` —— 严格走 picker.PickForUtility，无 fallback |
| **app/mcp** | WebSearch 通过 `MCPSearchRouter` 端口（web 包持端口）调 MCP search server；main.go 用 `mcpapp.Service` 适配实现该端口 |
| **chat** | 通过 ReAct loop 调度；WebFetch / WebSearch 都 IsReadOnly=true，可同 execution_group 并行 |
| **events / SSE** | 无 — 结果通过 chat.message tool_result block 推流 |
| **errmap** | **3 sentinel 已登记**：`ErrAuthFailed` → `WEBSEARCH_AUTH_FAILED`；`ErrRateLimited` → `WEBSEARCH_RATE_LIMITED`；`ErrUpstreamHTTP` → `WEBSEARCH_UPSTREAM_HTTP`（详 §4.2）。`ErrMCPSearchUnavailable` 是内部 sentinel（不到 handler）|

---

## 9. 演化方向

- **WebFetch 缓存**：CC 有 15min cache（独立 context 里跑摘要避免主对话污染）；Forgify v1 不做（cache invalidation 复杂）
- **WebFetch 多模态**：未来支持图片识别（OCR / 视觉模型）；当前仅文本 / markdown
- **WebSearch 第 5 个 BYOK provider**：marketplace 里出现新的搜索 API 时，加一行 `ProviderMeta` + 在 `apikeydomain.SearchProviderPriority` 排序 + 在 `search_byok.go` 加一个 `searchXxx` 函数即可（比删 SearXNG/Bing scrape 容易得多）
- **MCP search 多 server 支持**：当前 hardcoded `duckduckgo-search`；marketplace 出现第二个搜索类 MCP 时升级到 capability-based discovery
- **WebSearch 缓存 + dedup**：相同 query 短期内用缓存
- **SSRF IP-pinning**：自定义 Dialer 把解析到的 IP 钉到 TCP 连接，关上高速 DNS 翻转的洞（需写 `net.Dialer.Resolver` + 自定义解析器）
- **Image fetch + Vision 摘要**：URL 是图片时走 Vision 模型摘要
