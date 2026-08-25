# EDGE-267 · 切分支不落 marker

## L1 focused evidence

- `backend/internal/app/conversation/workdir_git_test.go:TestSwitchBranch_MovesTheHeadAndRepromsTheProjection` 通过。
- 分支切换只更新 Git 与当前 projection；驻地未变化，不在消息流中制造 workdir marker。

## 判定

L1=`F5`：历史记录只承载驻地变化，不把分支投影变化误写成另一种用户事件。L2-L5 本批未启动真实 App，记 `na`。
