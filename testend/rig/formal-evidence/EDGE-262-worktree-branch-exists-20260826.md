# EDGE-262 · worktree 分支已存在

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused` 通过。
- 已保留分支会被复用；若分支已在别处 checkout，动作拒绝并保留 git stderr 事实。

## 判定

L1=`F1`：worktree 投影与 Git 实际分支状态一致，不伪造新分支。L2-L5 本批未启动真实 App，记 `na`。
