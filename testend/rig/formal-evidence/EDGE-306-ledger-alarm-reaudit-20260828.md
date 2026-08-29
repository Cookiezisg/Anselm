# EDGE-306 账本警报独立复审

- scope: `EDGE-306 导演器清 Live 幽灵` L2
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-043601`
- review status: `reviewed`

本次裁决不是批量补录，也不是把旧的 `na` 批量改绿。EDGE-306 先在真实 App 中制造 messages stream 断流和真实 `410 SEQ_TOO_OLD`，观察到 durable completed 卡片旁的 stale `Running` live ghost；随后停止、修复 transcript 对 settled block 的所有迟到 frame 处理，并重建 App，再以独立窗口录屏、AX、backend、三路 SSE、frontend journal 和 LLM wire 复验。`judge.py` 只新增该行 L2，证据与法条均通过 gate；L3-L5 仍为 `na`。

本次 `pass-burst` 与 `discovery-collapse` 是新增真实绿格后重新计算出的统计信号。复审确认：

- 没有修改 `alarms.py` 阈值、算法或覆盖范围；
- 没有把 baseline journal 当作 live evidence；
- 没有使用无录屏的静态测试冒充 L2；
- 真实红场仍保留，修复前后的证据链没有被删除或覆盖；
- 当前清册只有 EDGE-306 的 L2 从 `na` 变为 `pass`，不影响其他未验收格。

两条警报均可在本复审后销账；后续仍由 `alarms.py check` 重新计算，若出现新的曲线异常会重新打开。
