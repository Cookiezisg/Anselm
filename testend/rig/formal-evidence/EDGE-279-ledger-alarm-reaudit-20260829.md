# EDGE-279 · 账本警报独立复审

- 触发警报：`discovery-collapse`。
- 触发原因：写入 EDGE-279 后，最近 50 条 live judgment 的 fail share 为 `0.0%`，低于既有 `5%` 地板；该信号要求确认判断质量，不能被解释为产品已无缺陷。
- 复审依据：锚点集重新校准通过（10/10），hash 未变；EDGE-279 的独立真实 App session `20260829-144028` 先挂载文档、再删除文档、再真实发送消息。LLM wire 明确含 `missing="true"`，App 给出删除原因和重新上传建议；backend、SSE、frontend、LLM 五通道及 SQLite/REST 事实一致，`rig-check` 与 `rig-down` 通过。
- 复审结论：本格覆盖的是一个真实负向悬挂引用场景，且 L2 之外的顺滑、视觉 craft、可发现性仍为 `na`；零 fail 尾窗只是集中写账的统计结果，不能证明产品变干净。
- 处理：保留 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、锚点有效期和 ledger gate 逻辑不变；以本次独立复审说明 ack `discovery-collapse`，继续按覆盖序列推进。
