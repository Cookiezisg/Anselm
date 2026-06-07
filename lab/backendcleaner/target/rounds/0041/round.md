# R0041 — M3.5 mcp 重写（GitHub registry 全量市场 + 加密表 + stdio/remote 双 transport）

> 波次 3 第三站。mcp = 接外部生态（GitHub/Slack/Notion…）的协议网桥，重写为「对接官方 registry 的市场 + 加密表 + 容器实体」。索引见 ROUNDS.md / STATE.md 决策行；本文记调研 + 设计 + 实现 + 留口。

## 调研：github.com/mcp 是什么（改判市场设计的关键）

用户提示「有个 market 模块」+「python+node+docker 能覆盖全部除一个外」。深挖（WebFetch + curl `api.mcp.github.com/v0/servers`）确认：

- **github.com/mcp = GitHub MCP Registry**，**99 个 server**，有**标准化 API**（`api.mcp.github.com/v0/servers`，一页全 `total_pages:1`）。背后是官方 MCP Registry 协议（`registry.modelcontextprotocol.io`，API 冻结 v0.1）。
- **runtime 分布（99）**：38 remote（SSE/HTTP，无需 runtime）+ 38 node + 11 python + 9 docker + 3 .NET（其中 `Azure.Mcp`/`Microsoft.Fabric.Mcp` 有 npm 备选 → node，仅 `NuGet.Mcp.Server` 纯 NuGet）。**python+node+docker 覆盖 96/99**，"除一个外"= .NET 那一类。
- **server.json 结构化**：`packages[]`（多安装方式备选：runtime_hint + name + environment_variables 带 is_secret + arguments）+ `remotes[]`（transport_type + url + headers）。**旧 curated_registry.go 手抄 24 条的全部内容，registry 直接给、99 全量、自动更新。**
- **关键改判**：市场从「硬编码 24 curated」→「**对接 GitHub registry API 拉 99 全量**」。

## 设计决策（用户拍板）

1. **市场 = 对接 GitHub registry**：`GitHubRegistrySource` HTTP 拉 99；三级兜底 `go:embed` snapshot（精简版 85KB，去 readme）→ `~/.forgify/cache/mcp-registry.json` → embed。**全局公共不分 workspace**（GitHub 的货架）。
2. **存储 = 加密表**（用户拍板，对齐 handler）：`mcp_servers` 表取代 mcp.json + 砍 `mcp_calls`/`mcp_health_history` 两表。`config_enc` AES-GCM 加密 `{env, headers}`，store 层封装（domain.Server 持明文、内部 serverRow 加解密）。mcp.json 降级为 import/export 互操作格式。
3. **进程池单例对齐 handler**：`map[mcp_id]`（id 全局唯一 → 跨 workspace 不撞，这是「单例 vs workspace 隔离」自洽的关键）；Boot per-workspace；crash 重连；手动 `reconnect_mcp`（重置按钮，对齐 restart_handler）；Shutdown。
4. **双 transport**：stdio（进程由 sandbox `SpawnLongLived` 起、归 sandbox 管，go-sdk 用 handle stdin/stdout 经 **`IOTransport`** 接协议 —— 比 CommandTransport+ResolveExec 更优，省回改）+ sse/streamable-http（go-sdk，headers 经自定义 http.Client RoundTripper 注入）。
5. **安装挑 runtime**：遍历 packages 按优先级 node>python>docker>dotnet（轻量优先，有 npm 版就别拉 .NET SDK）→ `RegistryEntry.Plan()` 纯逻辑。dotnet 加入（用户「加.Net」）→ 覆盖 99/99。
6. **catalog 容器实体**：报 server 名+描述+**全工具名**（catalog.Item 加 `Members []string` + mechanical 渲染，不截断）。handler 同款范式（列方法名，本轮留口）。
7. **工具面**：4 系统工具（list_mcp_marketplace/install/uninstall/reconnect_mcp）+ 动态 `mcp__server__tool`（每工具独立 lazy、进 search_tools 检索池**不进 Overview**、catalog 引导；冒号非法故双下划线）。danger 零逻辑（LLM 自报，S18）。
8. **砍**：Search LLM rerank、searchrouter、call_mcp_tool、search_mcp_tools、get/search_executions、curated 硬编码、两审计表。

## 实现（文件）

- `domain/mcp/{mcp,registry}.go`（+ 2 test）：Server/ServerStatus/ToolDef/RegistryEntry + Plan()/runtimeForHint/launchCommand + Repository/RegistrySource 端口 + 10 errorsdomain
- `infra/mcp/{client,registry,config}.go` + `registry_snapshot.json`（+ 2 test）：go-sdk client 双 transport（IOTransport/SSE/Streamable）+ GitHubRegistrySource（HTTP+embed+cache）+ ParseImport
- `infra/store/mcp/mcp.go`（+ test）：orm `mcp_servers` 表 + serverRow 加解密 config_enc
- `app/mcp/{mcp,install,calltool,catalog_source,relations}.go`（+ test）：进程池单例 + Boot/connectOne/reconnect/Shutdown + install/Import/AddServer + CallTool + catalog(Members)/relation(NamesByIDs) 适配器
- `app/tool/mcp/{mcp,system,dynamic}.go`（+ test）：4 系统工具 + 动态适配器
- `transport/httpapi/handlers/mcp.go`：REST（server CRUD + reconnect + tools:invoke + import + registry + install）
- 回改：`domain/catalog/source.go`（Item.Members）+ `app/catalog/mechanical.go`（渲染）
- go.mod：+`modelcontextprotocol/go-sdk v1.6.0`

## 留口（本轮逻辑完整 + 测试绿；物理跑通真实 server 需后续，见 deps-todo）

1. **sandbox 物理 runtime-tool**：node ResolveExec 认 npx（runtime bin）/ python uvx 需装 uv / dnx / docker 空 Cmd（prepareSpawn 放行）/ dotnet runtime 新增。涉及回改 sandbox R0026 多处 + **需真实环境验证（离线测不了真实 npx/uvx）**。
2. **handler catalog 列方法名**：catalog 渲染已支持 Members，但 handler source 填方法名需逐查 active version（ListAll 不附）。
3. **trigger sensor 绑 mcp.tool**：回改 trigger R0039（sensor target 加第三类 + 依赖 mcp 端口）。

## 验证

domain 6 + store 6 + app 7 + infra 3 + tool 3 测试全绿（fake sandbox/client/repo/registry，全离线）；embed snapshot 测试守住「parse 99 + 95+ 可 Plan」；gofmt/build/vet/test 全绿。契约 mcp.md 重写（DOC-112）+ database/api/error-codes/catalog.md + contract #21。
