# EDGE-313 · 编辑器 undo 的 Computer Use 输入桥阻塞（不计账）

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-094016`
- 权限处理后的第二次干净复验 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-094654`；该 session 再次从空文档输入同一基线、编辑为 `... EDITED`，`command+z` 仍未撤销，随后正常收台。
- data=`/private/tmp/anselm-data-edge313-20260828-r3`
- 本次从干净文档开始：真实 App 中输入 `Original paragraph for undo.`，等待草稿转正并确认页面显示 `25 chars`；再在正文尾部输入 ` EDITED`，页面真实显示 `Original paragraph for undo. EDITED`。
- 在正文可见且完成真实编辑后，依次尝试 `super+z`、`meta+z`、`cmd+z`、`ctrl+z`；正文均未撤销。系统 Edit 菜单中的 Undo/Redo 也持续为 disabled。普通单键 `x` 可以进入正文，说明这不是 App 未启动或窗口未激活。
- 窄命名复验 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-095012`：`Super_L+z`、`Meta_L+z`、`Control_L+z` 均未撤销；`Super+z` 与 `Command_L+z` 被 Computer Use 服务判为不支持的键名。该 session 仅用于输入桥诊断，不计 L2。
- 同一会话的前一段曾有误点击和 `EDITEDx`，已与本次干净基线区分；整个 session 不作为 L2 证据。
- `rig-down` 已完成，screen.mov 与五通道 journal 已封口；本记录仅保存观察器/input-path 事实，不写 `judge.py`，不改变 `EDGE-313` 的 `✓~~~~`。

源码核对：`frontend/lib/core/editor/an_editor.dart` 使用
`createDefaultDocumentEditor(..., isHistoryEnabled: true)`，并挂载上游
`undoWhenCmdZOrCtrlZIsPressed`；定向 Flutter 回归 `an_editor_test.dart`、
`an_presenter_differential_test.dart`、`library_test.dart` 共 `125` 项通过。

结论：这是 Computer Use 在 macOS Flutter 上无法提供可信 Command/Control 修饰键的已知输入桥边界，不能据此判产品通过或失败。后续必须使用真实物理输入或修复后的合法 Computer Use bridge 原地重测；不得用 `set_value`、直接改数据库或脚本调用 editor API 冒充用户 undo。
