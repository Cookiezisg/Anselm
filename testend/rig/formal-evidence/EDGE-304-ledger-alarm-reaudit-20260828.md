# EDGE-304 账本警报独立复审

- scope: `EDGE-304 侧幕跟随三档` L1/L2
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-040938`
- review status: `reviewed`

本格的 L1/L2 通过记录来自已经收台的真实 App session。session 覆盖空态、`Never`、`First per conversation`、`Every time` 及手动关闭优先级；五通道均有归属，`rig-check` 在 App 存活期间通过，`rig-down` 后进程和监听器清空。L1 的 G1 只判定三档语义和入口可发现性；L2 的 F1 只判定真实 UI、Activity、SSE、backend 和 LLM wire 一致，L3-L5 仍为 `na`。

`pass-burst` 与 `discovery-collapse` 是新增绿格后的统计信号。复审确认没有批量猜测、没有用历史基线冒充新证据、没有调整阈值、没有降低 CODEX 或锚点要求；该格证据足以销账两条警报。
