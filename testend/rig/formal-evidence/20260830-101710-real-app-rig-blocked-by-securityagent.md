# 2026-08-30 · 新正式台架再次被 SecurityAgent 阻断

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-101710`
- 结论: `non-qualifying`；没有写入 COVERAGE 的 `pass`、`fail` 或 `na`。
- conductor 成功完成当前工作树 server/observer 构建，启动真实 macOS Anselm App、窗口 recorder、backend、ssetap 和 llmtap；App PID、窗口归属、后端端口归属、managed gateway wiring、三条 SSE 连接与 channel-5 tap 均通过 `rig-check`。
- `rig-check` 唯一失败：macOS `SecurityAgent` 高层窗口（PID `92734`，bounds=`503,188,434,202`，layer=`1000`）覆盖 Anselm 录制区域。该窗口需要用户完成系统安全交互，Computer Use 不读取未知安全窗口，也没有点击或等待它。
- `rig-down` 已正常封口：窗口录像 `13.170000s`，App、backend、ssetap、llmtap 和 recorder 均已停止，session journals 保留。
- 该 session 不能证明任何真实 App 的产品格；不计入 L2-L5，不改变 `manual_queue` 顺序。系统安全交互仍统一留到人工尾队。
