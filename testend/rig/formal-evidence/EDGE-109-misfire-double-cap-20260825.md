# EDGE-109 misfire 台账双封顶

- **结论**：pass（按 trigger 单趟 cap 与 lookback 双重限制，且稀疏日程不被误截断）
- **验证目标**：旧安装首次启动时，misfire backfill 必须同时受每 trigger 最多 200 条与最多 30 天遍历窗口约束；稀疏 weekly 日程若本就低于 cap，仍须精确回溯全年，不能用固定 30 天窗口少报真实停机；水位推进后不得重复遍历。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestSweep_OldInstallBackfillIsBoundedButExact$' -count=1 -race -v`
- **结果**：真实 trigger service regression 通过：weekly 约全年 52 条全部保留，daily 只保留 lookback 内约 30 条，minutely 恰好封顶 200 条且全部在 lookback 内；第二次 sweep 返回零新增，证明双封顶与一次性记账同时成立。

Levels 2-5 are intentionally `na`: this cell is a trigger misfire backfill-bound contract; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
