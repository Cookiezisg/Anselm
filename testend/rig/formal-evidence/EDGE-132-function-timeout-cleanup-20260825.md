# EDGE-132 function 超时清洗

- 结论：`pass`（L1 function wall-clock timeout 的 HTTP、durable 与错误语义）；L2-L5 按当前台架边界记 `na`。
- 预期：无限循环 function 超过 `FunctionRunSec` 后，进程组被清理，HTTP 返回 `504 FUNCTION_RUN_TIMEOUT`；执行历史记录 `timeout`，错误说明 wall-clock 限制，不泄漏 sandbox 的 launch/spawn 误导。

## 证据

focused regression：

```text
cd backend && mise exec -- go test ./internal/app/function -run '^TestRunFunction_WallClockTimeout$' -count=1 -race -v
=== RUN   TestRunFunction_WallClockTimeout
--- PASS: TestRunFunction_WallClockTimeout (1.03s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/function 3.004s
```

真实 function HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestFunction_WallClockTimeout$' -count=1 -v
--- PASS: TestFunction_WallClockTimeout (5.19s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 5.783s
```

真实场景将 `functionRunSec` 设为 1，创建无限循环 function，`:run` 实际返回 `504`，错误码为 `FUNCTION_RUN_TIMEOUT`；随后读取 executions，唯一记录为 `timeout`，错误消息含 `wall-clock` 且不含 `spawn`。服务收台时 sandbox handles 为 0。

## 判定边界

L2-L5 暂记 `na`：真实 HTTP、durable execution 和收台证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
