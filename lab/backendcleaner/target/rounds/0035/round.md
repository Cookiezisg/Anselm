---
# Round 0035 — tool/web（波次 2 · M2.3#3）：WebFetch 摘要链重写 + WebSearch 单把 BYOK + 删 MCP tier

类型 / 目标:M2.3 叶子工具第 3 个——`tool/web`。WebFetch 抓网页 + utility 小模型摘要(对齐新地基重写)；WebSearch 用 R0034 搜索配置的单把 key(BYOK);**改判删 WebSearch 的 MCP tier**(用户质疑后认同——MCP 搜索走独立 tool/mcp,WebSearch 不该代理)。

## 核心方针(一句话)
**web = WebFetch(SSRF + Jina + 摘要先行)+ WebSearch(单把显式搜索 key、provider 由 key 隐含、防乱烧钱);无 MCP tier(MCP 搜索走 tool/mcp 平级)、web 零 mcp 依赖。**

## 关键决策
1. **删 WebSearch 的 MCP tier(用户质疑后改判)**:旧三阶 BYOK→MCP→引导。MCP tier 是内置 WebSearch 反过来代理调 duckduckgo MCP——错误抽象:① 冗余(MCP server 工具本就经 tool/mcp 平级暴露给 LLM、直接调)② 凭空让 tool/web(M2.3)依赖 mcp(M3.6)③ 职责越界。**删 search_mcp.go(MCPSearchRouter 整个)+ WebTools 去 mcpRouter 参数**,web 彻底不依赖 mcp。引导文案提"装 duckduckgo MCP"是纯文字、零代码耦合。
2. **WebSearch 单把 BYOK**(R0034 搜索配置):`searchKeys.DefaultSearchKeyID(ctx)` → `keys.ResolveCredentialsByID` → `websearch.IsProvider(provider)` ? switch → searchXxx。**替旧 SearchProviderPriority 自动遍历**(乱烧钱)。provider 由 key 隐含、401→MarkInvalidByID、key 非搜索 provider 返引导。四家(brave/serper/tavily/bocha)HTTP 照搬。
3. **WebFetch 摘要链对齐新地基重写**:`model.Resolve(utility)` → `ResolveCredentialsByID` → `factory.Build` → `llm.Generate`。删旧 `llmclient.ResolveUtility`(残留 pkg 不迁)+ `bundle.Thinking`(M1.3 删 ThinkingSpec、旋钮走 Options)。摘要失败/utility 未配 → 降级返原始内容截断 4KB。
4. **SSRF 双层全保留**:guardHostname(localhost/私网/link-local + DNS rebinding 防护)+ classifyIP + CheckRedirect 每跳重查。本质安全复杂度。
5. **9→5 方法 + danger 工具侧零逻辑(只读 LLM 自报)+ GetUserID→GetWorkspaceID(markInvalid detached ctx)+ MarkInvalid(provider)→MarkInvalidByID(keyID)**。

## 新实现
- `web.go`:`WebTools(picker, keys, factory, searchKeys, log)`(去 mcpRouter)。
- `fetch.go`:WebFetch — SSRF 套件(guardHostname/classifyIP/ssrfCheckRedirect)+ Jina/direct fetch + summarise(新地基链)+ buildSummaryPrompt + truncate。
- `search.go`:WebSearch — 二阶 Execute + runProvider(switch websearch.Provider 常量)+ noBackendMessage + markInvalidIfAuthErr(byID + workspace detached)+ marshalSearchResponse。删 MCPSearchRouter/runMCPSearch/parseMCPSearchResults/removeStr/tryBYOKProvider(遍历)。
- `search_byok.go`:brave/serper/tavily/bocha + doSearchHTTP(sentinel 分类)+ snippet。照搬。
- **删 `search_mcp.go`**(不迁)。

## 测试(全离线)
- `fetch_test` 6:ValidateInput · guardHostname/classifyIP 各地址 · Execute SSRF 拒(localhost/127/192.168/169.254)· 摘要全链(mock Jina httptest + provider=mock 短路 MockClient + PushScript)· 摘要失败降级原始截断。
- `search_test` 7:ValidateInput · 无 key 引导 · key 非搜索 provider 拒 · Brave 全链(httptest + header auth)· Tavily 全链(POST + body auth)· 401→MarkInvalidByID(ak_bad)· limit 截断。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet` 0 · `go test -race -count=1 ./internal/app/tool/web/...` ok(2.0s)。

## 契约
- `domains/web.md` **整篇重写**(DOC-127——旧版 MCP 当"搜索备选物理引擎"/虚构 wire code WEBSEARCH_AUTH_FAIL 等/`web_reference` relation 全删)。新版:SSRF 双层 + 摘要链 + WebSearch 单把 BYOK + **删 MCP tier 论证** + 四家 provider 表 + 测试矩阵 + 决策快照。
- `contract-changes #15`(WebSearch 去 MCP tier、去 provider 遍历、接 SearchKeyPicker、danger 自报)。
- 无新 HTTP 端点 / 无 DB 表 / 无 error code(工具失败软返串)。

## 波次 2 收官
M2.3:#1 filesystem ✅ → #2 search ✅ → 搜索配置 ✅(R0034)→ **#3 web ✅(R0035,删 MCP tier)** → #4 toolset(下一,波次 2 最后一个)。
