# EDGE-327 · 账本与警报独立复审

本复审对应正式 session `20260828-023548` 与 `EDGE-327 L2` 新增裁决。重新读取 session manifest、封口录屏、三 workspace 的 SSE journal、backend/frontend journal、LLM wire journal 和正式证据；未修改警报阈值、算法、法条或锚点。

- `gap-too-fast` 与 `pass-burst` 是连续裁决写入时间的统计信号；本格包含真实工作区创建、深链进入、菜单切换、目标列表重取和 `216.946667s` 五通道 session，不能用账本间隔替代产品观察。
- `discovery-collapse` 不代表隐藏失败：本格只判 L2，L3-L5 明确为 `na`，没有把 `na` 当作通过，也没有用静态 L1 代替真实路径。

复审结论：本格有真实五通道 session、G2 法条和封口证据；三项统计警报按既有 `ack` 流程销账，后续格仍须独立取证。
