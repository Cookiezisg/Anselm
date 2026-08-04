---
id: DOC-020
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# MCP

## 1. 定位

MCP Server 是连接外部工具生态的容器实体。它可以是 Sandbox 管理的 stdio
常驻进程，也可以是 SSE / streamable HTTP remote；连接后缓存 tools/list，
并把每个工具投影为 workspace dynamic tool。

```text
encrypted Server config
→ resident connection
→ cached ToolDef[]
→ dynamic mcp__server__tool
→ Call audit
```

## 2. 配置与运行态

Server 明文 domain config 包含 Env、Headers 与 OAuth credential bundle；store
将三者一起加密到 `config_enc`，不设明文 secret 列。

连接状态只在内存：

```text
disconnected → connecting → ready
                         ↘ failed
ready → degraded
```

`ready|degraded` 可调用。连续调用失败可进入 degraded；连接失败进入 failed。
每个 Server 至多一个 live client/process，Boot 在各 workspace 最佳努力重连，
`:reconnect` 原子替换连接，Shutdown 关闭全部实例。

Stdio 由 Sandbox `EnsureEnv` + `SpawnLongLived` 管理进程，MCP client 只接管协议
管道。stderr 写有界 ring buffer。Remote 使用配置的 URL/headers 或 OAuth
RoundTripper。

## 3. 安装与 Plan

安装入口：

- Registry install：从 curated registry item 选择可运行 package/remote；
- Manual PUT：直接 upsert 一个 Server；
- Import：导入 Claude Desktop 风格配置，可选择覆盖。

`POST /mcp-registry:plan` 无副作用返回：

- transport 与 runtime；
- OAuth 是否需要；
- required/secret env fields；
- prerequisite。

Package 选择按轻量 runtime 优先：node、python、docker、dotnet；无可运行 package
时使用 remote。只有 Required env 缺失才阻断；args/header/URL 中的 credential
placeholder 会被提升为所需 env。缺失时返回 `MCP_ENV_MISSING`，其
`details.missing` 保留精确变量名；进入 chat loop 后会以可行动的纯文本形式浮出，不能只显示
一个无上下文的“安装失败”。

`install_mcp_server` 是持久化外部能力安装，不是只读的 plan：它可能写入 server 配置、启动常驻进程
或建立外部连接，并保存加密凭证。因此工具具有不可绕过的静态 `dangerous` 下限；即使模型自报
`safe`/`cautious`，也必须先经过 Chat HumanLoop 的 action-time 用户批准，不能由 skill 的
`allowed-tools` 或 conversation `approve_always` 预授权绕过。批准句必须明确说明持久化配置、常驻
进程/外部连接与新增能力/加密凭证；缺少 env 时，批准后仍只执行无副作用的校验并返回
`MCP_ENV_MISSING`，不得落半安装行。

`uninstall_mcp_server` 同样具有不可绕过的静态 `dangerous` 下限：它会停止常驻进程并永久删除持久化
server 配置，使动态工具立即不可用；没有 MCP 面板恢复入口。它必须先经过 action-time HumanLoop
批准，不能被 skill 或 `approve_always` 绕过。参数应使用安装回执返回的已安装 server name（例如
`context7`）；实现同时接受对应的 marketplace registry name 作为确定性别名，避免模型因名称格式猜测
而重复调用。找不到名称时应诚实失败，不由模型自行换名重试。

市场使用 curated allowlist 覆盖 registry 数据源。Registry 声明仍是 package、
env description 与 required flag 的基础；overlay 只修正可运行/认证机制，不在
主仓文档复制易漂移的条目数量或供应商操作步骤。取舍见
[`ADR 0006`](../../../decisions/0006-mcp-curated-whitelist.md)。

## 4. Remote OAuth

支持 discovery + DCR 的 remote 使用 OAuth 2.1：

1. 从 401 challenge 发现 protected resource metadata；
2. 发现 authorization server；
3. DCR 注册 public client，或读取用户提供的 client ID/secret；
4. 使用 PKCE S256、state 与 resource audience 构造授权；
5. 打开系统浏览器并在 loopback callback 收 code；
6. 交换 token，加密持久化。

TokenSource 在请求前注入 Bearer，临过期时 refresh 并重存。Refresh 不可用返回
`MCP_OAUTH_REAUTH_REQUIRED`。Resource metadata 只接受与 Server 同 host 的
resource，避免 audience 改向。

需要固定 redirect URI 的自带客户端优先使用 loopback 端口 47100，占用时退
随机端口。Per-tenant URL、client ID/secret 和 scope override 都通过 Plan
显式收集，不硬编码用户凭证。

## 5. 工具与调用

Server tools 合成为 `mcp__<server>__<tool>`。动态工具只在本 workspace 的
Server 可调用时出现，并可通过 `search_tools` 发现；Agent 使用
`mcp:<server>/<tool>` 预绑定挂载。

所有入口汇入 `CallTool`：

- Chat dynamic tool；
- Agent mount；
- Workflow action；
- HTTP manual invoke。

Call 使用统一 wall-clock，写状态 `ok|failed|cancelled|timeout`、输入/输出、
conversation/tool-call/flowrun/node/iteration 溯源。List 不带大 output，单读
提供完整详情。Server 存在但不可调用时返回 server-down，而不是 tool-not-found。

MCP tool result 中的媒体先成为 Attachment/MediaRef，再由 Chat、Agent 或
Subagent 的统一消费咽喉按模型能力展开。

## 6. 投影与契约

- Catalog：Server 容器 + tool members；
- Search：Server 与 tool anchors，公开 identity 使用 Server name；
- Relation：Agent/Workflow equip 与 Conversation touch；
- Registry：curated install surface；
- Mention：Server 状态与工具概览。

精确端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。ID：`mcp_`、Call `mcl_`；HTTP/挂载以 Server
name 寻址。
