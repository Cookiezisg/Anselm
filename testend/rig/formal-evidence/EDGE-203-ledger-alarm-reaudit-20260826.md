# EDGE-203 ledger and alarm re-audit

- `judge.py` 五级账本写入：L1 `pass`，L2-L5 `na`
- L1 law: `measure:edge203-attachment-non-audio-playback-reject`
- Evidence: `formal-evidence/EDGE-203-attachment-non-audio-playback-reject-20260826.md`
- `gen_coverage.py --check`: 通过，覆盖清册无漂移
- `anchors.py check`: 10/10 通过
- `alarms.py check`: 账本写入前后均 clean；若因五格连续写入触发统计警报，已按本格证据逐项复核并 ack

本格没有新的 managed gateway / Computer Use / 五通道真实会话，故没有把本地 focused regression 提升为
L2-L5 的正式证据。
