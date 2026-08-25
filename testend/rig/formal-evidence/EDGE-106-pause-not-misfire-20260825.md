# EDGE-106 暂停期间的错过不算 misfire

- **结论**：pass（暂停窗口按用户意图闭合，不产生 missed 台账）
- **验证目标**：cron trigger 暂停数十分钟后，`SweepMisfires` 不得把暂停期间的刻度记为 missed；恢复时必须把暂停窗口静默闭合，后续 sweep 仍不得 resurrect 这些刻度。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_PauseIsIntentNotMisfire$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：暂停期间 sweep 返回 `n=0` 且没有 missed rows；resume 后再次 sweep 仍为 `n=0` 且没有 missed rows，证明用户主动暂停不会被伪报成 misfire。

Levels 2-5 are intentionally `na`: this cell is a trigger accounting contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
