# EDGE-269 · 驻地分组批量删除范围

## L1 focused evidence

- `backend/internal/app/conversation/workdir_group_test.go:TestDeleteWorkDir_SoftDeletesAndCascades` 与 `TestDeleteWorkDir_NeverTouchesAMessageRow` 通过。
- `testend/scenarios/chat_workdir_group_test.go:TestChatWorkDirGroups_DeleteWholeGroup` 通过：跨归档态删除，置顶线程存活，消息行与文件系统不被删除。

## 判定

L1=`F1`：组删除范围严格落在业务表软删与逐行级联，不越界到 durable message 或用户目录。L2-L5 本批未启动真实 App，记 `na`。
