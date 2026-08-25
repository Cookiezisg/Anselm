# EDGE-112 shed 孤儿 firing

- **结论**：pass（workflow 已删除时 firing 进入终态 shed，不无限重试）
- **验证目标**：firing 已进入 pending 收件箱后，若其 workflow 被删除，scheduler claim 必须把它中性终结为 `shed`；后续 drain 不得再次尝试、重复记录错误或创建 flowrun。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/scheduler -run '^TestFiring_DeletedWorkflowSheds$' -count=1 -race -v`
- **结果**：真实 scheduler regression 通过：连续两次 drain 后没有 pending firing、没有 flowrun；孤儿行在首次处理后成为终态 shed，未形成每 tick 重试的永久错误循环。

Levels 2-5 are intentionally `na`: this cell is a scheduler orphan-firing terminal-state contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
