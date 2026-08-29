# EDGE-350 语音帧越界 · 五通道实证

- **判定**：L2 `pass`。
- **真实路径**：在正式 conductor 启动的真实 macOS App、sidecar、三路 SSE、llmtap 和窗口录屏运行中，使用独立一次性 WebSocket witness 连接 App 的 `/api/v1/speech/asr`，分别注入 `256 KiB + 1` 的 binary audio frame 与 `{"type":"pause"}` 非法控制帧。
- **用户面结果**：前者收到 `{"type":"error","code":"SPEECH_AUDIO_FRAME_INVALID"}`，后者收到 `{"type":"error","code":"SPEECH_CONTROL_INVALID"}`；两条连接随后收口。两个坏帧均未被转发到上游 fixture。
- **台架归属**：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-005848`；`rig-check` 五通道通过，`rig-down` 录屏 `52.511667s` 并无残留进程。
- **五通道**：backend journal 无 `panic/FATAL/WARN/ERROR`；frontend journal 无 `FlutterError/DartError/RenderFlex/RenderBox/Unhandled/PlatformException`；ssetap 三流均连接并在收台时 EOF；llmtap 记录 challenge `200` 与两次 speech upgrade `101`；窗口录屏只含 Anselm 主界面且可由 `ffprobe` 读取。
- **实现修复**：原 `SetReadLimit(256 KiB)` 会在业务层观察到越界前直接返回 `ErrReadLimit`，导致 typed error 丢失。改为 `NextReader` + `LimitReader(256 KiB+1)`，观察越界首字节后发送闭集错误并关闭；前端将两个码映射为可重试、带下一步的明确文案。
- **回归**：`go test ./internal/transport/httpapi/handlers ./internal/app/speech`；Flutter speech/composer focused tests `46/46`。
- **法条**：E1、F2、F3、F4。

L3（顺滑）、L4（独立视觉 craft）、L5（可发现性）本次均不判定；这是受控协议注入，不伪装成用户自然旅程。
