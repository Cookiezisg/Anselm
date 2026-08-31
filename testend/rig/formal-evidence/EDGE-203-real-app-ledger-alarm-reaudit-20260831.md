# EDGE-203 账本警报复审：真实图片能力边界

- **警报**：`gap-too-fast`
- **复审对象**：`EDGE-203|非 audio 签发 playback` L2-L5，登记于 `01:20:45` 至 `01:22:45 UTC`
- **真实证据**：`testend/rig/formal-evidence/EDGE-203-real-app-non-audio-playback-green-20260831.md`
- **正式 session**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-091904`
- **真实录屏**：同 session `recording.mov`，`94.216667s`

## 复审结论

警报由四个等级裁决的写入间隔触发，属于裁决速率信号，不是证据观看时长信号。本次复审重新核对了同一个已收台的真实 session：真实 macOS App 显示图片附件且没有音频播放入口；图片的 playback lease 请求返回 `415 ATTACHMENT_PLAYBACK_UNSUPPORTED`；backend、三路 SSE、frontend console、managed gateway tap 和录屏均存在并相互一致，`rig-check` 与 `rig-down` 均通过。

关键事实如下：

- 图片附件 `att_6dafbde93e263470` 的 metadata 是 `kind=image`、`mimeType=image/png`，准备状态为 `ready`。
- App 最终画面 `/private/tmp/edge203-final.jpeg` 显示图片缩略图、已完成 assistant 回复和可用 Composer；没有 `Play audio`、时长、时间线或播放按钮。
- `POST /api/v1/attachments/att_6dafbde93e263470/playback-lease` 在 backend 返回 HTTP `415` 与 `ATTACHMENT_PLAYBACK_UNSUPPORTED`，没有签发 lease。
- managed gateway tap 记录 media upload create/PUT/complete 为 `200/200/201`，chat completion 为 `200`；SSE 收到用户和 assistant 的完整 completed close，最后 durable seq 为 `9`。
- frontend journal 没有 Flutter/Dart 异常；唯一 IMK 行是已知 macOS 系统诊断。backend 没有 ERROR 或 panic。

本次四格确实来自已完成、可回放的同一真实证据包，不是无证据橡皮章。复审不修改告警阈值、算法、CODEX、锚点或顺序 gate，仅销账当前 journal 水位。
