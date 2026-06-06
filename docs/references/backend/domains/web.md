---
id: DOC-127
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-06
review-due: 2026-09-01
audience: [human, ai]
---
# Web Tools — 网络抓取（WebFetch）+ 搜索（WebSearch）

> **核心地位**:`tool/web` 给 LLM "上网"的能力——`WebFetch`(抓一个 URL、小模型摘要回答)+ `WebSearch`(用 workspace 选定的搜索 key 搜)。叶子工具适配器(无 domain / store / handler / DDL / HTTP 端点),只实现 `app/tool` 的 5 方法接口。
>
> **WebFetch 灵魂 = SSRF 防护 + 摘要先行**:防 agent 被诱导访问内网;抓到的内容先经 utility 小模型按 prompt 提炼,不返原始 HTML(防灌爆窗口)。
>
> **WebSearch 灵魂 = 单把显式搜索 key(BYOK)**:用 workspace 的 `default_search_key_id`(R0034)选定的**一把** key,provider 由 key 隐含。**无 MCP tier**——搜索 MCP server 经 `tool/mcp`(波次 3)暴露自己的工具、LLM 直接调,WebSearch 不代理。

---

## 1. 物理布局

```
backend/internal/app/tool/web/
├── web.go          # WebTools(picker, keys, factory, searchKeys, log) 装配
├── fetch.go        # WebFetch — SSRF + Jina + 摘要链
├── search.go       # WebSearch — 二阶(BYOK + 引导)
└── search_byok.go  # brave/serper/tavily/bocha 4 家 HTTP 实现
```

无 domain / store / handler / DDL / HTTP 端点。装配器由 host 注入 picker / keys / factory / searchKeys。

---

## 2. WebFetch — 抓网页 + 小模型摘要

参数:`url`(绝对 http/https)+ `prompt`(从页面提取什么)。

流程:

```
① guardHostname(host)        ← SSRF 第一层:拒 localhost / 私网 / link-local，DNS 解析后验所有 IP（防 rebinding）
② fetchContent               ← Jina reader(r.jina.ai → 干净 markdown) 优先，失败兜底直接 GET；
                                fetchClient.CheckRedirect 每跳重跑 guardHostname（防 302 → 内网）
③ 截断 1 MiB
④ summarise                  ← utility 小模型按 prompt 提炼 content → 返摘要（不返原始 HTML）
```

### 2.1 SSRF 双层防护(本质安全复杂度,全保留)

- **guardHostname**:`localhost`/`ip6-localhost` 特判;IP 直接 `classifyIP`;域名 `net.LookupIP` 后**验证所有解析 IP**(任一落入禁区即拒——防 DNS rebinding)
- **classifyIP** 禁区:loopback / private(10./172.16./192.168.) / link-local(169.254.) / unspecified(0.0.0.0) / multicast
- **CheckRedirect**:重定向每跳重跑 guardHostname,≥10 跳停(防公网 URL 302 跳内网)

### 2.2 摘要链(对齐新地基重写)

```go
ref   := model.Resolve(ctx, ScenarioUtility, nil, picker)   // {APIKeyID, ModelID, Options}
creds := keys.ResolveCredentialsByID(ctx, ref.APIKeyID)     // {Provider, Key, BaseURL, APIFormat}
client,_ := factory.Build(Config{creds.Provider, creds.APIFormat, ref.ModelID, creds.Key, creds.BaseURL})
out := llm.Generate(ctx, client, Request{ModelID, Key, BaseURL, Options: ref.Options, Messages:[summaryPrompt]})
```

- 删旧 `llmclient.ResolveUtility`(残留 pkg 未迁)+ `bundle.Thinking`(M1.3 删 ThinkingSpec,旋钮走 `ModelRef.Options`)
- **摘要失败降级**:utility 模型未配(`ErrNotConfigured`)/ LLM 出错 → 返**原始内容截断 4KB** + 说明,不硬失败(用户至少拿到网页内容)

---

## 3. WebSearch — 单把搜索 key(BYOK)

参数:`query` + `limit`(默认 10,硬上限 30)。返 JSON `{query, source, results:[{title,url,snippet}], truncated}`。

二阶逻辑:

```
① BYOK：keyID, ok := searchKeys.DefaultSearchKeyID(ctx)         ← R0034 SearchKeyPicker（workspace 选定的一把）
     ok → creds := keys.ResolveCredentialsByID(ctx, keyID)
          websearch.IsProvider(creds.Provider) ?
             switch creds.Provider → searchBrave/Serper/Tavily/Bocha(creds.BaseURL, creds.Key, query, limit)
             401/403 → keys.MarkInvalidByID(keyID)               ← 标该 key 失效（detached ctx 保 workspace id, §S9）
             return JSON {query, source, results, truncated}
          否则（key 不是搜索 provider）→ 返"这把 key 不是搜索后端"引导
② 引导文案：「配一个搜索类 API key（Brave/Serper/Tavily/Bocha）并设为 workspace 默认搜索 key；
            或装搜索类 MCP server（如 duckduckgo），它作为独立工具直接可调」
```

