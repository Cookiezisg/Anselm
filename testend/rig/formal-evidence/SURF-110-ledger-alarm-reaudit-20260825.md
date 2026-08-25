# SURF-110 ledger and alarm re-audit

## Evidence decision

本次五级裁决只针对最终真实成功路径：`SURF-110-stage-agent-investigation-20260825.md` 与 session 内五通道证据共同作为依据。两次错误 `create_agent` 参数、一次取消收尾 WARN、输入桥错位和模型重复推理均保留为负事实，不被改写为绿证据，也不阻挡对修正后正向路径的裁决。

## Ledger integrity

- `anchors.py check`: 10/10 calibration passed，judge unlocked。
- `gen_coverage.py --check`: 848 rows, 492 carried judgments, 0 tombstones。
- SURF-109 已先完成五级，故 SURF-110 五个等级按顺序写入，不绕过 predecessor gate。
- 本次不修改阈值、算法、CODEX、anchor set 或 gate 规则。

## Alarm handling

写入五格后，统计警报若因短窗口触发，只能使用本文件与同 session 五通道事实逐条复核，并串行 ack；不得通过改阈值或排除本格消警。复核结论：间隔过快和发现率变化属于连续验收操作造成的统计信号，正向证据独立、完整、无缺失，因此 ack；随后 `alarms.py check` 必须回到 clean。
