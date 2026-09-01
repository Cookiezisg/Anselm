# EDGE-327 workspace 热切换三拍：L4 账本与警报独立复审

- subject: `EDGE-327 / workspace 热切换三拍 / L4`
- source evidence: `testend/rig/formal-evidence/EDGE-327-workspace-hot-switch-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260901-12/sessions/20260901-231217`
- ledger result: `judge.py` 已写入 `pass (C2)`；coverage 行由 `✓✓✓~~` 变为 `✓✓✓✓~`
- anchors: `10/10`；anchor set sha256 `e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`

## Independent review

逐项重读封口录屏、`edge327-l4-switch-contact.jpg`、60fps 帧测量摘要、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和 rig lifecycle。录屏确实包含 source 深链、用户主动点击 workspace 菜单、target 空 Chat landing 及约 6 秒稳定态；后端无应用错误，三条 SSE 流均有连接证据，messages durable seq 单调，前端无 Flutter/Dart 应用错误，managed gateway wire 的 challenge/install/models/chat 请求均为 200，`rig-check` 与 `rig-down` 均通过。

本格的 `C2` 判定只覆盖最终目标页面的语义间距、导航/空态/composer 几何关系和稳定视觉成品；用户主动触发的菜单展开与 workspace 替换不被误算为 B2 缺陷。60fps ROI 测量的动作窗口变化最大为 `changedFrac=0.03201`，动作完成后的稳定窗口无超过 `0.001` 的变化，未发现旧内容回流、白屏、幽灵右岛或二次布局跳变。

`discovery-collapse` 是近 50 条裁决 fail-share 为 0.0% 的既定统计信号，不代表本证据缺失。锚点仍为 10/10，证据、法条和五通道均齐全；本次复审不修改阈值、算法、法典、锚点或顺序门。仅在此水位销账，后续真实 fail 仍会重新打开该警报。
