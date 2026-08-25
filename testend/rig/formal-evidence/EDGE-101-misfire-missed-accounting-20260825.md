# EDGE-101 misfire 记账不补跑

- **结论**：pass（停机错过的 cron 刻度只记账，不自动补跑）
- **验证目标**：后端重启跨过 cron 刻度后，每个错过的刻度落一条 `missed` firing，`createdAt` 回拨到该刻度；missed 行不携带 flowrun、不进入 pending、不被后续 sweep 重复记账。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/app/trigger -run 'Test(Sweep_BooksMissedTicksIdempotently|Sweep_ARestartDoesNotWaitOutTheGraceForDeadTicks|Sweep_LeavesTheToleranceBandToALateFire)' -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_MisfireMissedAccounting$' -count=1 -v`
- **结果**：trigger focused `-race` 三项通过；真实 HTTP scenario 对 sidecar 执行 `SIGKILL`，跨过一分钟边界后重启，boot 记录 `missed=1`，firing 查询、workspace 汇总、时间窗口和 flowrun-stats 均通过；missed 行没有 flowrun 且保持 missed。free-tier port-1 warning 与 search shutdown warning 是隔离 harness 预期噪声，不是场景失败。

Levels 2-5 are intentionally `na`: this cell is a trigger ledger/restart contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
