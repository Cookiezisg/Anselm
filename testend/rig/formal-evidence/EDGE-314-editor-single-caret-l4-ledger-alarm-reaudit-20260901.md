# EDGE-314 编辑器唯一光标：L4 账本与警报独立复核

- target judgment: `EDGE|编辑器唯一光标铁律|L4`
- target session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-201749`
- re-audit timestamp: `2026-09-01`

## Alarm disposition

`alarms.py check` 在新增正式裁决后打开 `discovery-collapse`：最近 50 条 live
judgment 的 `fail` 占比为 `0.0%`，低于当前 `5%` 地板。该警报只说明需要复核裁判是否停止发现问题，
不是把本格判为产品失败。

复核动作：

1. 重新读取 EDGE-314 L4 的完整证据与录屏关键帧，而不是只读取裁决行。
2. 确认 `f100` 是表格单 caret、`f110` 是代码单 caret、`f120` 是收尾稳定帧；确认唯一显著测量变化只在用户动作窗口。
3. 确认同一 session 的 backend、SSE、frontend、LLM wire 和 rig lifecycle 记录均存在且无应用错误。
4. 运行 10-anchor 校准：`anchors: calibration passed (10 anchors)`。
5. 确认 `gen_coverage.py --check` 保持 `848 rows, 848 carried judgments, 0 tombstones`。

## Result

该警报由真实产品证据复核通过后销账；本次复核没有发现被漏记的 fail、伪造证据或缺失通道。
EDGE-314 L4 的 `pass (C1)` 保留，后续判断仍必须经过同一 gate 和三曲线检查。
