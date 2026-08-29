# EDGE-324 · 账本警报独立复审

- 触发警报：`discovery-collapse`。
- 触发原因：写入 EDGE-324 后，最近 50 条 live judgment 的 fail share 仍为 `0.0%`，低于 `5%` 地板。
- 复审依据：锚点集重新校准通过（10/10）；EDGE-324 使用独立真实 App 故障注入 session `20260829-140606`，四个私有 selector 均不存在时 App 仍可启动和导航，录屏 `30.895000s`，收台前 `rig-check` 五通道全绿且无外部遮挡。
- 复审结论：警报是统计机制的预期停闸，不是放宽标准。该 L2 只覆盖 nil-guard 降级下的真实可见性、持续导航和五通道健康；L3-L5 仍为 `na`，没有把未测量的视觉精度或可发现性冒充通过。
- 处理：保留 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、锚点有效期和 ledger gate 逻辑不变；以本次独立复审说明 ack `discovery-collapse`。
