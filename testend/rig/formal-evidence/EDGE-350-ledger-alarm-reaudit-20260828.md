# EDGE-350 ledger alarm re-audit

本次新增裁决后，`alarms.py check` 按既定阈值打开 `gap-too-fast` 与 `discovery-collapse`。
这两个警报针对裁决台账的统计形态，不是产品行为证据；不修改算法、不降低阈值。

- 真实 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-005848`，录屏 `52.511667s`。
- 本格不是快速橡皮章：先发现 `SetReadLimit` 会吞掉越界帧的真实代码缺陷，修复后补 Go/Flutter 回归，再启动完整五通道 App 台架，用独立客户端注入两种边界帧，核对未转发上游、typed error、SSE/LLM/backend/frontend 收台结果。
- 复核结论：`EDGE-350` 的 L2 证据完整；`E1/F2/F3/F4` 引用与证据文件齐全。警报仅反映历史裁决密度与近期零失败比例，不能推翻本次证据，也不能被解释为产品全绿。
