# EDGE-342 · 账本警报复审

- 本次新增的是一个真实 App L2 裁决，不是五个未经观察的快速橡皮章。完整 session
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-213419` 已由
  `rig-down` 封口，录屏为可读的 60fps H.264；`rig-check` 在操作期间确认五通道均归属
  conductor。
- `gap-too-fast` 的触发原因是单格账本写入发生在完整观察结束之后，不能反推观察时长。
  session 中确有 App 选择模型、设置页拒绝 Agent 默认、真实 chat 回合和最终 Composer
  状态，且保留 backend、SSE、frontend、LLM 原始 journal。
- `discovery-collapse` 的 0% fail-share 不能被解释为产品零缺陷。本格保留真实负向：
  chat-only 模型设置为 Agent 默认时服务端返回 `422 MODEL_NOT_AGENT_CAPABLE`，旧默认
  未改变；同时保留了之前的 raw-English/截断发现及其修复后的本地化回归。
- anchors 已重新校准为 `10/10`，算法、阈值、CODEX、COVERAGE 序列 gate 均未修改；本次
  仅对这两个已打开警报按原规则串行销账。
