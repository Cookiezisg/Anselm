# EDGE-189 ledger alarm re-audit

- 触发：新批次第八格五项裁决按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-189-search-changed-queue-reconcile-20260825.md`。
- 复审结论：queue overflow 非阻塞、live entity 对账恢复和 orphan 清理均由 `-race` 回归钉住；真实 App 五通道未执行，L2-L5 保持 `na`。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
