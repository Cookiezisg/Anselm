# EDGE-156 agent 离线 MCP 挂载归因

- 结论：`pass`（L1 agent MCP mount attribution/recovery）；L2-L5 按当前台架边界记 `na`。
- 预期：已挂载的 MCP server 断线时，mount-health 和 invoke 都必须报 `MCP_SERVER_DOWN` / 
  `not connected`，不能误导成 `MCP_TOOL_NOT_FOUND`；恢复 server 后挂载重新健康且工具可调用。

## real agent seat, offline, reconnect, invoke

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestP4bMcp_OfflineServerAgentSeatAndRecovery$' -count=1 -v -timeout 600s
--- PASS: TestP4bMcp_OfflineServerAgentSeatAndRecovery (3.74s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.185s
```

真实 agent 先挂载并确认 ready 的 stdio MCP server，再 PUT 替换为不存在的 Python 脚本制造
断线。`mount-health` 显示 not connected，agent invoke 在 LLM 调用前 fail-fast，错误不是
tool-not-found；PUT 换回活命令后 mount-health 恢复健康，`mcp__recover__echo` 真正执行并在
MCP calls 台账记为 `triggeredBy=agent`。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实 agent/MCP HTTP 与 LLM mock seat 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
