# EDGE-315 L3 账本与警报独立复审

- subject: `EDGE-315 / 空 task 尾空格腐化 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`
- law: `B2`

## 复审结论

独立复核了真实录屏、ROI 测量、稳定帧、backend/frontend/SSE/LLM 五通道 journal 和 L2 的 REST 原文。`changedFrac` 较大的样本均处于文档打开、离开或重开窗口；中间任务的输入/退格变化只落在当前编辑区域。没有把用户动作产生的变化伪装成静止期零变化，也没有把收台 EOF 误报为产品断流。

本次 `judge.py` 的 `L3 pass (B2)` 具备真实 evidence 文件与现存法条；anchors 为 `10/10`，COVERAGE 仅提升 `EDGE-315` 的 L3，L4/L5 不变。若本次批量写账触发 `pass-burst` 或 `discovery-collapse`，其原因是串行裁决节奏，不是放宽阈值；按原阈值复核后方可 ack。
