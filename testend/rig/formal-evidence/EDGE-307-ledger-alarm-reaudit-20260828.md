# EDGE-307 账本警报独立复审

- scope: `EDGE-307 poll 型 202 不谢幕` L2
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-050413`
- review status: `reviewed`

本次只为 EDGE-307 的一条真实 L2 绿格复审统计警报，不批量补录、不改变其他格子的判定。成功路径由真实 App、backend、三路 SSE、frontend journal、managed LLM wire 和录屏共同证明；更早的输入桥接失败已在正式证据中隔离，不被当作本次产品红线。

复审确认：

- 没有修改 `alarms.py` 的阈值、算法或覆盖范围；
- 没有把 baseline journal 当作 live evidence；
- 没有用静态测试或无录屏请求冒充 L2；
- 真实成功路径和早期失败探针均保留，证据没有被删除或覆盖；
- 本次只把 EDGE-307 L2 从 `na` 更新为 `pass`，不改变 L3-L5 的 `na`。

若本次新增绿格触发 `pass-burst` 或 `discovery-collapse`，它们是统计信号而非产品失败；本复审后可按真实证据销账，随后仍由 `alarms.py check` 重新计算，新的曲线异常必须重新打开。
