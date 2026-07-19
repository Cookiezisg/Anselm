---
id: WRK-035
type: working
status: active
owner: @weilin
created: 2026-06-21
reviewed: 2026-06-21
review-due: 2026-09-19
audience: [human, ai]
landed-into:
---

# MCP 设置页重做 —— 后端对齐 + 市场/已装设计

> 来源：3 路并行后端调研 + 逐路反核验（catalog/市场 · install 流程 · 已装运行态），全部对到 `backend/internal/…:行`。
> 用法：demo「MCP」页（`demo/features/settings/{data,sea}.js`）重做的设计依据 + 真前端对接契约。
> 设计要点（用户定）：标题就叫 **MCP**（去「与市场」）；市场 = 带搜索的**双列框卡**（项目图标 + 描述）；已装 = **卡片 + 运行信息**。

## 后端事实（已核验到代码行）

### catalog / 市场来源 —— ⭐图标的关键
- catalog = `backend/internal/infra/mcp/catalog.json`（`//go:embed`），**96 条**，每条仅 `{slug, auth?, local?, prerequisite?}`。slug 是官方 reverse-DNS 名（`io.github.<owner>/<name>`、`com.<co>/<name>`）。
- **live registry feed = GitHub MCP Registry `https://api.mcp.github.com/v0/servers?limit=100`**（`infra/mcp/registry.go:20`），离线兜底 `registry_snapshot.json`。
- **图标 + 富元数据全在 registry feed 的 `x-github`**：`preferred_image`/`owner_avatar_url`（= 图标，GitHub 头像）、`display_name`、`stargazer_count`、`primary_language`、`license`。后端 `RegistryEntry`（投影给前端的 DTO）**本身无 icon/displayName/category**——但前端可直接读 registry（或后端补投影）拿到。**demo 已按 96 slug 抓 registry，命中 95**，烤入真图标/星数/语言。
- 前端 HTTP `GET /api/v1/mcp-registry` 返完整裸 `RegistryEntry[]`（`handlers/mcp.go:255`），**含 `remotes[].auth`**——前端有可靠显式信号判 oauth，无需推断。**无搜索/分页端点**（一次返全 96）→ 搜索 = 前端客户端过滤。**无 per-name 详情端点**。

### auth 7 类（96 总，demo 徽对齐）
| auth | 数 | 判据 | 前端徽 / 装机 |
|---|---|---|---|
| direct（works-now + 零表单 stdio） | 49 | 无 auth/local（+ 2 个钉 package 无 token 的 stdio） | 无徽 · 免配置直装 |
| token（remote + stdio static-token） | 24 | `auth.transport remote` 或 stdio 带 token env | 「需 Token」· 填 token |
| oauth-DCR | 18 | `auth.transport=oauth` 无 clientIdEnv/env | 「OAuth」· 零表单 → 浏览器授权 |
| byo-client | 3 | oauth + clientIdEnv（Box/MS-Enterprise/MS-Sentinel） | 「自建应用」· 填 client_id |
| oauth-url | 1 | oauth + env（Glean，`GLEAN_MCP_URL`） | 「OAuth·URL」· 填实例 URL |
| local | 1 | `local`（figma-dev-mode，`127.0.0.1:3845`） | 「本地」 |

- **blocked = 缺席**：被排除的 server 不在 catalog（唯二真排除：figma-remote + getguru）→ 市场里全部可装，无 blocked 态。
- **`prerequisite`（4 条：unity/dbhub/imagesorcery/azure-foundry）**：可装但需前置 → 显「需前置」。

### install
- 统一端点 `POST /api/v1/mcp-registry:install` body `{name, env}` → **201**。表单 = entry 的 `env: EnvVar[]{name,description,isSecret,required}`。
- **OAuth 是请求内同步阻塞**：拉系统浏览器 + `127.0.0.1:47100` loopback，阻塞到授权完（≤5min）才返 201。前端客户端超时须 ≥5min；**不轮询/不订 SSE**。
- **无安装进度**（G2 缺口）：REST `:install` 同步挂着→201/错误，只能 spinner；进度回调仅 chat-agent 装 stdio 时走 messages SSE。完成事件 `mcp.installed` 走 notifications SSE。
- 错误：缺 env `MCP_ENV_MISSING`(422,`details.missing`)、`MCP_NO_RUNNABLE_PACKAGE`(422)、OAuth 族 `MCP_OAUTH_*`(502/401)。

### 已装 server 运行态
- `GET /api/v1/mcp-servers` → `ServerStatus[]`（无分页）。**ServerStatus** = `{id, name, status, connectedAt, lastError, lastErrorAt, consecutiveFailures, totalCalls, totalFailures, tools}`。
- **status 5 态**：`disconnected / connecting / ready / degraded / failed`。degraded = 连续失败 ≥3 且曾 ready；IsCallable = ready|degraded（仅此 tools 非空）。
- **无 enabled/disabled 概念**；**无 auth_status/token_expiry 字段**（OAuth 过期靠 status=failed + lastError `MCP_OAUTH_REAUTH_REQUIRED` 推断）。
- **缺口**：`ServerStatus` 不含 transport/source/runtime/url（在 `Server` 表、无 GET 回显）→ demo 自带 transport 展示。
- 动作端点：`DELETE /{name}`(204) · `POST /{name}:reconnect`(200) · `GET /{name}/calls`（台账）· `GET /{name}/stderr` · `POST /{name}/tools/{tool}:invoke`（试调）。
- **⚠️ reconnect 救不了 OAuth 过期**：`:reconnect` 只用现存 refresh token，**无任何端点能重拉浏览器授权**——refresh 也失效时只能 `DELETE` + 重 `:install`。故 demo 失败-OAuth 卡显「**重新授权**」（语义 = 卸载重装），非「重连」。
- tool（ToolDef）仅 `{serverName, name, description, inputSchema}`，**无 danger 级**（HTTP 面 tool 列表显不出危险级）。

## demo 设计落地
- **标题 MCP**（rail label + 页头去「与市场」）。
- **市场**：搜索框（前端过滤 name/desc/lang）+ `.mcp-grid` 双列框卡。卡 = 真图标(`<img>` GitHub 头像) + 名 + 2 行描述 + auth 徽（direct 无徽）+ `★stars · 语言` + 安装/授权安装；prereq 显「需前置」。
- **已装**：`.mcp-inst` 卡 + 运行信息——status-dot 5 态配色、`N 工具 · M 调用 · K 失败`、`transport · 连接时间`、错误行（红）；动作随态（失败-OAuth → 重新授权；连接中只删除；余 重连/日志/删除）。
- demo 数据（`data.js`）：34 市场（catalog 真 slug + registry 真元数据，覆盖全 auth + prereq）+ 6 已装（覆盖 5 态 + OAuth 重授权）。图标走远程 URL（demo 在浏览器跑、有网；真 Flutter 端另做缓存）。
