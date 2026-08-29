# EDGE-255 · PageAsc collation 不一致 · ledger/alarm re-audit

- ORM 普通与 race 回归通过：`PageAsc` 使用 `COLLATE NOCASE ASC`，以主键作同键 tie-breaker，跨页无漏行/重行。
- 本项是 `EDGE-254` 对话列表排序体验背后的 ORM 实现 seam；没有独立持久状态、交互时延、视觉表面或可发现性入口，故 L2-L5 以具体适用性理由记录 `na`。
- 如统计告警因适用性裁决打开，按既定流程使用本证据完成锚点复核并销账；不修改告警阈值、算法、CODEX 或顺序门。
