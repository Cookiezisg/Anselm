# EDGE-292 · todo 全完成后被问清单

## L1 focused evidence

- `backend/internal/app/todo/todo_test.go:TestReadRendered_IncludesCompleted` 通过：清单查询仍返回已完成项目。
- `backend/internal/app/todo/todo_test.go:TestSystemReminder_InjectsOnlyWhenOpen` 通过：无 open 项时不注入 reminder。

## 判定

L1=`F1`：DB 清单与渲染视图一致，完成态不会被误报为待办。L2-L5 本批未启动真实 App，记 `na`。
