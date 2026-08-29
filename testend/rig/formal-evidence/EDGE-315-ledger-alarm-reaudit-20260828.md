# EDGE-315 · 账本与统计警报复核

- 新增裁决：`EDGE-315 空 task 尾空格腐化` Level 2 `pass`，法典引用 `F1`，真实五通道证据见 `EDGE-315-task-whitespace-heal-real-app-20260828.md`。
- `discovery-collapse` 因最近 50 个裁决 fail 占比为 0% 打开；该提示保留，不通过降低阈值或放宽 judge 处理。
- 写账前重新运行 `anchors.py check`：10/10 通过，anchor set hash 未变。
- 本轮证据包含两轮真实输入/清空、离开/重开、精确后端原文、SSE durable 序列、frontend journal、LLM wire 和录屏；没有用静态测试替代真实 App。
- 结论：按既有规则 ack；保持原阈值、算法、法典与 sequence gate，继续下一 atomic cell。
