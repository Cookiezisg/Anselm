# EDGE-348 | 语音双工握手拒绝闭集 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：超过 1 秒的操作必须持续显示进度或状态；拒绝也必须给用户可理解的状态收尾。

## 有效会话

- session：`/private/tmp/anselm-rig-formal-20260902-23/sessions/20260902-045413/`
- 数据目录：`/private/tmp/anselm-data-edge348-20260902-r5`
- 上游：真实 `https://api.anselm.website`
- App：conductor 直接启动的 Flutter macOS App，Computer Use 逐步操作，窗口录屏独占
- 录屏：`screen.mov`，`h264 / 3104x1848 / 60fps / 135.975000s`

## 用户目的与 stop-and-fix

普通用户从新对话点击 Composer 的 `Voice input`。台架只让真实上游的 `/v1/speech/asr` WebSocket 握手返回一次 `401 QUOTA_EXHAUSTED`，challenge、install、models 和其它请求仍走真实网关。App 没有把供应商原文泄漏给用户，也没有留下永远录音或卡死的 Composer，而是显示完整的 `Voice quota. Try later.`，随后恢复空 Composer，用户可以继续输入。

首轮真实 session 曾显示 `This month's voice input allowance is used...` 的视觉截断。该结果冻结为红，不计入本格；修复把普通通知 capsule 的最大宽度从 340px 调整为 400px，并保留独立 widget 守卫，之后重新用全新 session 复验。

Computer Use 最终观察到：点击后约 `1912ms` 出现拒绝状态，AX 同时含 `Voice quota. Try later.`、dismiss affordance 和仍可用的 `Voice input`；没有 retry card、死 loading 或不可操作状态。

## 五通道互证

- **Channel 1 / 录屏**：conductor 录屏正常封口，`ffprobe` 可读，窗口归属和 60fps 均由 `rig-check.sh` 证明。
- **Channel 2 / backend**：后端日志无 `WARN`、`ERROR`、panic 或 fatal；本地 WebSocket 路径正常收尾，拒绝映射为闭集业务状态。
- **Channel 3 / SSE**：`sse.jsonl` 记录 notifications、messages、entities 三流连接，并在 `rig-down` 时 clean EOF；本次拒绝不产生虚假的 durable 业务帧。
- **Channel 4 / frontend console**：无 Flutter、Dart、RenderFlex、Unhandled、Exception、SEVERE 或 overflow 红线；仅保留已知 macOS IMK 宿主诊断。
- **Channel 5 / LLM wire**：`llm.jsonl` 中 challenge/install/models 为 `200`；`GET /v1/speech/asr` 仅一次 `401`，response body 为 `QUOTA_EXHAUSTED`，并标记 `fault_injected`。普通探测没有被 fixture 截断。

## 结论

真实握手拒绝被可靠归类为语音额度耗尽，状态反馈及时且可继续操作；修复前的截断红场和修复后的最终现场均保留在台架历史中。
