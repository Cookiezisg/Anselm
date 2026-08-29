# EDGE-280 · 账本警报独立复审

- 触发警报：`discovery-collapse`。
- 触发原因：写入 EDGE-280 后，最近 50 条 live judgment 的 fail share 仍为 `0.0%`，低于既有 `5%` 地板；这要求复审判断质量，不能被当作产品已经无缺陷。
- 复审依据：锚点集重新校准通过（10/10），且 hash 未变；EDGE-280 使用独立真实 App session `20260829-143120`，真实删除 Agent knowledge 文档后重新进入 Agent 详情，画面显示 `1 unhealthy` 与 `knowledge document does not exist`。同一 session 保存录屏、backend、frontend、SSE、LLM 五通道日志，`rig-check` 与 `rig-down` 均通过，REST mount-health 与 SQLite/SSE dependency-broken 事实一致。
- 复审结论：该 L2 是一条真实负向依赖断裂路径的五通道验收，并没有把未观察到的 L3-L5 冒充通过；当前零 fail 尾窗只反映账本集中写入时序，不能证明产品变干净。
- 处理：保留 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、锚点有效期和 ledger gate 逻辑不变；以本次独立复审说明 ack `discovery-collapse`，继续按覆盖序列推进。
