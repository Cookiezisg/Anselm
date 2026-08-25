# EDGE-289 · @ 一个 fork skill

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestPreauthorizeActiveSkill_InlineGrantsForkSkips` 通过：inline skill 可预授权，fork skill 的 mention 不授予父回合预授权。
- `backend/internal/app/skill/activate.go` 明确 fork 的执行语义是 activate_skill 派 subagent，不把 @ mention 伪装成父回合执行。

## 判定

L1=`G1`：用户从 @ 入口不会被带入错误的 fork 执行模型，能力边界与入口语义一致。L2-L5 本批未启动真实 App，记 `na`。
