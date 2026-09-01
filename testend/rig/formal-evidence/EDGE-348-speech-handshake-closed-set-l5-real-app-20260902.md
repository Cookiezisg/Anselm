# EDGE-348 | 语音双工握手拒绝闭集 | L5 真实 App 证据

## 判定

L5 通过，法典 `G1`：新用户无需阅读内部文档即可找到下一步并完成目标。

## 真实用户路径

在全新隔离 workspace 的真实 App 中，用户看到 Composer 的麦克风 `Voice input` 入口，不需要知道 WebSocket、provider 或内部错误码。点击一次后，App 以完整可读的 `Voice quota. Try later.` 告知额度拒绝，并提供 dismiss；Composer 随即回到可继续输入的状态。用户能够理解“这次没有开始录音，因为额度不可用”，不会误以为仍在录音或需要反复点击。

最终 Computer Use AX 观察同时确认 `Voice input` 仍存在；实时反馈约 `1912ms` 到达。没有 retry card、隐藏设置入口或只有内部术语的错误说明。

## 五通道互证

- **录屏**：`/private/tmp/anselm-rig-formal-20260902-23/sessions/20260902-045413/screen.mov`，`3104x1848 / 60fps / 135.975000s`。
- **backend/SSE**：backend 无应用红线；三路 SSE 连接并正常 EOF，无虚假运行或丢失终态。
- **frontend console**：无 Flutter/Dart/RenderFlex/Unhandled/Exception/overflow 红线。
- **LLM wire**：真实 bootstrap 200；speech handshake 只得到一次受控 401，前端呈现闭集文案而非上游 prose。

## 结论

从零用户入口到诚实拒绝、关闭提示和继续输入的完整路径可发现且不要求用户理解内部实现。
