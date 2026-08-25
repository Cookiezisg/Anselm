# EDGE-147 handler 同实例并发调用串扰

- 结论：`pass`（L1 Handler resident stderr-window 语义）；L2-L5 按当前台架边界记 `na`。
- 预期：同一 resident 的 stdio 管道按 mutex 串行执行，但上层并发调用的 stderr sink 窗口
  可能重叠。产品不能假装存在严格 per-call 归属；它必须保证每条调用自己的 stderr start/end
  不丢，并用 30ms grace 接住 return 后仍在管道中的迟到行。

## focused fan regression

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestStderrFan_(WindowAttribution|ConcurrentCalls)$' -count=1 -race -v
=== RUN   TestStderrFan_WindowAttribution
--- PASS: TestStderrFan_WindowAttribution (0.00s)
=== RUN   TestStderrFan_ConcurrentCalls
--- PASS: TestStderrFan_ConcurrentCalls (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler 1.733s
```

focused 回归同时覆盖窗口外丢弃、detach 幂等、并发 attach/write/detach，以及两个 sink 对同一
实例 stderr 行的扇出完整性。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestHandler_ConcurrentCallStderrWindows$' -count=1 -v
--- PASS: TestHandler_ConcurrentCallStderrWindows (6.34s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 6.893s
```

真实场景并发发出带 `alpha`/`beta` 参数的两个 `:call`，method 各自打印 `start-*`、等待并打印
`end-*`。两个调用都成功，调用台账的 `instanceId` 相同，详情 logs 各自包含自己 tag 的 start
与 end。运行日志可见两个窗口确实重叠：RPC method 仍逐个执行，但 stderr 的窗口归属不被伪装
成严格隔离；该行为与代码契约一致，且尾行在 grace 窗内被保留。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused fan + 真实 HTTP/同 instance/call logs 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
