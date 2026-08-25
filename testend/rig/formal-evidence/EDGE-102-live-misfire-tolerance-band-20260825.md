# EDGE-102 睡眠期 misfire（进程仍活）

- **结论**：pass（活进程睡眠缺口记账，仍可迟到的尾带不被偷占）
- **验证目标**：进程没有重启但 cron listener 经历墙钟缺口时，`SweepMisfires` 记录尾带之前的错过刻度；对仍在 `MisfireTolerance` 内、可能迟到送达的刻度不落 `missed`，并且 watermark 不越过这条尾带。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_LeavesTheToleranceBandToALateFire$' -count=1 -race -v`
- **结果**：真实 `Service.SweepMisfires` 与 cron listener 状态测试通过；由 `ageHotSince` 将当前 listener 的注册纪元回拨，精确复现“进程仍活但睡过墙钟”的状态，确认 gap 外刻度被记账、尾带不被记账、watermark 停在尾带之前。实际等待一小时不可重复且会污染开发机，故不伪造真实睡眠时长或 App 五通道证据。

Levels 2-5 are intentionally `na`: this cell is a trigger timing/watermark contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
