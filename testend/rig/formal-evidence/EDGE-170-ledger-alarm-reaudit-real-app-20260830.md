# EDGE-170 账本统计告警独立复审

- 复审对象：`EDGE-170|MCP 连接失败仍落盘` L2，正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-174239`。
- `gap-too-fast` 由集中写入单个 L2 产生；复审重新核对五通道封口、真实 `PUT` 失败持久化、App failed 卡片、真实 `:reconnect` 恢复、可读录屏和进程归零，未用时间阈值代替证据，未改阈值。
- `discovery-collapse` 由近尾无 fail 产生；本项实际包含真实失败路径和恢复路径，backend/SSE/frontend/LLM 原始 journal 可交叉验证，故不是漏测导致的假绿。未修改发现率门禁、法典、锚点或顺序门。
- 复审结论：两项告警按原阈值 ack；本文件不为额外 COVERAGE 单元提供通过依据。
