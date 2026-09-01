# EDGE-330 设置项搜索索引漂移：L3 账本与警报独立复审

- subject: `EDGE-330 / 设置项搜索索引漂移 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-330-settings-search-l3-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852`
- ledger result: `judge.py` 已写入 `pass (A1)`；coverage 行由 `✓✓~~~` 变为 `✓✓✓~~`
- anchors: `10/10`；anchor set sha256 `e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`

逐项重读 30fps 抽帧、三次 `measure latency` 输出、动作窗口 diff、Computer Use AX 状态，以及 backend/SSE/frontend/LLM journals 和 rig lifecycle。三次首反馈均为 `33.3ms`，低于 `A1=100ms`；搜索结果、跳转洗亮、无匹配和清空恢复均有真实画面与 AX 对应，未把只读路径伪造成模型调用或业务 durable 事件。

`discovery-collapse` 仅表示近 50 条裁决 fail-share 为 0.0%，不是本格缺证据。anchors 仍为 10/10，未修改阈值、算法、法典、五级标准或顺序门；仅按当前 journal 水位销账，后续真实 fail 仍会重新打开该警报。
