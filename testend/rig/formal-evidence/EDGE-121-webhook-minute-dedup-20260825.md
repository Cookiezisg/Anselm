# EDGE-121 webhook 分钟桶去重

- 结论：`pass`（L1 真实 HTTP 行为）；L2-L5 按当前台架边界记 `na`。
- 预期：同一秒内相同 raw body 的网络重试折叠为同一条 firing/run；不同 body 必须保持独立执行。

## 证据

```text
cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_WebhookDuplicateBodyDedupsWithinMinute$' -count=1 -v
--- PASS: TestTrigger_WebhookDuplicateBodyDedupsWithinMinute (13.01s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 13.587s
```

真实 HTTP 场景中同一 raw body 连发两次，两次请求均接受但最终只保留一条 started firing 和一条 completed webhook-origin flowrun；随后发送不同 body，第二条 firing/run 独立产生。收台时 search lexical fallback/context canceled 为预期测试退出日志。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；真实 HTTP 只用于确认去重和独立执行真相。
