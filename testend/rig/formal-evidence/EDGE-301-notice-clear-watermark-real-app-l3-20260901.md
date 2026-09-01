# EDGE-301 L3 丝滑证据（2026-09-01）

正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-151411`。真实 App 点击
`Clear all` 后，在约 80ms 的退场动画窗口内注入 fresh `skill.created`，HTTP 返回 `201`；动画结束后
fresh notice 稳定成为当前卡，旧队列没有回流。录屏、`edge301-clear-before.jpg`、
`edge301-clear-after-fresh.jpg` 与同场三流 SSE 共同证明交接完成，没有冻结或瞬跳。法条：A4。
