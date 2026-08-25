# EDGE-171 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-171-mcp-media-best-effort-20260825.md`。
- 复审结论：focused 三件媒体逐件失败回归与真实 stdio→attachment→vision wire 均通过；失败件
  占位、成功件 receipt、调用成功和线缆原生图片事实一致，L2-L5 的 na 边界明确。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
