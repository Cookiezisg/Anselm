# EDGE-140 handler ctx 取消 = 管道脏

- 结论：`pass`（L1 handler RPC cancellation 的 crashed/respawn 语义）；L2-L5 按当前台架边界记 `na`。
- 预期：一次 RPC 等待被 context cancel 后，stdio client 不能继续复用状态未知的管道，必须标记 crashed；manager 下次 Get/Call 回收该实例并重生一个新的 resident。这是协议正确性，不是普通业务失败。

## 证据

真实 stdio client pipe regression：

```text
cd backend && mise exec -- go test ./internal/infra/handler -run '^TestClient_CancelledRPCMarksPipeCrashed$' -count=1 -race -v
=== RUN   TestClient_CancelledRPCMarksPipeCrashed
--- PASS: TestClient_CancelledRPCMarksPipeCrashed (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/infra/handler 1.526s
```

测试使用真实 `stdioClient` 和 `io.Pipe` stdout，取消已开始等待的 `Init`；断言返回 `context.Canceled` 后 `Crashed()` 为 true，再次 Init 立即返回 `ErrCrashed`，证明脏管道不会被复用。

app manager respawn regression：

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestCrash_RespawnsOnNextCall$' -count=1 -race -v
=== RUN   TestCrash_RespawnsOnNextCall
--- PASS: TestCrash_RespawnsOnNextCall (0.10s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/handler 2.073s
```

该回归先让 resident client 报 crashed，再发下一次 `Call`；manager 重新建立 resident，spawn 计数从 1 到 2，旧 handle 被回收，证明 crashed 标记确实连接到了下一次自动重生。

## 判定边界

该项需要客户端在 RPC 中途断连，当前 testend 没有可控的真实 HTTP handler 断连台架；不伪造 HTTP 证据。L2-L5 暂记 `na`：stdio/client 与 app respawn focused 证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
