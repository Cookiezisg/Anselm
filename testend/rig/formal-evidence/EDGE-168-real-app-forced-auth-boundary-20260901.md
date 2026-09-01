# EDGE-168 每租户模板 URL：真实 App 强制授权边界（复核）

- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-221208`
- 真实 App 从 `Settings → MCP servers` 打开 marketplace，进入 `com.glean/mcp` 安装计划。
- 安装计划真实显示 `GLEAN_MCP_URL`、`* required`、租户 endpoint 示例和 `Connect & authorize`。
- 本轮停在授权动作之前：没有填写租户 URL，没有点击 `Connect & authorize`，没有启动浏览器 OAuth，没有落盘 MCP server 或 OAuth grant。
- 该动作会建立持久外部访问凭证，属于强制人工队列；本文件不是 L2 通过证据，COVERAGE 仍保持 `✓~~~~`。

## Five-channel boundary

- **frames / Computer Use**：真实 App AX 树与稳定截图确认 required URL 字段和最终按钮存在；截图归档在 session 的 `evidence/EDGE-168-real-app-before-oauth-confirmation.jpeg`。
- **backend**：`backend.log`=`303` 行；没有应用级 panic、fatal、WARN 或 ERROR。
- **SSE**：`sse.jsonl`=`8` 行；三条 workspace 流均连接，未发生业务写入，故没有伪造 durable 成功帧。
- **frontend console**：`frontend.log`=`4` 行；唯一 error 是已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断，无 Flutter/Dart/布局/Unhandled 红线。
- **LLM wire**：`llm.jsonl`=`1` 行；managed 握手在线，本轮没有 completion 或 OAuth 请求。

`rig-down` 已完成，owned process 已收台。后续需要用户在明确动作时确认，才能继续填写真实租户 URL、点击授权并验证展开后的 OAuth resource。
