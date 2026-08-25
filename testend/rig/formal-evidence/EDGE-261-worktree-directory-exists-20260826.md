# EDGE-261 · worktree 目录已存在

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused` 通过。
- 冲突目录通过真实 worktree 动作返回 `409 CONVERSATION_WORKTREE_EXISTS`，不会接管已有目录。

## 判定

L1=`E1`：冲突对象、路径和下一步由产品错误 envelope 明确表达。L2-L5 本批未启动真实 App，记 `na`。
