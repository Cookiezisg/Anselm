# EDGE-249 · 后台裸 ctx 播种缺失

## L1 focused evidence

- `backend/internal/bootstrap/background_ctx_test.go:TestBackgroundPaths_RequireWorkspaceSeeding` 通过：后台 ws-scoped 入口必须播种 workspace context，裸 context 返回 `MISSING_WORKSPACE_ID`，不会静默跨 workspace。
- `backend/internal/bootstrap/build.go` 的后台循环按 workspace 派生 context；启动/关停 focused suite 同批通过。

## 判定

L1=`F5`：后台自动化链路缺身份时大声失败而不是生成错误数据。L2-L5 本轮未启动真实后台灾难路径 App session，记 `na`。
