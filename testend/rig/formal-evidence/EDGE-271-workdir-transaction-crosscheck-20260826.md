# EDGE-271 · 分组事务交叉核对

## L1 focused evidence

- `backend/internal/app/conversation/workdir_group_test.go:TestWorkDirActions_AreAllOrNothing` 通过四个 archive/delete 子场景。
- 影响行数与预读 id 集不一致时事务回滚，既不留下半个组状态，也不伪报成功。

## 判定

L1=`F5`：分组动作是原子 durable 变化，不会在中途失败后留下不可解释的部分归档/删除。L2-L5 本批未启动真实 App，记 `na`。