### 3.1 四家 provider(`search_byok.go`,照搬)

| provider | 方法 | 认证 | 响应解析 |
|---|---|---|---|
| `brave` | GET `/web/search` | `X-Subscription-Token` header | `web.results[].{title,url,description}` |
| `serper` | POST `/search` | `X-API-KEY` header | `organic[].{title,link,snippet}` |
| `tavily` | POST `/search` | `api_key` in body | `results[].{title,url,content}` |
| `bocha` | POST `/web-search` | `Authorization: Bearer` | `data.webPages.value[].{name,url,snippet}` |

`doSearchHTTP` 统一发送 + 状态分类:401/403 → `ErrAuthFailed`、429 → `ErrRateLimited`、其他非 2xx → `ErrUpstreamHTTP`(`errors.Is` 匹配)。

### 3.2 为什么单把 key = 防乱烧钱

旧 WebSearch 持 `SearchProviderPriority=[brave,serper,tavily,bocha]` **自动遍历**:配了多家就挨个试,烧钱。新版用 workspace 显式选定的**一把** key(R0034 搜索配置),provider 由 key 隐含,**零遍历**。四家仍全支持,只是同时只用你选的那把。详见 `domains/websearch.md`。

### 3.3 为什么没有 MCP tier(改判删除)

旧 WebSearch 有第三档"MCP tier":没配 BYOK key 时,内置 WebSearch **反过来代理调** duckduckgo MCP server。这是错误抽象:

- **MCP 的正道**:连接的 MCP server,其工具经 `tool/mcp`(波次 3 M3.7)**平级暴露**给 LLM、LLM 直接调
- WebSearch 再代理一次 = 冗余(同一搜索能力两个入口)+ 凭空让 `tool/web`(M2.3)依赖 `mcp`(M3.6)+ 职责越界

**删 MCP tier**:`tool/web` 彻底不依赖 mcp。引导文案里提"可装 duckduckgo MCP"是**纯文字**(告诉用户有免费选项),不是代码调用——零耦合。

---

## 4. 跨域接线

| 接线 | 当下 | 实接 |
|---|---|---|
| 装入 `Toolset.Resident` | host 调 `WebTools(...)` | chat M5.2 host 组装 |
| `picker`(utility 摘要) | `model.ModelPicker` | workspace.Service(已实现) |
| `keys` | `apikey.KeyProvider` | apikey.Service(已实现) |
| `searchKeys` | `websearch.SearchKeyPicker` | workspace.Service(R0034 已实现) |
| `factory` | `llm.Factory` | server boot M7 |
| MCP 搜索 | — | 独立 `tool/mcp`(M3.7),与 WebSearch 无关 |

---

## 5. 测试矩阵(全离线)

- **fetch_test**:`ValidateInput`(空 url/prompt、非 http scheme) · `guardHostname`/`classifyIP` 各地址(loopback/private/link-local/unspecified/multicast 拒、公网过) · Execute SSRF 拒绝(localhost/127.0.0.1/192.168/169.254) · Execute 摘要全链(mock Jina httptest + provider="mock" 短路 MockClient) · 摘要失败降级返原始截断
- **search_test**:`ValidateInput` · 无 key 引导 · key 非搜索 provider 拒 · Brave 全链(httptest + header auth) · Tavily 全链(POST + body auth) · 401 → `MarkInvalidByID` · limit 截断

---

## 6. 决策快照

- **WebFetch 摘要先行**:抓到内容用 utility 小模型提炼,不返原始 HTML(防灌爆窗口);失败降级原始截断
- **SSRF 双层全保留**:hostname guard + DNS rebinding 防护 + 重定向每跳重查——本质安全
- **WebSearch 单把 key**:R0034 搜索配置 → 显式选一把、provider 隐含、防乱烧钱(替旧 4-provider 自动遍历)
- **删 MCP tier**:MCP 搜索走独立 `tool/mcp` 平级工具,WebSearch 不代理;`tool/web` 零 mcp 依赖
- **danger 工具侧零逻辑**:两工具只读,LLM 逐次自报
- **无 HTTP 端点 / DDL / 错误码**:工具失败软返 tool-result 串(SSRF 拒、抓取失败、搜索失败、无 key 引导皆为字符串),永不冒泡 HTTP
