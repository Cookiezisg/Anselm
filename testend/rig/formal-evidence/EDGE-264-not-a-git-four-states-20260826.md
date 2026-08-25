# EDGE-264 · 这里没有 git 四情形

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestGitActions_NotARepoIsOneAnswerForEveryFlavour` 通过。
- 未挂、路径消失、普通目录与 git 不可用四种形态统一返回 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`，读侧仍返回诚实投影。

## 判定

L1=`E1`：产品不把四种底层状态泄漏成互相矛盾的错误文案。L2-L5 本批未启动真实 App，记 `na`。
