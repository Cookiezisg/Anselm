# EDGE-098 activity 排队段负值

- **结论**：pass（activity projection + frontend timing model）
- **验证目标**：replay 旧审计行或时钟偏差造成 `readyAt > startedAt` 时，前端排队段钳为零，不显示负时长；后端仍正确 join 真相行，缺真相戳时诚实缺席。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/infra/store/flowrun -run 'TestListActivity_(UnionFourTablesInGanttOrder|ReadyAtAbsentWithoutTruthRow|KeysetPaginationNoSkipNoDup)' -count=1 -race -v`；`cd frontend && mise exec -- flutter test test/features/scheduler/scheduler_run_model_test.dart test/features/scheduler/scheduler_run_test.dart`；`cd testend && mise exec -- go test ./scenarios -run TestFlowrunActivity_GanttProjection -count=1 -v`
- **结果**：Flutter `66` 项通过，其中明确的 negative span clamp regression 通过；后端 activity union/join、无戳降级、keyset 通过；真实 HTTP 双 agent activity 场景通过，queue stamp 与正执行窗口一致。testend free-tier port-1 warning 是隔离 harness 预期关闭端口，不是场景失败。

Levels 2-5 are intentionally `na`: deterministic backend/frontend timing evidence exists, but no independent Computer Use frame, timing capture, beauty review, or discoverability session was made for this cell.
