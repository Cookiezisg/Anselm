# EDGE-186 ledger alarm re-audit

- 触发：新批次第六格五项裁决按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-186-search-reindex-singleflight-inplace-20260825.md`。
- 复审结论：focused single-flight/per-workspace/no-purge 与真实 HTTP 204→命中恢复均通过；真实 App 五通道未执行，L2-L5 保持 `na`。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
