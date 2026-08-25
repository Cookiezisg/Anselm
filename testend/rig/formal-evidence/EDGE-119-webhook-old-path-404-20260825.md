# EDGE-119 webhook 路径改后旧路径

- 结论：`pass`（L1 真实 HTTP 行为）；L2-L5 按当前台架边界记 `na`。
- 预期：Edit 修改 `config.path` 后，旧 URL 必须立即失效，新 URL 才能接收；catch-all registry 不应留下旧路由或不断增长 per-trigger mux。

## 证据

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractWorkflow_TriggerWebhookEditHotSwapsPath$' -count=1 -v
--- PASS: TestContractWorkflow_TriggerWebhookEditHotSwapsPath (12.19s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 12.502s
```

真实 HTTP 顺序为：旧路径 `POST` 返回 `202`；PATCH trigger 将 `before` 改为 `after`；旧路径随后返回 `404`；新路径返回 `202`；最终确认 pre/post swap 两次 run 均完成。测试退出时 search engine context canceled / lexical fallback 为收台预期日志，不改变 webhook 断言。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；真实 HTTP 只用于确认路由真相。
