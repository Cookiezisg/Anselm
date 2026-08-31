# EDGE-204 账本警报复审：真实朗读缓存

- **警报**：`gap-too-fast`
- **复审对象**：`EDGE-204|朗读缓存命中` L2-L5，登记于 `01:26:51` 至 `01:31:22 UTC`
- **真实证据**：`testend/rig/formal-evidence/EDGE-204-real-app-readaloud-cache-green-20260831.md`
- **正式 session**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-092531`
- **真实录屏**：同 session `recording.mov`，`166.938333s`

## 复审结论

警报由四个等级裁决的写入间隔触发，属于裁决速率信号，不是证据观看时长信号。本次复审重新核对同一正式 session 的五通道证据和原始时序：真实 App 的朗读入口可见；首次点击完成真实语音合成并播放；第二次点击复用本地附件，不再产生后端或上游语音调用；独立同文本同音色 API 对证明 `cached=false → true`、附件 ID 不变且只发生一次真实语音调用。

关键事实如下：

- `GET /read-aloud/availability` 返回 `available=true`，不是把不可用能力伪装成可点击按钮。
- API 缓存对的两次返回分别是 `cached=false` 与 `cached=true`，均指向 `att_8cfdd5c62a061cc3`；该对只对应一条 `/v1/audio/speech` 上游记录。
- 真实 App 首次朗读对应一条 `/api/v1/read-aloud:read` `200` 和一条 `/v1/audio/speech` `200`，随后 playback lease 与 Range/full `206` 均成功。
- 真实 App 第二次点击没有新的 `read-aloud:read`、`audio/speech` 或 chat completion；它只切换同一播放器状态。
- SSE 收到真实对话的 completed close，frontend 无 Flutter/Dart 异常，backend 无 ERROR/panic，`rig-check`/`rig-down` 通过，录屏完整收台。

这四格来自已完成、可回放的真实 App 证据包，不是无证据橡皮章。复审不修改告警阈值、算法、CODEX、锚点或顺序 gate，仅销账当前 journal 水位。
