# EDGE-170 MCP 连接失败仍落盘

- 结论：`pass`（L1 persist-and-reconnect contract）；L2-L5 按当前台架边界记 `na`。
- 预期：PUT 一个连不上的 stdio/remote server 仍落盘 `status=failed` + `lastError`；`:reconnect`
  可以再次尝试；失败 server 不进入 callable 工具面，而是明确返回 `MCP_SERVER_DOWN`。

## focused reconnect and notification regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^(TestReconnect_NotifiesOutcome|TestReconnect_RefreshesStatus)$' \
  -count=1 -race -v
=== RUN   TestReconnect_RefreshesStatus
--- PASS: TestReconnect_RefreshesStatus (0.00s)
=== RUN   TestReconnect_NotifiesOutcome
--- PASS: TestReconnect_NotifiesOutcome (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.931s
```

focused service test确认成功重连回 `ready`，失败重连仍发带 `status=failed` 与 `lastError` 的通知；
连接失败不被包装成“已恢复”的假成功。

## real HTTP error paths

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ErrorPaths$' -count=1 -v -timeout 600s
--- PASS: TestMCP_ErrorPaths (4.04s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.461s
```

真实二进制 HTTP 场景覆盖：坏 stdio PUT 返回并保留 `failed`/`lastError`；对其执行 `:reconnect`
仍是失败但可重试；对 failed server 调工具返回 `503 MCP_SERVER_DOWN`；不可达 remote PUT 同样
持久化为 failed；未知动作仍是 404。日志里的 free-tier 回环拒绝和 shutdown embedder cancel
属于 testend 隔离/收台预期，不是 MCP 失败落盘的误报。

## 判定边界

```text
L2 na: 本格有 focused service 与真实 HTTP，但没有独立真实 App 五通道 session
L3 na: 没有本格独立 Computer Use 失败安装/重连的逐帧时序测量
L4 na: 没有本格独立失败卡片与重连提示的视觉成品及 craft 比对
L5 na: 没有本格独立的新用户发现失败 server、理解原因并触发 reconnect 的 discoverability session
```
