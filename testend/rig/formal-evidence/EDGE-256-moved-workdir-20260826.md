# EDGE-256 · 驻地目录被移走

## L1 focused evidence

- `backend/internal/app/conversation/workdir_test.go` 覆盖驻地不存在/不可用投影。
- `backend/internal/app/conversation/workdir_git_test.go:TestWorkDirInfo_ListsBranchesAndWorktrees` 与 `TestGitActions_NotARepoIsOneAnswerForEveryFlavour` 通过；路径保留，git 能力不伪造。

## 判定

L1=`F1`：目录消失时返回原 path 与 `exists=false`，不会静默回落到后端目录。L2-L5 本批未启动真实 App，记 `na`。
