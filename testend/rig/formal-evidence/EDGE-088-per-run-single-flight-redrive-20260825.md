# EDGE-088 per-run 单飞 + redrive

- **结论**：pass（scheduler concurrency regression）
- **验证目标**：同一 run 并发收到多个 advance 时，最多一个 goroutine 进入驱动；在节点执行中到达的信号只置 redrive，活动驱动完成后再走一次，不能重复执行副作用节点。
- **Focused command**：`mise exec -- go test ./internal/app/scheduler -run 'TestPool_(ShutdownSkipsBufferedRun|SendJobRecoversOnClosedQueue|SameRunNeverDoubleDriven)' -count=1 -race -v`
- **结果**：`TestPool_SameRunNeverDoubleDriven` PASS；连续三次 advance 信号下 `fn_a` 实际执行恰一次，run 完成。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability evidence was captured for this scheduler concurrency invariant.
