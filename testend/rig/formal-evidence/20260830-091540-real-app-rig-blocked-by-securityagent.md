# 2026-08-30 · 新构建真实 App 台架被 SecurityAgent 阻断

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-091540`
- 结论: `non-qualifying`，没有写入 COVERAGE 的 `pass` 或 `fail`。
- 新构建已通过：`make -C frontend app` 重新编译当前工作树，真实 App 启动后进入 Settings，Flutter 控制台未见 Dart/RenderFlex/应用级异常；后端、ssetap、llmtap 与窗口录像均由本次 conductor 归属。
- `rig-check` 通过 backend health、三条 SSE、managed gateway wiring、App PID/window 归属和 recorder lifecycle；唯一失败为录制区域上方的 macOS `SecurityAgent` 高层窗口（window `7148`，bounds `503,188,434,202`）。
- 先出现的 `CoreServicesUIAgent` 过期提示“应用程序 anselm 已不再打开”已尝试关闭；其退场后 `SecurityAgent` 仍在，Computer Use 无法读取其内容，故没有继续点击未知安全窗口。
- `rig-down` 已正常封口：录像 `94.045s`，backend/ssetap/llmtap/App 均已停止，journal 保留。该 session 不能证明任何真实 App 的 L2-L5，也不能替代后续无遮挡现场。
- 这属于人工尾阶段的系统安全交互，不改变标准、不写 `na`，也不改变 `manual_queue` 顺序。
