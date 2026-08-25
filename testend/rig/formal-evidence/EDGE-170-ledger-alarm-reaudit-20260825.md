# EDGE-170 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-170-mcp-failed-persists-20260825.md`。
- 复审结论：focused service 与真实 HTTP 均证明连接失败先落盘、重连仍可尝试、失败工具调用明确
  返回 down；没有把失败重连通知伪装成成功，L2-L5 的 na 边界明确。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
