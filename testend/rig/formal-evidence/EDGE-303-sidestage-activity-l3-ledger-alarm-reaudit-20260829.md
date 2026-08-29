# EDGE-303 L3 账本警报复核

- 本次新裁决前，`alarms.py check` 为 clean；写入真实 L3 后，唯一打开 `discovery-collapse`。
- 触发原因是近 50 条 live judgment 的 fail share 为 `0.0% < 5%`。这不是跳过证据：本格有同一真实 App session 的五通道记录和逐帧测量，且明确记录了一次目标布局重排，没有把它写成零变化。
- `anchors.py check`：`10/10`，校准仍在 4 小时窗口；`gen_coverage.py --check`：`848 rows, 848 carried judgments, 0 tombstones`。
- 复核结论：本次 alarm 是当前批次大量成功但证据链完整的统计信号；不修改阈值、法典、锚点或 gate。该信号已按复核结果销账，后续继续由同一阈值监控。
