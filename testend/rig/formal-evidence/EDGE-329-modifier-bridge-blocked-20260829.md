# EDGE-329 · 快捷键录制后吞键 · 物理输入桥阻塞复验

本次不计入账本、不推进批次。真实 App 已进入 Settings → Shortcuts 的第一个快捷键录制态；分别通过 Computer Use 发送 `super+j` 和 `cmd+j`，App 均真实显示 `A chord must include a modifier (⌘/Ctrl…)`，没有发生改绑。录制态仍在，故无法继续验证“录制完成后交还键盘、后续组合键不被吞掉”。

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-141110`
- workspace: `ws_26b82c114edb549f`
- App/window: `29133` / `6035`
- recording: `screen.mov`, `80.995000s`; fixed frame: `evidence/EDGE-329-modifier-bridge-blocked.jpeg`
- `rig-check.sh` 与 `rig-down.sh` 通过，五通道归属完整；backend 无 WARN/ERROR/panic，frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled 红线。
- 既有 focused test `frontend/test/features/settings/s6_shortcuts_test.dart` 仍覆盖录制完成后的 `unfocus()` 契约；但在物理修饰键输入桥可用前，L2 继续为 `na`。

结论：这是测试仪器限制，不是产品通过，也不是产品失败；保持 `EDGE-329=✓~~~~`，不写 `judge.py`。
