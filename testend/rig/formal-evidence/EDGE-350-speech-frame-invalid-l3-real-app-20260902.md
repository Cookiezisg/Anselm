# EDGE-350 | 语音帧越界 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：非法语音帧会得到明确错误、有限恢复动作和真实可继续的终态。

## 真实路径

正式 session=`/private/tmp/anselm-rig-formal-20260902-29/sessions/20260902-053042`。真实 App 从 Composer 的
`Voice input` 开始录音；llmtap 对真实 `https://api.anselm.website` 完成 WebSocket upgrade，转发首个 `3200`
字节音频帧，再从真实上游腿返回 `SPEECH_AUDIO_FRAME_INVALID`。App 停止录音，准确显示“这段语音数据格式不受支持。
尚未转写出文字，请重新录音”，并提供 `Retry transcription` / `Delete voice draft`。点击重试后连接不再命中一次性
扰动预算，Composer 正常恢复为空态，未悬挂或无限重试。

## 五通道互证

- **录屏 / Computer Use**：`screen.mov`=`68.185000s / 3104x1848 / 60fps`；AX 逐状态看到入口、错误通知、重试卡、
  重试完成和可用 Composer。
- **backend**：两次 `/api/v1/speech/asr` 均以 `200` 收口，无应用级 WARN/ERROR/panic。
- **SSE**：`messages`、`entities`、`notifications` 三流均连接并 clean EOF；没有虚假 durable 业务帧。
- **frontend console**：无 Flutter/Dart/PlatformException/RenderFlex/Unhandled/Exception/overflow 红线，仅有已分类
  macOS IMK 宿主诊断。
- **LLM wire**：一次真实 upgrade `101` 后有 `speech_audio_forwarded size=3200`、`speech_error_forwarded size=52` 和
  `fault_injected`；重试连接透明通过真实网关，未绕过 wire。

## 结论

协议错误在真实产品链路中被收敛成可理解、可操作且有限的用户状态；重试动作可以正常结束。
