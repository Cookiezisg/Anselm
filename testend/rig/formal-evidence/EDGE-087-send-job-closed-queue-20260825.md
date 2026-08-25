# EDGE-087 sendJob 撞已关队列

- **结论**：pass（scheduler shutdown regression）
- **验证目标**：feeder 在 StopPool 关闭队列后发送，`sendJob` recover `send on closed channel`，清理 dedup 槽，不使进程崩溃；run 可由后续 Recover 重新入队。
- **Focused command**：`mise exec -- go test ./internal/app/scheduler -run 'TestPool_(ShutdownSkipsBufferedRun|SendJobRecoversOnClosedQueue|SameRunNeverDoubleDriven)' -count=1 -race -v`
- **结果**：`TestPool_SendJobRecoversOnClosedQueue` PASS；关闭队列上的迟到入队未 panic，`advQueued[run_x]` 已清除。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability evidence was captured for this shutdown race.
