# EDGE-168 每租户模板 URL：真实 App 授权前边界（2026-09-02 重启后复核）

- session=`/private/tmp/anselm-rig-formal-20260902-38/sessions/20260902-205256`
- 真实 App PID=`30377`；录屏=`336.606667s`；`rig-check.sh` 五通道通过；`rig-down.sh` 正常收台。
- 从 onboarding 创建隔离 workspace 后，Computer Use 进入 `Settings → MCP servers → com.glean/mcp`。
- 真实产品计划页显示 `streamable-http`、`GLEAN_MCP_URL * required`、Glean endpoint 示例和 `Connect & authorize`。
- 本轮没有输入任何租户 URL，没有点击授权按钮，没有启动浏览器 OAuth，没有落盘 MCP server 或 OAuth grant。
- 本文件是授权前边界证据，不是 L2 通过证据；COVERAGE 保持 `✓~~~~`，不得用本轮结果写绿。

## Five-channel evidence

- **frames / Computer Use**：AX 树确认计划页的 required 字段（element `41`）和授权按钮（element `42`）；稳定画面归档为 `sessions/20260902-205256/evidence-EDGE-168-before-oauth.jpeg`。页面无遮挡、重叠、截断或未解释的布局跳变。
- **backend**：`backend.log`=`791` 行；真实记录包含 `/api/v1/mcp-registry`=`200` 与 `/api/v1/mcp-registry:plan`=`200`；无应用级 WARN、ERROR、panic 或 FATAL。
- **SSE**：`sse.jsonl`=`4` 行；notifications/messages/entities 三条 workspace 流均连接。本轮没有业务写入，不伪造 durable 成功帧。
- **frontend console**：`frontend.log`=`5` 行；唯一 `error` 是 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断，未见 Flutter、Dart、Unhandled exception 或布局错误。
- **LLM wire**：`llm.jsonl`=`10` 行；managed bootstrap challenge/install/models 均真实经过 tap 并成功，未发生 OAuth 请求。

## Boundary decision

仓内 `oauth_flow_test.go` 已覆盖“URL 展开后再做 OAuth discovery、resource 与持久化 URL 一致”，但它不是 App + 真实第三方租户证据。要完成本格 L2，下一步必须在明确动作时提供真实 Glean tenant endpoint，并在点击 `Connect & authorize` 前再次确认；在此之前顺序门不得推进该格，也不得以本地 fake server、API 直调或旧 session 替代。
