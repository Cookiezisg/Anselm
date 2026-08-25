# EDGE-251 · 删最后一个 workspace

## L1 focused evidence

- `backend/internal/app/workspace/workspace_test.go:TestDelete_LastRefused` 通过。
- `testend/scenarios/platform_test.go:TestPlatform_WorkspaceLifecycle` 通过，真实 HTTP 删除最后 workspace 返回 `422`，不是静默删除。

## 判定

L1=`F1`：工作区删除保护在 app 层与黑盒线缆一致。L2-L5 本批未启动真实 App，记 `na`。
