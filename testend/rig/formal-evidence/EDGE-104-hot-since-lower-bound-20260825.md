# EDGE-104 hotSince 下界

- **结论**：pass（重启后的死刻度立即入账，不等待 live listener 容差）
- **验证目标**：boot replay 重新注册 cron listener 后，`hotSince` 作为 misfire 窗口下界：在本进程注册之前已经死掉的刻度即使落在 `MisfireTolerance` 内也必须立即记账，用户重启后立刻查看面板不能看到虚假的空白窗口。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_ARestartDoesNotWaitOutTheGraceForDeadTicks$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：AttachReplay 后将 trigger 做旧到约 90 秒前，sweep 立即生成 missed 行，行不进入 pending；测试钉住重启 entry 的 `hotSince` 下界压过 live-listener 容差，不延迟两分钟。

Levels 2-5 are intentionally `na`: this cell is a trigger restart watermark contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
