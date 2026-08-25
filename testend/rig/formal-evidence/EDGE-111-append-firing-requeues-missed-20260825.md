# EDGE-111 AppendFiring 撞键返已存在行

- **结论**：pass（missed 行被真 fire 救回 pending，终态行不被伪造为新 run）
- **验证目标**：同一 cron 刻度已经被 misfire sweep 记为 `missed` 后，真实 fire 撞上 dedup key 时，必须复用并 requeue 原 firing、更新 activation 血缘和计数；不能静默吞掉真实执行，也不能凭空新建第二行。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestFanOut_AFireOnATickBookedMissedRequeuesItIntoTheRun$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：原 missed 行变为唯一 pending run，missed 查询不再包含该行，activation `firingCount=1`，且 firing 的 `activation_id` 正确指回本次 activation。

Levels 2-5 are intentionally `na`: this cell is a trigger dedup/requeue data-truth contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
