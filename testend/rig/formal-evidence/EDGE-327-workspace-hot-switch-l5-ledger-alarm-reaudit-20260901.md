# EDGE-327 workspace 热切换三拍：L5 账本与警报独立复审

- subject: `EDGE-327 / workspace 热切换三拍 / L5`
- source evidence: `testend/rig/formal-evidence/EDGE-327-workspace-hot-switch-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260901-12/sessions/20260901-231217`
- ledger result: `judge.py` 已写入 `pass (G1)`；coverage 行由 `✓✓✓✓~` 变为 `✓✓✓✓✓`
- anchors: `10/10`；anchor set sha256 `e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`

逐项重读普通用户路径证据、封口录屏、三流 SSE、backend/frontend/LLM journals 与 rig lifecycle。录屏中 workspace 控件和菜单使用可读名称，当前项有明确标记；用户不需要 workspace ID、内部工具名或路由知识即可切换。目标 workspace 显示空 Chat，source 对话没有残留；回到 source 后原对话仍可回访。五通道和收台记录完整，未发现应用错误或伪造 completion。

`discovery-collapse` 只表示近 50 条裁决的 fail-share 为 0.0%，不是本格缺证据。anchors 仍为 10/10，未修改阈值、算法、法典、五级标准或顺序门；仅按当前 journal 水位销账，后续真实 fail 仍会重新打开该警报。
