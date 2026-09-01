# EDGE-349 | 语音流中上游断线 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：错误反馈、恢复边界和终态对用户目标诚实且可继续。

## 真实路径

正式 session=`/private/tmp/anselm-rig-formal-20260902-27/sessions/20260902-051714`，新建隔离 workspace 后通过真实 Composer 的 `Voice input` 开始录音。llmtap 先对真实 `https://api.anselm.website` 完成 WebSocket upgrade，转发首个 3200 字节音频帧，再只关闭上游腿；共发生三次 `101`、三次 `speech_audio_forwarded` 和三次受控断线，分别覆盖首次连接、一次自动重连和用户点击 `Retry transcription` 后的重试。

第一次断线后 App 停止录音并显示 `Voice input was interrupted`，保留本地录音并提供 `Retry transcription` / `Delete voice draft`。点击重试后短暂显示 `Finishing 00:00`，第二次断线再次回到同一可重试卡；没有无限重连、永久录音或 Composer 锁死。由于本次真实麦克风没有产生可转写文字，顶部通知准确显示 `Voice input disconnected. No text was transcribed; your local recording is ready to retry.`。

## 五通道互证

- **录屏 / Computer Use**：`screen.mov` 为 `151.935000s / 3104x1848 / 60fps`；AX 逐状态看到入口、录音、断线卡、重试收尾和再次断线终态。
- **backend**：三次 `/api/v1/speech/asr` 均以 `200` 收口，无应用级 WARN/ERROR/panic。
- **SSE**：`messages`、`entities`、`notifications` 三流均连接并 clean EOF；语音错误没有伪造 durable 业务帧。
- **frontend console**：仅有已分类 macOS IMK 宿主诊断，无 Flutter/Dart/PlatformException/RenderFlex/Unhandled 红线。
- **LLM wire**：三次 `/v1/speech/asr` 均真实 upgrade `101`，每次都有非零音频帧转发和 `fault_injected`，未绕过受管网关线缆。

## 结论

断线是可解释、可恢复、有限次的错误终态；用户知道录音是否有可用文字，也知道下一步是重试或删除。
