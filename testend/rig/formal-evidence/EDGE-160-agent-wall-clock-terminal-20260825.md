# EDGE-160 agent 墙钟压过自报终态

- 结论：`pass`（L1 agent invocation wall-clock timeout）；L2-L5 按当前台架边界记 `na`。
- 预期：agent invocation 的总墙钟超过 `AgentInvokeSec` 时必须终止为 durable `timeout`，不能
  被 loop 自报的其它终态冒充成功；执行历史可查询，并且服务能正常收尾。

## focused service timeout and durable execution

```text
cd backend && mise exec -- go test ./internal/app/agent \
  -run '^TestService_InvokeWallClockTimeout_R20$' -count=1 -race -v
=== RUN   TestService_InvokeWallClockTimeout_R20
--- PASS: TestService_InvokeWallClockTimeout_R20 (1.03s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/agent 3.180s
```

focused 场景把 `AgentInvokeSec` 缩到 1 秒，让真实 invocation context deadline 切断阻塞流；
返回非 OK、状态为 timeout，并确认 execution durable row 同样为 timeout，可供 replay。

## real HTTP limits and invoke path

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestContractEntities_AgentInvokeWallClockTimeout$' -count=1 -v -timeout 600s
--- PASS: TestContractEntities_AgentInvokeWallClockTimeout (8.16s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 8.475s
```

真实产品路径通过 HTTP PATCH 把 `agentInvokeSec` 设为 2 秒，给 mock LLM 一个 6 秒 stall；
`POST /agents/{id}:invoke` 约 2 秒返回非 OK `timeout`，随后 executions 列表仍记录 timeout，
并在后端优雅 shutdown 时收台。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 service/HTTP timeout 与 durable execution 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
