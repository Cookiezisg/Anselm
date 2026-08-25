# EDGE-175 MCP 失败附 stderr 尾

- 结论：`pass`（L1 stderr evidence contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：stdio MCP 工具失败时，调用日志附 server stderr 的最新 8 KiB，并明确标注这是 server-level
  信息且可能早于本次调用，不能把历史 stderr 误报为本次精确时序。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestStderrTail_UsesByteCapAndKeepsNewestBytes$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.944s
```

回归使用超过 8 KiB 的 stderr 字节串，断言结果按字节封顶并保留最新尾部 marker。

## real HTTP blackbox

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ScriptedServerLifecycle$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.701s
```

真实 stdio server 的 `boom` 工具向 stderr 写入故意失败信息并返回 MCP `isError`；失败调用仍落
`mcp_calls`，详情 logs 同时包含 `server stderr tail (server-level, may predate this call)` 和
`boom tool exploding`。同一生命周期还核对了失败过滤/聚合、stderr endpoint、重连及删除后的 404。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use 错误日志逐帧时序测量
L4 na: 没有本格独立错误详情 UI 的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户发现并理解 server-level 历史 stderr 语义的 discoverability session
```
