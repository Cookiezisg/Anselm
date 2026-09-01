# EDGE-313 编辑器 undo 全量重建：L4 Computer Use 输入桥阻塞（不计账）

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-201210`
- data: `/private/tmp/anselm-data-edge313-l4-20260901.MfxLR3`（由未污染的 `anselm-data-edge313-physical-20260828` 副本启动）
- recording: `screen.mov`, `66.590000s`, 已由同一 conductor 封口

## Observation

本场只作为输入路径诊断，不写 `judge.py`，不推进批次。真实 App 启动、Library 文档打开和五通道归属均通过；基线正文为 `Original paragraph for undo.`。

Computer Use 点击 AX 正文文本后，光标没有形成可供快捷键可靠操作的可验证编辑焦点；随后 `End` 没有把插入点移动到正文末尾，`type_text(" EDITED")` 实际把文本插入为 `Original parag EDITEDraph for undo.`。此后 `super+z` 未撤销，正文仍为该错误中间态，故没有任何“用户 undo 已完成”的 L4 证据。

这场误插入是观察器输入定位失败，不是产品缺陷判定；未用 `set_value`、数据库写入或 editor testing API 修正结果，也未把这次污染的 session 作为通过证据。

## Channel health

- backend journal=`257` 行；无 WARN、ERROR、panic 或 fatal。
- SSE journal=`10` 行，三路 witness 已接入并正常收台。
- frontend journal=`4` 行；无 Flutter、Dart、RenderFlex、RenderBox、Unhandled 或 Null check 应用红线。
- LLM wire 在线；本场编辑路径没有 completion 请求。
- 录屏=`66.590000s`，`rig-check` 通过，`rig-down` 停止全部 owned processes。

## Disposition

L4 保持开放，不写绿账；该项已从自主前线移入 `forced_queue`，等待真实物理输入或可靠的 Computer Use 修复后再验收。既有 L2/L3 证据不被本场覆盖或降级。
