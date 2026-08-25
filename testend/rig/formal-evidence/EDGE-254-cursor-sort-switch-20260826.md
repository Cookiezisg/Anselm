# EDGE-254 · keyset 排序切换丢游标

## L1 focused evidence

- `backend/internal/infra/store/conversation/conversation_test.go:TestList_CursorRejectsChangedQueryAxes` 的 `sort` 子场景通过。
- `TestList_SortParam`、`TestList_SortByName_CursorPaging` 与 `testend/scenarios/chat_test.go:TestChat_RailSortByName` 通过。

## 判定

L1=`F1`：游标绑定完整查询轴；从 activity 切换 name 不复用旧游标，避免跨排序漏行或重行。L2-L5 本批未启动真实 App，记 `na`。
