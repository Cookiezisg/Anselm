# EDGE-152 uvx/npx 孙进程整组杀

- 结论：`pass`（L1 sandbox/MCP lifecycle and process-group reclaim）；L2-L5 按当前台架边界记
  `na`。
- 预期：MCP 由 `npx`/`uvx` wrapper 启动时，删除 server 必须停止其 resident 进程；boot
  survivor 清理不能只杀 wrapper，而要对其同组的真实 node/python 子进程发负 pgid SIGKILL。

## real product path: npx MCP install, invoke, delete

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_OfficialFilesystemServer$' -count=1 -v -timeout 600s
--- PASS: TestMCP_OfficialFilesystemServer (4.87s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.447s
```

这条真实 testend 旅程从全新 sandbox 通过 `npx -y @modelcontextprotocol/server-filesystem`
启动官方 filesystem server，真实发现工具并读取临时文件；随后经产品 HTTP DELETE 删除
`fs`，验证 server 404 且原工具调用返回 `MCP_SERVER_NOT_FOUND`，不是只等 harness shutdown
代替用户动作。运行日志同时记录了实际 npx server 的 stdio banner 和 DELETE 204。

## real process-group regression

```text
cd backend && mise exec -- go test ./internal/app/sandbox \
  -run '^TestRestoreOnBoot_Kills(SurvivorAndClearsManifest|GrandchildViaProcessGroup)$' \
  -count=1 -race -v
=== RUN   TestRestoreOnBoot_KillsGrandchildViaProcessGroup
--- PASS: TestRestoreOnBoot_KillsGrandchildViaProcessGroup (0.03s)
=== RUN   TestRestoreOnBoot_KillsSurvivorAndClearsManifest
--- PASS: TestRestoreOnBoot_KillsSurvivorAndClearsManifest (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/sandbox 1.743s
```

focused 回归把记录 PID 的 wrapper 放进独立进程组，再 fork 同组 `sleep` 孙进程；boot reaper
后孙进程消失，manifest 的 `running_pid` 也被清零，证明负 pgid 收割而非单 PID kill。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: MCP/进程 focused 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
