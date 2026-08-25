# EDGE-263 · worktree 建成后切驻地失败

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestAddWorktree_TheOneShot` 锁住 worktree 建成、分支存在和驻地投影更新的边界。
- `backend/internal/app/conversation/workdir_test.go:TestUpdate_WorkDirMarkerFailureNeverBlocksTheSwitch` 验证最后一步失败不会毁掉已经可用的外部状态。

## 判定

L1=`F1`：半成功状态诚实保留 worktree 与原线程，不回滚或静默破坏已完成的文件系统动作。L2-L5 本批未启动真实 App，记 `na`。
