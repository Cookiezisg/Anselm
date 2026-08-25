# EDGE-175 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-175-mcp-stderr-tail-20260825.md`。
- 复审结论：8 KiB byte-cap focused 回归和真实 MCP 失败调用日志均通过；L2-L5 明确保持 `na`，没有把 server-level stderr 冒充精确本次时序或视觉证据。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
