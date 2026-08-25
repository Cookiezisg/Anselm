# EDGE-169 MCP degraded 态

- 结论：`pass`（L1 health state and live status signal contract）；L2-L5 按当前台架边界记 `na`。
- 预期：同一 MCP server 连续三次工具失败后进入 `degraded`，仍可调用；entities 流发 ephemeral
  `status` signal 供 UI 变色；一次成功清零连续失败并恢复 `ready`。

## focused health + entities signal regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^(TestCallTool_RoutesToClient|TestCallTool_DegradesAndSignals)$' \
  -count=1 -race -v
=== RUN   TestCallTool_RoutesToClient
--- PASS: TestCallTool_RoutesToClient (0.00s)
=== RUN   TestCallTool_DegradesAndSignals
--- PASS: TestCallTool_DegradesAndSignals (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.781s
```

新增 focused bridge 断言保留实体 run open/close 事件，同时只筛选 `node.type=status`：阈值跨越发一条
ephemeral `ready→degraded`，恢复发一条 `degraded→ready`；REST 状态、连续失败计数和 payload 三者
一致，证明前端状态点不是只在数据库/HTTP 侧改变。

## real HTTP black-box lifecycle

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ScriptedServerLifecycle$' -count=1 -v -timeout 600s
--- PASS: TestMCP_ScriptedServerLifecycle (3.77s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.032s
```

真实二进制 HTTP 场景完成 stdio MCP PUT/connect、echo 成功、三次 boom 失败、GET 观察
`degraded`、degraded 状态下 echo 仍成功、GET 观察恢复 `ready`，并核对 mcp_calls failed/ok 聚合、
stderr tail、reconnect 和删除后的 404。测试 harness 启动时受控 free-tier 连接到关闭的回环端口，
日志中的 provision skipped 是 testend 设计的无配额隔离；收台时 search embedder context canceled 也
是正常 shutdown，不是 MCP 或 sidecar 残留。

## 判定边界

```text
L2 na: 本格有 focused bridge 与真实 HTTP，但没有独立真实 App 五通道 session
L3 na: 没有本格独立 Computer Use 观察状态点变色的逐帧时序测量
L4 na: 没有本格独立 degraded/ready UI 状态点的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户从 MCP 面板发现降级提示并恢复服务的 discoverability session
```
