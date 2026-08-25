# EDGE-181 ledger alarm re-audit

- 触发：新批次首格五项裁决按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-181-search-embed-upsert-all-fail-20260825.md`。
- 复审结论：`-race` focused 回归确认整批 upsert 失败时当前轮次有界结束且只尝试一次；真实盘满/表损和 App 五通道未执行，L2-L5 保持 `na`。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
