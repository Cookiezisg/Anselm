# EDGE-120 webhook HMAC 不匹配

- 结论：`pass`（L1 真实 HTTP 行为）；L2-L5 按当前台架边界记 `na`。
- 预期：HMAC 错误或签名头不匹配时必须返回 `401` 纯文本，不进入 workflow；正确签名仍应返回 `202`。

## 证据

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractWorkflow_TriggerWebhookSecretCarriers$' -count=1 -v
--- PASS: TestContractWorkflow_TriggerWebhookSecretCarriers (12.25s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 12.674s
```

真实日志证明：明文 secret 缺失/错误均 `401`，正确 header/query 均 `202`；HMAC 正确的自定义 `X-Custom-Sig` 返回 `202`，将同一签名放到错误的默认 header 返回 `401`，响应为 `19` 字节的纯文本错误。后端实现使用 `http.Error(w, "signature mismatch", http.StatusUnauthorized)`，不走 N1 JSON envelope。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；真实 HTTP 只用于确认鉴权和拒绝语义。
