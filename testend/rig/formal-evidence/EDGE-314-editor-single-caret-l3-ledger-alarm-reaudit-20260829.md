# EDGE-314 编辑器唯一光标铁律：L3 账本与告警复审

- target: `EDGE-314 / 编辑器唯一光标铁律 / L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-314-editor-single-caret-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` 保留 EDGE-314 的 L1/L2 裁决并只新增 `L3:B2`；L4/L5 仍未测，不改写为通过。
- `B2` 存在于 `docs/working/acceptance-loop/CODEX.md`；新增证据为非空文件，含真实 App session、全程/ROI 测量、固定帧、五通道和 durable truth。
- 所有可见变化均落在用户进入 fixture、点击嵌入字段、输入或恢复动作窗口；稳定段没有第二根 caret、回弹或自发重排。

## Alarm re-audit

写账后若 `alarms.py check` 打开 `pass-burst` 或 `discovery-collapse`，按原规则独立复核近期证据、锚点和未测等级，再 ack；不修改阈值、算法、CODEX、锚点答案或正式序列。最终状态以 `alarms.py check` 的 clean 输出为准。
