---
id: DOC-112
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-07
review-due: 2026-09-01
audience: [human, ai]
---
# MCP Domain — 外部生态协议网桥（容器实体 + 常驻进程）

> **核心地位**：MCP 是 Forgify 接外部现成生态（GitHub / Slack / Notion …）的**协议网桥**。底层用官方 [`github.com/modelcontextprotocol/go-sdk`](https://github.com/modelcontextprotocol/go-sdk) v1.6.0（JSON-RPC over stdio / HTTP）。**每个 server 是一个「容器实体」**——一个 server 里装着 N 个工具——以**常驻进程**运行、按 workspace 隔离、进程模型镜像 [handler](handler.md)（单例进程池 / boot / reconnect / shutdown）。

---

## 1. 定位：容器实体 + 进程网桥

- **server = 容器实体**：不像 function/handler 一个实体一个能力，**一个 mcp server 携带它自报的全部工具**。catalog 报「server 名 + 描述 + 全部工具名」，每个工具再各自落成一个独立的 LLM 懒加载工具（见 §6）。
- **常驻进程**：每个 stdio server 对应一个宿主机子进程，长驻不杀；remote（sse / streamable-http）则是一条长连接。生命周期镜像 handler——单例进程池、crash 重连、改 config 重连、手动 reconnect（「重置按钮」）。
- **workspace 隔离**：server 是用户数据，每个 workspace 一套已装清单，物理隔离（D2）。**唯独 market（§4）是全局公共**——那是 GitHub 的货架，不是用户数据。

---

## 2. 物理模型：一张 `mcp_servers` 表

整个域只有**一张表**：已装 server 的配置清单。无调用审计表、无健康历史表（均已砍，见 §10）。

### `mcp_servers`（`mcp_`，软删 D1）

```go
// One installed MCP server = one container of tools, one resident connection.
// config_enc holds AES-GCM ciphertext of {env, headers}; the domain.Server the
// rest of the system sees carries PLAINTEXT Env/Headers — crypto is sealed in
// the store layer (an internal serverRow encrypts on write, decrypts on read).
type Server struct {
    ID          string         `db:"id,pk" json:"id"`                       // mcp_<16hex>
    WorkspaceID string         `db:"workspace_id,ws" json:"-"`             // D2 物理隔离
    Name        string         `db:"name" json:"name"`                     // 工作区内唯一短名（LLM/path 用）
    Description string         `db:"description" json:"description"`
    Transport   string         `db:"transport" json:"transport"`           // stdio | sse | streamable-http
    Runtime     string         `db:"runtime" json:"runtime,omitempty"`     // node|python|docker|dotnet，仅 stdio
    Command     string         `db:"command" json:"command,omitempty"`     // stdio 启动命令
    Args        []string       `db:"args,json" json:"args,omitempty"`      // JSON
    URL         string         `db:"url" json:"url,omitempty"`             // 仅 remote（sse / streamable-http）
    Env         map[string]string `db:"-" json:"-"`                        // 明文（落库前进 config_enc）
    Headers     map[string]string `db:"-" json:"-"`                        // 明文（落库前进 config_enc）
    TimeoutSec  int            `db:"timeout_sec" json:"timeoutSec"`        // CallTool 超时
    Source      string         `db:"source" json:"source"`                 // registry | manual | import
    RegistryID  string         `db:"registry_id" json:"registryId,omitempty"` // 装自哪个 registry slug
    CreatedAt   time.Time      `db:"created_at,created" json:"createdAt"`
    UpdatedAt   time.Time      `db:"updated_at,updated" json:"updatedAt"`
    DeletedAt   *time.Time     `db:"deleted_at,deleted" json:"-"`
}
```

- **`config_enc`（物理列，不在 struct 直接出现）**：store 层把 `{env, headers}` 合成一个 JSON、过 [`infra/crypto`](../../../concepts/architecture.md) AES-GCM 加密成单列 `config_enc`；读时解密回填明文 `Env`/`Headers`。**domain 永远拿明文，加密细节不泄漏到 domain/service**（与 handler `config_encrypted` 同手法）。
- **唯一索引 `idx_mcp_ws_name`**：`UNIQUE(workspace_id, name) WHERE deleted_at IS NULL`——短名在工作区内唯一，故可作 HTTP path key。

---

## 3. 进程生命周期（镜像 handler）

**一个 mcp server = 一个常驻连接**，由进程池单例托管。`id` 全局唯一，**跨 workspace 不碰撞**，故进程池是扁平 `map[mcp_id]*conn`（不嵌 workspace 维度）。

| 动词 | 触发 | 行为 |
|---|---|---|
| **Boot** | 开机 per-workspace | 读 `mcp_servers` 表，**并发**连接所有已装 server |
| **reconnect** | crash 自愈 / 改 config / 手动 `reconnect_mcp` 工具 / `:reconnect` 端点 | 优雅断旧连接 → 用最新 config 重连（「重置按钮」，对齐 handler `restart`）|
| **Shutdown** | 退出软件 | 优雅关全部连接 / 子进程 |

> **为何需要手动 reconnect**：crash 重连救不了「连接活着但状态坏了」（远端掐断、token 过期、子进程卡死）——`reconnect_mcp` 是常驻连接的人工重置闸，镜像 handler 的 `restart_handler`。

### transport 三态

| transport | 连接方式 | 说明 |
|---|---|---|
| `stdio` | 子进程由 [sandbox](sandbox.md) `SpawnLongLived` 拉起、归 sandbox 管；go-sdk 用 handle 的 stdin/stdout 经 `IOTransport` 接 JSON-RPC | 本地包（node/python/docker/dotnet）|
| `sse` | go-sdk `SSEClientTransport` 连 `url` | remote server |
| `streamable-http` | go-sdk `StreamableClientTransport` 连 `url`；`headers`（Bearer token 等）经自定义 `http.Client` 注入 | remote server |

---

## 4. Market：GitHub MCP Registry 全量

market 对接 **GitHub MCP Registry**（`https://api.mcp.github.com/v0/servers`，**99 个 server**）——逛货架、一键装。

- **全局公共，不按 workspace 隔离**：这是 GitHub 的货架（公开元数据），非用户数据，所有 workspace 共享同一份。
- **三级兜底**：`go:embed` 内嵌 snapshot（离线永远可用）→ `~/.forgify/cache/mcp-registry.json`（在线刷新落盘）→ 回落 embed。
- **覆盖率**：99 个 = 38 remote + 38 node + 11 python + 9 docker + 3 .NET（其中 2 个 .NET 有 npm 备选 → 归 node），**95+ 可装**。

### 安装：`InstallFromRegistry`

遍历 registry entry 的 `packages` 数组，按 **runtime 优先级 node > python > docker > dotnet**（轻量优先）挑最优 package（或 remote url）；校验必填 env；sandbox `EnsureEnv` 装对应 runtime；写表（加密 env/headers）；连接。

---

## 5. catalog 集成：容器报全部工具名

mcp server 是容器实体，所以它在 [catalog](catalog.md) 的呈现与单能力实体不同：**报「server 名 + 描述 + 全部工具名」**。

- [`catalog.Item`](catalog.md) 为此新增 `Members []string` 字段：mcp source 把该 server 自报的**全部工具名**塞进去（只列名、不列工具描述、不截断）。
- 只报 **ready / degraded** 的 server（连不上的不进货架，免得 LLM 调一个死工具）。

---

## 6. 工具面：4 固定 + N 动态

### 6.1 四个固定系统工具（resident，常驻）

| 工具 | 入参 | 行为 / 返回 |
|---|---|---|
| `list_mcp_marketplace` | — | 逛市场，返回 `name + 描述 + runtime + 必填 env` |
| `install_mcp_server` | `name`, `env` | 装一个，返回 `status + tools`（该 server 的工具名列表）|
| `uninstall_mcp_server` | `name` | 卸一个 |
| `reconnect_mcp` | `name` | 重连（重置闸）|

### 6.2 动态工具（每个已装工具一把，懒加载）

- 每个已装 server 的**每个工具** = 一把独立的 lazy 工具。
- **命名 `mcp__<server>__<tool>`**：双下划线分隔（LLM tool 名不许带冒号）。
- **`Parameters` 原样透传** server 自报的 `inputSchema`；`Execute` 转发到该 server 的 `CallTool`。
- 进 [`search_tools`](tool.md) 检索池、**不进 Overview**（容器工具太多会撑爆提示词），靠 §5 catalog 条目引导 LLM 去搜。

> **danger 完全由 LLM 逐次自报，工具侧零 danger 逻辑 / 零 danger 字段**（S18：无中央权限门控，危险靠 LLM 自报 + 逐次确认）。

---

## 7. 安装格式与互操作

- **registry 装**：`POST /api/v1/mcp-registry:install`（slug + env）或 `install_mcp_server` 工具。
- **手动 upsert**：`PUT /api/v1/mcp-servers/{name}`（直接给 command/args/env/url/transport/runtime）。
- **import**：`POST /api/v1/mcp-servers:import` 吃 **Claude Desktop `mcp.json` 片段**（`?overwrite=true` 覆盖同名）。`mcp.json` 仅作 import / export 互操作格式，**不是主存储**（主存储是 `mcp_servers` 表）。

---

## 8. HTTP 端点

> N5：**server 用短名**（工作区唯一）作 path key；**registry 用完整 slug**（slug 含 `/`，故放在 body）。

| 方法 | 路径 | 动作 |
|---|---|---|
| GET | `/api/v1/mcp-servers` | 列已装 server（实时 status）|
| GET | `/api/v1/mcp-servers/{name}` | 单个 server status |
| GET | `/api/v1/mcp-servers/{name}/stderr` | stderr 尾部（诊断）|
| PUT | `/api/v1/mcp-servers/{name}` | 手动 upsert（body: command/args/env/url/transport/runtime/timeoutSec）|
| DELETE | `/api/v1/mcp-servers/{name}` | 软删（断连接 + D1）|
| POST | `/api/v1/mcp-servers/{name}:reconnect` | 重连（重置闸）|
| POST | `/api/v1/mcp-servers/{name}/tools/{tool}:invoke` | 直接试调用一个工具，绕过 LLM（body: args）|
| POST | `/api/v1/mcp-servers:import` | 吃 Claude Desktop mcp.json 片段（`?overwrite=true`）|
| GET | `/api/v1/mcp-registry` | 列市场全量（99 个）|
| POST | `/api/v1/mcp-registry:install` | 装一个（body: 完整 slug + env）|

---

## 9. 跨域集成

- **sandbox**：stdio 子进程经 `SpawnLongLived` 拉起、归 sandbox 管；`EnsureEnv` 装 runtime（node/python/docker/dotnet）。
- **crypto**：`config_enc`（env + headers）经 `infra/crypto` AES-GCM，封在 store 层。
- **catalog**：mcp 是 7 个 CatalogSource 之一；报 server 名 + 描述 + 全部工具名（`Item.Members`）。
- **tool / toolset**：4 固定工具常驻；N 动态工具进 `search_tools` 检索池。
- **workflow**：`tool` 节点可引用 mcp 工具（`mcp__<server>__<tool>`）。
- **apikey**：server env 常引用密钥（用户填，加密存）。

---

## 10. 砍掉的旧机制

以下旧物理事实**已不存在**，文档不再描述：

- **`mcp_calls` 表（`mcl_`）/ `mcp_health_history` 表（`mch_`）**：调用审计 + 健康历史全删。
- **HTTP**：`/{name}/health-history`、`:health-check`、registry `GET /{name}`——全删。
- **`Search`（LLM rerank 检索）**：删。
- **LLM 工具**：`call_mcp_tool` / `search_mcp_tools` / `get_execution` / `search_executions`——全删（动态工具直接落成 `mcp__<server>__<tool>`，无需中间检索工具；审计随表删）。
- **硬编码 curated registry（24 个）**：删，改对接 GitHub Registry 全量（99 个）。
- **`mcp.json` 作为主存储**：降级为 import / export 互操作格式。

---

## 11. 错误字典

> 所有 sentinel 经 `errorsdomain.New(kind, code, msg)`（Kind → HTTP status + 稳定 wire code，S20）。工具失败软返 tool-result 串（不冒泡 HTTP）；下表是 HTTP 端点冒泡的 domain 错误。

| Sentinel | Wire Code | HTTP | 场景 |
|---|---|---|---|
| `ErrServerNotFound` | `MCP_SERVER_NOT_FOUND` | 404 | 短名查不到已装 server |
| `ErrServerNotConnected` | `MCP_SERVER_DOWN` | 503 | 连接断 / 子进程崩，暂不可用 |
| `ErrToolNotFound` | `MCP_TOOL_NOT_FOUND` | 404 | server 未自报此工具 |
| `ErrToolCallFailed` | `MCP_RPC_ERROR` | 502 | 上游 server 返回错误 JSON-RPC |
| `ErrToolCallTimeout` | `MCP_TOOL_TIMEOUT` | 504 | CallTool 超 `timeout_sec` |
| `ErrNameConflict` | `MCP_NAME_CONFLICT` | 409 | 短名在工作区内已占用 |
| `ErrInstallFailed` | `MCP_INSTALL_FAILED` | 502 | 装包 / 连接失败 |
| `ErrEnvMissing` | `MCP_ENV_MISSING` | 422 | 缺必填 env |
| `ErrRegistryEntryNotFound` | `MCP_REGISTRY_NOT_FOUND` | 404 | slug 不在 registry |
| `ErrNoRunnablePackage` | `MCP_NO_RUNNABLE_PACKAGE` | 422 | registry entry 无可装 package（无支持的 runtime / remote）|
