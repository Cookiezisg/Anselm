# EDGE-259 · 切分支名拼错

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestBranchActions_EveryRefusalHasItsOwnReason` 通过。
- 黑盒 `TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused` 验证远端存在但本地不可用的分支名返回 `404 CONVERSATION_BRANCH_NOT_FOUND`，不触发 git DWIM。

## 判定

L1=`E1`：拼错 ref 大声拒绝并指向具体原因，不静默创建跟踪分支。L2-L5 本批未启动真实 App，记 `na`。
