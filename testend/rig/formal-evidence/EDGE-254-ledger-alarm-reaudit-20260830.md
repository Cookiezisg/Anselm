# EDGE-254 · keyset 排序切换丢游标 · ledger/alarm re-audit

- ORM 普通与 race 回归通过：排序轴变化时游标绑定查询条件，游标列随排序切换，不漏行、不重行。
- acceptance HTTP 场景通过：`TestChat_RailSortByName` 及 cursor 相关 contract 场景均通过。
- L2-L5 的本次裁决只覆盖内部/HTTP 契约的适用性边界；没有把接口测试冒充真实桌面 App、五通道、视觉 craft 或 discoverability 证据。
- 如统计告警因连续适用性裁决打开，按原阈值完成锚点校准和本证据复审后销账；不修改告警算法、阈值、CODEX 或顺序门。
