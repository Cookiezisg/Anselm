# EDGE-164 被取消的 subagent 落终态

- 结论：`pass`（L1 cancellation/finalization invariant）；L2-L5 按当前台架边界记 `na`。
- 预期：父对话取消正在运行的 subagent 后，父回合和 sub-message 都必须落 durable terminal，
  sub-message 通过 detached finalize 发出 `message_stop`，不能留下 streaming/pending 孤儿。

## focused terminal annotation

```text
cd backend && mise exec -- go test ./internal/app/subagent \
  -run '^TestAnnotateTerminal$' -count=1 -race -v
=== RUN   TestAnnotateTerminal
--- PASS: TestAnnotateTerminal (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/subagent 2.060s
```

focused 回归锁住 completed 原样透传、cancelled/error/max-steps 终态前缀，以及无文本 error 仍浮出
原因；不会把部分答案当成干净成功。

## real HTTP cancellation and detached finalize

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestContractChat_SubagentCancelTerminal$' -count=1 -v -timeout 600s
--- PASS: TestContractChat_SubagentCancelTerminal (32.22s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 32.736s
```

真实 HTTP 场景让子 provider 故意 stall 30 秒，父端调用 `POST /conversations/{id}:cancel`；父消息与
sub-message 都在轮询窗口内成为终态，且没有 pending/streaming 残留。日志中的
`httptest.Server blocked in Close after 5 seconds` 是故意不合作的 30 秒 mock provider 在测试替身
收台时留下的尾巴，不是 Anselm sidecar listener；它被原样保留在测试输出，不作为静默成功依据。

## 判定边界

```text
L2 na: 当前为真实HTTP取消/持久化终态证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧、取消反馈时序或视觉测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 取消是 chat 控件行为，本格没有独立 discoverability session
```
