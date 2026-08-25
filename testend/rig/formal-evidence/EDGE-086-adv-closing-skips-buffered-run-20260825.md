# EDGE-086 advClosing 关停不跑缓冲 run

- **结论**：pass（scheduler shutdown regression）
- **验证目标**：Shutdown 设置 `advClosing` 后，StopPool 排空队列只跳过缓冲 run，不在不可取消上下文中执行；run 保持 running，等待下次 boot Recover。
- **Focused command**：`mise exec -- go test ./internal/app/scheduler -run 'TestPool_(ShutdownSkipsBufferedRun|SendJobRecoversOnClosedQueue|SameRunNeverDoubleDriven)' -count=1 -race -v`
- **结果**：`TestPool_ShutdownSkipsBufferedRun` PASS；缓冲 run 未 dispatch `fn_a`，状态仍为 running。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability evidence was captured for this shutdown boundary.
