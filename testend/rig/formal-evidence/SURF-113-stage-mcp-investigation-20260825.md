# SURF-113 stage/mcp investigation

## Scope

验收 MCP 接线现场和工具货架：市场发现、危险安装闸、连接状态、typed tools 列表、重连后的货架稳定性，以及普通 MCP 结果不会污染货架。

## Static contract

- `McpStageBody` 只把 `install_mcp_server`、`reconnect_mcp`、`create_mcp` 的 typed `result.tools[].name` 渲染为工具货架；其它 `mcp__server__tool` 执行结果不得被正则捞入货架。
- live 阶段显示 server name、env key（值永远掩码）和 progress tail；settled 阶段显示连接状态、工具数、最多 12 个工具名和结果条；失败态显示可解释错误。
- marketplace 安装是持久化/新增外部能力的 dangerous action，必须停在用户确认闸；本轮只点击一次性“允许”，没有选择“总是允许”。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-104412`
- workspace: `ws_c210c2d2162bdaa6`
- recording: `screen.mov`, finalized `202.041667s`, `2784x1808`, 60fps
- marketplace server: `microsoftdocs/mcp`; installed server name: `mcp`

### Positive paths

1. 真实 App 请求市场内的 `microsoftdocs/mcp`。模型一次 `search_tools`、一次 `list_mcp_marketplace({query:"microsoftdocs mcp"})`，市场返回 86 个可安装服务器并选中目标；App 明确显示远程运行时、无必填 env。
2. 安装在产品自己的 dangerous interaction 上停住，SSE 记录 `interaction` pending；Computer Use 点击一次 `允许`，没有点“总是允许”。安装后状态从 `disconnected → connecting → ready`，发现 3 个工具：`microsoft_docs_search`、`microsoft_code_sample_search`、`microsoft_docs_fetch`。
3. 安装 settled stage 的货架显示 `已允许`、`已连接`、`3 工具`、三个 typed chips 和连接时间；助手正文列出的工具与 REST `GET /mcp-servers/mcp` 完全一致。
4. 第二条真实 App 请求只重连已安装的 `mcp`。LLM wire 只调用一次 `reconnect_mcp({"name":"mcp"})`，无另装、卸载或 retry；状态再次经过 `disconnected → connecting → ready`，工具仍是同一 3 个且无重复。

## Five-channel evidence

- **Frame/UI**: 抽帧 `evidence/frames/surf113-mcp-125.png`（安装货架）和 `surf113-mcp-175.png`（重连货架）；录屏逐帧确认 chips、数量、连接时间、状态和工具说明均在界内，无 clipping/overlap/reflow。
- **Backend**: `GET /api/v1/mcp-servers` 和单读均 200；status=`ready`、consecutiveFailures=0、totalCalls=0、totalFailures=0，tools 三项 typed 描述齐全；backend journal 无 panic/FATAL/应用异常。
- **SSE**: messages durable seq `1..44`、notifications `16..19` 单调无 gap；entities 两次均为 `disconnected→connecting→ready`；安装 interaction pending/resolved 配对，`mcp.installed` 与 `mcp.reconnected` inbox 信号各一。
- **Frontend**: `frontend.log` 无 Flutter/Dart/Unhandled/Exception/RenderFlex/overflow marker；持续录屏包含市场等待、确认闸、连接态和 settled shelf。
- **LLM wire**: 业务工具调用各一次：`search_tools`、`list_mcp_marketplace`、`install_mcp_server`、`reconnect_mcp`；观测响应全 HTTP 200，安装 action 的 interaction 由真实 UI 允许帧闭合。

## Boundary facts

- 没有调用任何 MCP 业务工具，因此 `totalCalls=0` 是真实事实，不伪造一次业务执行来证明货架。
- 本轮没有卸载已安装 server；数据在独立 disposable rig 目录，收台后不会污染开发 workspace。产品的“不可逆卸载”路径留给对应 coverage 行。

## Product verdict

用户能先发现市场能力、理解远程/无 env 前置条件，在危险闸看到将发生的持久化动作并明确允许；连接成功后能立即看到可用工具和稳定状态，重连不会丢货架或重复工具。工具货架只信 typed wiring receipt，五通道真相一致，本格可进入五级账本。
