# EDGE-313 编辑器 undo 全量重建：L3 账本与告警复审

- target: `EDGE-313 / 编辑器 undo 全量重建 / L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-313-editor-undo-rebuild-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` 保留 EDGE-313 的 L1/L2 裁决并只新增 `L3:B2`；L4/L5 仍未测，不改写为通过。
- `B2` 存在于 `docs/working/acceptance-loop/CODEX.md`；新增证据为非空文件，含真实 App session、稳定帧、1fps/10fps 测量、五通道和 durable truth。
- 两次窗口整体缩放已明确标成宿主/手动操作边界；产品判断只使用用户编辑/撤销窗口及其后稳定段，不把观测环境现象伪装成 App 平滑度。

## Alarm re-audit

写账后若 `alarms.py check` 打开 `pass-burst` 或 `discovery-collapse`，按原规则独立复核近期证据、锚点和未测等级，再 ack；不修改阈值、算法、CODEX、锚点答案或正式序列。最终状态以 `alarms.py check` 的 clean 输出为准。
