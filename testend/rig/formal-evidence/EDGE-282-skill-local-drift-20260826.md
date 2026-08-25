# EDGE-282 · skill 本地改动漂移

## L1 focused evidence

- `backend/internal/app/skill/install_test.go:TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate` 通过：本地改动后非 force update 返回 ErrLocallyModified，force 才覆盖上游。
- 同测试验证 allowed-tools 变化会重置 trust gate，避免旧授权静默延续。

## 判定

L1=`E1`：冲突原因、阻断状态与下一步 force 操作均有明确语义。L2-L5 本批未启动真实 App，记 `na`。
