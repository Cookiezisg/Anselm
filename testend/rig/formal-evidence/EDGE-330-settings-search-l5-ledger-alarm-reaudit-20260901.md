# EDGE-330 设置项搜索索引漂移：L5 账本与警报独立复审

- subject: `EDGE-330 / 设置项搜索索引漂移 / L5`
- source evidence: `testend/rig/formal-evidence/EDGE-330-settings-search-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852`
- ledger result: `judge.py` 已写入 `pass (G1)`；coverage 行由 `✓✓✓✓~` 变为 `✓✓✓✓✓`
- anchors: `10/10`；anchor set sha256 `e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`

逐项重读 Settings 入口、搜索 placeholder、`zoom` 分组结果、`Reset zoom` 跳转、无匹配和清空恢复的真实录屏与 AX 证据，并核对 backend/SSE/frontend/LLM journals 和 rig lifecycle。普通用户路径没有使用内部 ID、anchor 或 widget 名称；结果、跳转目标与空态文案均可理解且能完成目标。

`discovery-collapse` 仅表示近 50 条裁决 fail-share 为 0.0%，不是本格缺证据。anchors 仍为 10/10，未修改阈值、算法、法典、五级标准或顺序门；仅按当前 journal 水位销账，后续真实 fail 仍会重新打开该警报。
