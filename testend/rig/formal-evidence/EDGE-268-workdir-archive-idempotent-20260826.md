# EDGE-268 · 驻地分组批量归档重跑

## L1 focused evidence

- `backend/internal/app/conversation/workdir_group_test.go:TestArchiveWorkDir_ScopeAndCount` 通过。
- `testend/scenarios/chat_workdir_group_test.go:TestChatWorkDirGroups_ArchiveWholeGroup` 通过：首次只归档目标组，第二次返回 `archived:0`，不重复发声。

## 判定

L1=`F1`：归档结果、计数与重复动作均由服务端状态决定，幂等重跑不会漂移。L2-L5 本批未启动真实 App，记 `na`。
