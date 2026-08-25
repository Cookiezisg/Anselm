# EDGE-110 睡醒伪 fire 吸附/丢弃

- **结论**：pass（合法迟到吸附到刻度，睡醒伪 fire 超容差丢弃）
- **验证目标**：cron 回调必须归属最近且不超过 `MisfireTolerance` 的调度刻度；正常回调和短暂迟到仍吸附到该刻度，系统睡眠/墙钟跳变后远超容差的 stale callback 不得隐式补跑，应由 misfire sweep 负责记账。
- **Focused command**：`cd backend && mise exec -- go test ./internal/infra/trigger/cron -run '^TestSnapTick_SuppressesWakeArtifacts$' -count=1 -race -v`
- **结果**：真实 cron infra regression 通过：准时回调与 90 秒迟到回调都吸附到小时刻度，50 分钟后的 wake artifact 被拒绝，证明 listener 不会把睡醒伪 fire 变成隐式执行。

Levels 2-5 are intentionally `na`: this cell is a cron callback attribution contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
