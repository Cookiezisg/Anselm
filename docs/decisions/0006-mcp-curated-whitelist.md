---
id: DOC-042
type: decision
status: active
owner: @weilin
created: 2026-06-20
reviewed: 2026-06-20
review-due: 2099-12-31
audience: [human, ai]
---

# 0006 — MCP 市场 curated 白名单 + 「纯代码 vs 厂商业务步骤」可用性判据

## 背景

市场原样列出内嵌 registry snapshot 的全部 99 个 server、全标可装，但其中很多装上就坏：`Plan`（`domain/mcp/registry.go`）对「remote 且无可填 header」的 OAuth-only server **静默建一个零认证连接**——UI 不报错、看着装好了，真调用才 401。要让「每个标注可用的 server 都真能用」，必须先判定每个 server 到底能不能被我们做成可用。

经一次系统调研（每 server 一个 agent 调查 + 2 轮对抗 cross-check，共 297 个 agent；结论见 [`archive/mcp-oauth-support`](../archive/mcp-oauth-support/README.md)）按一条判据分类：

**判据 = 纯代码 vs 厂商业务步骤。** 写一套完整 MCP OAuth 2.1 + PKCE + DCR 客户端算「纯代码」→ 做；需要**我们（vendor）**去厂商控制台注册 OAuth app / 过安全审核（如 Google CASA）/ 进 allowlist / 架带域名+证书的托管 proxy 算「业务步骤」→ 不做。**终端用户**自己粘 token、或在浏览器点「同意」不算业务步骤。remote OAuth 的分界 = 其授权服务器是否支持 **DCR**（RFC 7591 运行时自注册）。

结果（99 个）：`works-now` 59（stdio 静态 env / remote 已带静态 header）+ `static-token` 25（用户粘 PAT/apikey 接成静态 header）+ `oauth-dcr` 10（支持 DCR）= **94 可用**；`oauth-app-registration` **5 永不做**（figma 进 allowlist、vercel 审客户端、box 注册 app、MS EnterpriseMCP / MS sentinel 走 Entra 不支持 DCR）。

## 决策

**市场改成 curated 白名单**：`infra/mcp` 的 `CuratedCatalog` 装饰 `GitHubRegistrySource`，数据 `catalog.json`——只暴露白名单 slug（List/Get 按 slug 过滤，非白名单 `Get` → `MCP_REGISTRY_NOT_FOUND`、不可装），并对每条套 **auth 覆盖**钉死已核验的安装+认证。

**分两档落地：**

- **档 1（本 ADR 落地）= 84 个**（works-now + static-token），不需要 OAuth 客户端。白名单 + 覆盖**结构性根治「静默零认证」**：静态 token **remote** 注入 `Authorization: Bearer {TOKEN}` header + 必填 env（→ `Plan` 暴露 → `missingEnv` 强制 → 不会无认证装上）；静态 token **stdio** 把 token env 标必填、或钉死启动 package（上游裸名解析不出 runtime 时，如 Snyk CLI `snyk mcp -t stdio`）。
- **档 2（后续）= 10 个 oauth-dcr**：待新建 MCP OAuth 2.1 + PKCE + DCR 客户端（桌面 loopback 回调 + 经 Flutter 通道拉浏览器 + token 加密存储/自动刷新，规格见 archive/mcp-oauth-support §1–§5）后再纳入白名单。
- **永不做 = 5 个 oauth-app-registration**：需厂商业务步骤。

覆盖永远复用现有 `Env`/`Headers` 的 `config_enc` 加密通道——**无新明文列、无 domain 层改动**（纯 infra decorator + 内嵌 `catalog.json`）。

## 取舍

**为何不选：**

- **保留全量直通 + 运行时再报错**：放弃。与「确保每个标注可用的真可用」直接相悖；静默零认证是最差 UX。
- **每个 server 一个配置文件（84 个文件）**：放弃。单个数据驱动的 `catalog.json` 更干净、好测、好维护；个别需特殊安装逻辑的（钉 package）在同一覆盖模型里表达即可。
- **catalog 自带全部安装数据、彻底替换 `GitHubRegistrySource`**：放弃。装饰器复用上游 package/version（保鲜）+ 内嵌 snapshot 兜底离线，**只覆盖认证**；安装数据仍由上游/snapshot 供，catalog 只做白名单 + 认证矫正。代价：上游若改了某 works-now 的包形态，catalog 不拦（由 `TestCuratedCatalog_AllEntriesPlannable` 守可解析性兜底）。
- **现在就做那 5 个 oauth-app-registration**：放弃。是注册 app + 过审 + 可能托管 proxy 的公司/法务/预算级事，非纯代码，且 Google/MS 的 DCR 缺失是其刻意产品决策、不会变。
- **把 oauth-dcr 10 个也推迟成「永不做」**：放弃。它们支持 DCR = 纯代码可解，只是工作量大，单列档 2 而非砍掉。
