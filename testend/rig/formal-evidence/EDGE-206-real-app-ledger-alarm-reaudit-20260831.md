# EDGE-206 账本警报复审：朗读长度上限

- **警报**：`gap-too-fast`
- **复审对象**：`EDGE-206|朗读长度上限` L2-L3，本正式 session 的连续裁决
- **真实证据**：`testend/rig/formal-evidence/EDGE-206-real-app-readaloud-length-limit-green.md`
- **正式 session**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-095420`
- **真实录屏**：同 session `recording.mov`，`155.681667s`

## 复审结论

警报由裁决写入间隔触发，属于速率信号，不是证据缺失信号。本次复审重新核对同一正式
session：真实 sidecar 收到 exactly `4001` 个 CJK rune 的朗读请求并在 `0ms` 返回
`READALOUD_TEXT_TOO_LONG`；LLM wire 没有任何 `/v1/audio/speech`；真实 App 已启动并录屏，
三路 SSE、backend journal、frontend console 与 managed wiring 均留存。长文本没有在 App
composer 成功提交，因此本次只写入 L2/L3，L4/L5 仍开放，未把失败的 UI 构造冒充视觉或
发现性证据。

复审不修改告警阈值、算法、CODEX、锚点或顺序 gate，仅销账当前 journal 水位。
