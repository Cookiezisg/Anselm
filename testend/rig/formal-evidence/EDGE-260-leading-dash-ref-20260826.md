# EDGE-260 · 前导 `-` 的合法 ref

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestBranchActions_EveryRefusalHasItsOwnReason` 通过，覆盖前导短横线 ref 的参数守卫。
- 黑盒同批工作区 Git 场景通过，所有拒绝均使用 N1 envelope。

## 判定

L1=`E1`：对会被下游命令解释为选项的 ref 先返回 `422 CONVERSATION_INVALID_BRANCH`，不把安全问题交给 shell。L2-L5 本批未启动真实 App，记 `na`。
