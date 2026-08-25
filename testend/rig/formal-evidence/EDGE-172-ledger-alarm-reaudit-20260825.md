# EDGE-172 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-172-mcp-media-no-uploader-20260825.md`。
- 复审结论：同一回归对比 uploader 已接线与 `nil` 两种装配，缺席能力时调用成功、占位保留、无
  attachment receipt；L2-L5 的 na 边界明确，没有把无 uploader 冒充真实 App 视觉证据。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
