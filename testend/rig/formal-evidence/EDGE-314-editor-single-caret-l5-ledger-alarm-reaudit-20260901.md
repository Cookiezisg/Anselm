# EDGE-314 编辑器唯一光标：L5 账本与警报独立复核

- target judgment: `EDGE|编辑器唯一光标铁律|L5`
- primary evidence: `testend/rig/formal-evidence/EDGE-314-editor-single-caret-l5-real-app-boundary-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-203612`

## Alarm disposition

写入 L5 适用性裁决后，三曲线再次打开 `discovery-collapse`：近 50 条 live judgment 的 fail
占比为 `0.0%`，低于 `5%` 地板。独立复核确认该信号不是被掩盖的产品失败：

- L5 没有把缺少证据写成 `na`；证据文件包含真实 App 普通用户编辑路径、录屏、五通道和 durable SQLite 核对。
- L5 的对象是唯一 caret 这个编辑器不变量。它没有独立入口、tooltip、命令或快捷键，G1 因而确实不适用；L4 已以 C1 复核该不变量的产品成品质量。
- 本场与前一场的输入桥分叉已严格分开：前一场被标为 invalid 且未写账；本场只使用输入字符后立即 BackSpace，封口 SQLite 与最终 UI 完全一致。
- 10-anchor 校准通过，`gen_coverage.py --check` 仍应保持 `848 rows / 848 carried judgments / 0 tombstones`。

## Result

该警报按独立复核销账。EDGE-314 L5 的 `na` 是记录了真实边界的适用性裁决，不是豁免；五级标准、
阈值、法典、锚点和顺序门均未修改。
