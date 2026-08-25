# EDGE-174 MCP 进度关联

- 结论：`pass`（L1 per-call token correlation）；L2-L5 按当前独立台架边界记 `na`。
- 预期：同一 MCP session 并发执行两个会发 progress 的工具时，session 级 handler 必须按每次调用的
  progress token 把进度送回正确 sink；durable 调用日志不能互相串台。

## focused regression

```text
cd backend && mise exec -- go test ./internal/infra/mcp \
  -run '^(TestOnProgress_RoutesByToken|TestOnProgress_RoutesConcurrentCallsByToken)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/mcp 1.542s
```

新增并发回归交错两个 token 的通知，断言 call-a 只收到 alpha、call-b 只收到 beta，未知 token 被丢弃。

## real HTTP blackbox

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ConcurrentProgressCorrelation$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.696s
```

真实 stdio MCP server 同时接收 alpha/beta 两次 `tools/echo` 调用，并故意延迟结果制造交错窗口；
两个 HTTP 调用均 200 且返回正确文本。随后读取两条真实 `mcp_calls` 详情，每条分别只含自己的
`echo alpha halfway` 或 `echo beta halfway`，没有另一调用的 progress 文本。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use 并发进度逐帧时序测量
L4 na: 没有本格独立 progress UI 两条并发轨迹的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户发现并发进度归属语义的 discoverability session
```
