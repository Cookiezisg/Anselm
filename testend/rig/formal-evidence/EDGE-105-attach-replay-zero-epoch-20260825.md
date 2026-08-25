# EDGE-105 AttachReplay 零值纪元

- **结论**：pass（boot replay 与实时首次挂载的 misfire 归属分离）
- **验证目标**：boot replay 的 workflow 引用在本进程启动前已存在，必须用零值 attach epoch 记它真正错过的停机缺口；运行中刚 `Attach` 的 workflow 只能从挂载时刻之后计 missed，绝不能把挂载前的刻度归给它。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_LiveAttachEpochBoundsItsOwnMissedTicks$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：同一 cron trigger 上，`wf_old` 经 `AttachReplay` 被正确记入缺口，`wf_new` 经实时 `Attach` 不被追溯记账；测试同时验证 listener 共用、引用集合与 misfire workflow 归属。

Levels 2-5 are intentionally `na`: this cell is a trigger attach-epoch attribution contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
