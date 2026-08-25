# EDGE-094 mode=0 老库升级

- **结论**：pass（真实落盘 SQLite Compact migration）
- **验证目标**：旧库 `auto_vacuum=NONE` 通过用户 Compact 一次性升级到 `INCREMENTAL`，同时回收死空间、不丢行；升级跨重启持久，第二次 Compact 不重复报告迁移。
- **Focused command**：`cd backend && mise exec -- go test ./internal/infra/db ./internal/app/storage -run 'Test(Compact_UpgradesModeZeroDBAndReclaims|Compact_ReclaimsOnIncrementalDB_NoMigration|Service_StatThenCompact)' -count=1 -race -v`
- **结果**：mode=0 真实文件测试通过：Compact 回收死空间、`migrated=true`、存活行完整、重开同一旧 DSN 仍读 `INCREMENTAL`；第二次 Compact `migrated=false`；已是 INCREMENTAL 的普通 Compact 与 app storage 映射同组通过。

Levels 2-5 are intentionally `na`: this is an infra/db migration invariant; no independent real-app frame, timing, beauty, or discoverability capture was made for this cell.
