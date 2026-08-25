# EDGE-296 · 触点 deleted 行借名

## L1 focused evidence

- `backend/internal/app/touchpoint/touchpoint_test.go:TestRecord_HydrationMissThenSnapshotStaysEmpty` 通过：活体 hydrate 不到时保持诚实空名。
- `backend/internal/infra/store/touchpoint/touchpoint_test.go:TestUpsert_DeletedRowBorrowsSiblingName` 通过：删除行不从无关兄弟实体借名。

## 判定

L1=`F1`：已删除实体的历史名称不会被错误借用。L2-L5 本批未启动真实 App，记 `na`。
