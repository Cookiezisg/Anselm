# EDGE-232 · 模型目录运行时刷新失败

## L1 focused evidence

- `backend/internal/infra/llm/modelcatalog_test.go:TestCatalogRefresh_FailSilent` 将上游指向死端口，刷新失败后既有 catalog 仍可 Describe，刷新不 panic、不清空 picker；通过。
- 同文件 cache load/corrupt cache 断言拒绝坏缓存且不污染 active catalog；通过。

## 判定

L1=`E7`：失败与 settled-empty 保持分流，last-good 目录不塌。L2-L5 本轮无新的真实 App 五通道 session，记 `na`。
