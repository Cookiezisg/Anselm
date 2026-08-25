# EDGE-103 窗口上界留容差尾带

- **结论**：pass（misfire sweep 上界不越过仍可迟到的 cron 尾带）
- **验证目标**：当一个刻度落在 `now - MisfireTolerance` 之后时，本趟 sweep 不应把它记成 `missed`；否则会先占掉 dedup key，随后真实 fire 会被静默吞掉。watermark 必须停在记账窗口末端，交给下一趟 sweep。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_LeavesTheToleranceBandToALateFire$' -count=1 -race -v`
- **结果**：真实 trigger service test 通过：尾带之外的 gap 被记账，尾带内没有 `missed`，watermark 不越过尾带；测试同时验证了 cron listener 的 late-fire 语义和 dedup-key 不被提前占用。

Levels 2-5 are intentionally `na`: this cell is a trigger window-boundary contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
