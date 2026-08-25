# EDGE-173 MCP name-or-id 双键 purge

- 结论：`pass`（L1 service + real HTTP relation purge）；L2-L5 按当前独立台架边界记 `na`。
- 预期：以 `mcp:<name>/tool` 挂载 MCP 后删除 server，关系边无论按 server name 还是 `mcp_` ID 存储都被清理；删除后的 server 不可读，agent 邻域不留下 MCP 孤儿节点。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestRemove_PurgesRelationsByIdAndName$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.634s
```

该测试安装真实 registry 形态的 Context7 server，注入 relation syncer，断言 `RemoveServer` 同时调用
`PurgeEntity` 的 `mcp_...` ID 和 `context7` 名称键。

## real HTTP blackbox

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestRippleR5_RelationGraphFaces$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.195s
```

真实场景先创建 stdio MCP、挂载到 agent 并观察关系邻域包含 `relmcp`，随后通过
`DELETE /api/v1/mcp-servers/relmcp` 删除；HTTP 读取返回 `MCP_SERVER_NOT_FOUND`，最终 agent 邻域
不再包含 `relmcp`。服务日志同时记录 `relation purge ... kind=mcp id=relmcp removed=1`。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use 逐帧时序测量
L4 na: 关系邻域无视觉 craft 断言，不能冒充视觉成品验收
L5 na: 没有本格独立的新用户发现/理解 MCP 删除后关系状态的 discoverability session
```
