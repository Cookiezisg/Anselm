# EDGE-313 · undo 手动物理输入复验（不计账）

- 原始功能观察 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-210421`；用户在真实 App 中先输入正文，再粘贴 `EDITED`，物理按下 macOS `Command+Z`。
- 产品结果：正文保留原始内容，仅移除最近粘贴的 `EDITED`。这证明 undo 的用户语义符合预期：最近一次独立编辑可单独撤销，不会回滚更早正文。
- 该 session 的 frontend journal 同时出现 `16` 条 `Null check operator used on a null value`，故整轮不能作为 L2 通过证据；backend、三路 SSE 与 LLM tap 没有对应应用红线。
- 后续重建后的干净台架 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-215348`：启动、正文编辑、持续观察期间 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；Computer Use 组合键未可靠完成 undo，因此不把它冒充完整撤销复验。
- 再次收台 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-220058`：五通道归属、录屏和优雅收台均通过，frontend 无应用红线，画面保持原始正文；本轮没有可证明的 `EDITED` 中间态与物理快捷键操作链，因此仍不计 L2。
- 为让下一次真实红线可定位，`installErrorHandlers` 现将 `FlutterErrorDetails.stack` 与压缩错误行一起写入 frontend console，并同步前端平台文档；这不是对旧 16 条错误的事后归因。
- 新增宿主回归 `undo restores the host document after an inserted edit without an error`；focused Flutter editor/library/error tests：`126` 项通过。本次不写 `judge.py`，不推进批次，不改变 `EDGE-313=✓~~~~`。
