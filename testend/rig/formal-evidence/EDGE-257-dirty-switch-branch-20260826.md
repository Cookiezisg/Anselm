# EDGE-257 · 脏区切分支被拒

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestSwitchBranch_DirtyIsRefusedWithANextStep` 通过。
- `testend/scenarios/chat_workdir_git_test.go:TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused` 通过，真实 HTTP 返回 `422`。

## 判定

L1=`E1`：拒绝包含可执行下一步，不以 git 原始异常替代产品文案。L2-L5 本批未启动真实 App，记 `na`。
