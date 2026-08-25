# EDGE-270 · 空 workDir 批量动作

## L1 focused evidence

- `backend/internal/app/conversation/workdir_group_test.go:TestWorkDirActions_RejectTheTwoUnnameableSpellings` 通过。
- `testend/scenarios/chat_workdir_group_test.go:TestChatWorkDirGroups_ArchiveWholeGroup` 与 `TestChatWorkDirGroups_DeleteWholeGroup` 通过：缺失字段与显式空值均不会误扫全 workspace，返回 `400 INVALID_REQUEST`。

## 判定

L1=`E1`：空值作为列表过滤合法，但作为批量动作目标必须大声拒绝，避免破坏性全量操作。L2-L5 本批未启动真实 App，记 `na`。
