# EDGE-258 · 新建分支不受脏区门

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestCreateBranch_DirtyIsAllowedBecauseNothingCanCollide` 通过。
- 黑盒 `TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused` 同时验证脏区下 create branch 成功，形成刻意的不对称产品行为。

## 判定

L1=`G1`：用户无需先清理当前工作即可创建新分支，入口行为与风险边界一致。L2-L5 本批未启动真实 App，记 `na`。
