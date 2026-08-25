# EDGE-092 磁盘回收闸

- **结论**：pass（真实落盘 SQLite + infra/db gate）
- **验证目标**：保留清理删除真实行后，死空间达到 `25%` 或 `128 MiB` 任一门槛才执行 `incremental_vacuum`；日常小 churn 两道门都不过时文件不动；回收不删除存活行。
- **Focused command**：`cd backend && mise exec -- go test ./internal/infra/db ./internal/app/storage -run 'Test(ReclaimFreePages_|Stat_|TestService_StatThenCompact)' -count=1 -race -v`
- **结果**：`TestReclaimFreePages_ShrinksFileAndKeepsRows` 通过，真实文件 `61665280 -> 61665280`（DELETE 后不缩）`-> 12341248`（回收后缩小），回收 `49.3MB`，`3000` 行存活；`TestReclaimFreePages_GateHoldsBackRoutineChurn` 通过，约 `5%` 删除低于比例与绝对字节两道门，回收 `0` 且文件不变；`TestStat_ReportsDeadSpaceAndDrops` 与 app storage 映射测试通过；整组 `-race` 通过。

这证明的是自动保留清理后的空间回收闸，不是用户主动 Compact。后者无闸路径在相邻 storage/db 测试中独立覆盖；本格不把两种语义混为一谈。

Levels 2-5 are intentionally `na`: this is an infra/db disk-governance invariant; no independent real-app Computer Use frame, timing, beauty, or discoverability capture was made for this cell.
