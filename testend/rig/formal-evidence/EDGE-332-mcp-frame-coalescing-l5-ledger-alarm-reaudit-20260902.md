# EDGE-332 L5 账本警报独立复审

- alarm: `discovery-collapse`
- formal ledger: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`
- product session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- judgment under review: `EDGE|MCP 面板帧不可信|L5|pass|G1`

## Independent checks

- 盲走路径从 Settings → MCP servers 开始，不依赖 endpoint、SSE、代理名或内部错误码；失败、诊断、删除后的下一目标都在真实 App 中有对应入口或状态。
- 失败卡的用户可见文案是“连接失败”与检查配置/运行环境并重连；原始 `mcp.Client.Initialize...EOF` 只有显式展开技术详情后出现，普通用户无需理解内部协议即可完成恢复或删除。
- 删除测试 fixture 后服务端 roster 变为空数组，App 回到 marketplace；没有把短暂 entities 帧或删除通知冒充最终列表。
- `rig-check`/`rig-down` 通过，三路 SSE、backend、frontend console、LLM wire 和 app proxy 证据均在本 session；本复审不把报警的统计事实改写成产品事实。

## Resolution

L5 入口、失败解释、恢复动作和下一目标均可复核，允许按原规则 ack。G1 与报警阈值保持不变。
