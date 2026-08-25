# EDGE-108 catchup_one 崩溃窗不重跑

- **结论**：pass（已记账的 catch-up 在崩溃重查中不重跑）
- **验证目标**：模拟 fan-out 已提交但 `AdvanceMissedWatermark` 尚未提交时进程崩溃，重启后的 sweep 会重查同一时间窗；它必须依据“本次真正已记账的刻度”而不是窗口里仍存在的刻度决定是否补跑。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_CatchupOne_GatesOnWhatWasBooked_NotOnWhatTheWindowHeld$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：首次 sweep 产生恰好一个 activation；回拨水位重查相同缺口后返回 `n=0`、activation 数不变、pending catch-up 仍只有一个，证明崩溃窗不会重复执行。

Levels 2-5 are intentionally `na`: this cell is a trigger crash-window accounting contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
