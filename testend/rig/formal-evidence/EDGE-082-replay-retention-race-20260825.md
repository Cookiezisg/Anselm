# EDGE-082 replay 与保留清理竞速

- **结论**：pass（实现/回归证据）
- **验证目标**：保留清理在父表删除处重新检查终态；`:replay` 将 `failed` guarded-update 为 `running` 后，清理不能删除该 run。反向的 stale replay 必须返回 `ErrNotReplayable`。
- **实现证据**：`backend/internal/infra/store/flowrun/retention.go` 的父表 `DELETE` 同时限制 `status IN ('completed','failed','cancelled')`；`backend/internal/infra/store/flowrun/flowrun.go` 的 `ReopenForReplay` 同时限制 `WHERE id=? AND status='failed'`。
- **Focused command**：`mise exec -- go test ./internal/infra/store/flowrun -run 'Test(ReopenForReplay_GuardsTheReversal|PurgeTerminalRunsBefore_)' -count=1 -v`
- **结果**：`TestReopenForReplay_GuardsTheReversal`、5 个 `PurgeTerminalRunsBefore_*` 测试全部 PASS；随后 scheduler race focused test `TestCancelRun_GuardLoserLeavesNaturalTerminalAlone` PASS。
- **边界说明**：生产 SQLite 由 `SetMaxOpenConns(1)` 串行化事务；本证据不添加测试专用生产 hook，而锁住两个真实 guarded write 的 first-wins 语义。

Levels 2-5 are intentionally `na`: no real-app frame, timing, beauty, or discoverability evidence was captured for this storage race.
