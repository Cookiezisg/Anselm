# EDGE-291 · memory 更新保留策展

## L1 focused evidence

- `backend/internal/app/memory/memory_test.go:TestUpsert_UpdatePreservesUserCuration` 通过：AI 更新保留用户已有的 `pinned` 与 `source`。
- `backend/internal/app/memory/memory_test.go:TestUpsert_CreateThenUpdate_Notifies` 通过：更新仍产生权威通知。

## 判定

L1=`F1`：持久化行保留用户策展字段。L2-L5 本批未启动真实 App，记 `na`。
