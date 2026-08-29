# EDGE-323 · 账本与警报独立复审

本复审对应正式 session `20260828-023137` 与 `EDGE-323 L2` 新增裁决。重新读取了 session manifest、封口录屏、三路 SSE journal、backend/frontend journal、LLM wire journal 和正式证据；未修改警报阈值、算法、法条或锚点。

- `gap-too-fast` 与 `pass-burst` 只反映连续裁决的写入时间分布；本格实际包含 `51.830000s` 录屏、全屏进入/退出和完整收台，不能用统计间隔替代产品观察。
- `discovery-collapse` 不代表漏掉失败：本格只判 L2，L3-L5 明确保持 `na`，没有把 `na` 变成 pass，也没有隐藏产品失败。

复审结论：本格具备真实五通道 session、G2 法条和封口证据，三项统计警报按既有 `ack` 流程销账；下一格重新独立取证，不沿用本次观察。
