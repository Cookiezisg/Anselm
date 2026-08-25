# EDGE-107 catchup_one 补一个

- **结论**：pass（只补最近一个错过刻度，且恰好一次）
- **验证目标**：`misfirePolicy=catchup_one` 跨过多个 cron 刻度后，只把本轮真正记账的最近一个刻度重新置为可运行 pending；较早刻度保持 missed，重新 sweep 不得再产生第二个 catch-up。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_CatchupOne_FiresExactlyOnce$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：恰好一个 runnable catch-up，catch-up 刻度不再出现在 missed 中，较早刻度仍为 missed，第二次 sweep 不产生第二个 catch-up。

Levels 2-5 are intentionally `na`: this cell is a trigger misfire-policy contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
