# EDGE-305 账本警报独立复审

- scope: `EDGE-305 侧幕尊重手动关` L1/L2
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-041819`
- review status: `reviewed`

L1/L2 来自已收台的真实 App session，覆盖首条活动、用户手动关闭、切换到 Entities、返回 Chat，以及同一会话第二次真实活动。`rig-check` 在 App 存活期间通过，三路 SSE、frontend、backend、LLM wire 和录屏均有归属；`rig-down` 后无残留。L1 只判定手动关闭的产品行为，L2 只判定五通道一致性，L3-L5 仍为 `na`。

`pass-burst` 与 `discovery-collapse` 是新增绿格后的统计信号。复审确认无批量猜测、无 baseline 冒充、无阈值修改、无标准降低；该格证据足以销账两条警报。
