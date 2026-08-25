# EDGE-154 agent 挂载撞名

- 结论：`pass`（L1 agent mount resolution/collision semantics）；L2-L5 按当前台架边界记 `na`。
- 预期：两个挂载合成相同 LLM tool name 时不能静默覆盖或 last-write-wins；create/invoke 必须
  大声拒绝并说明 collision，mount-health 则逐项报告冲突而不把整个其它挂载误报为 unhealthy。

## real agent invoke and mount-health paths

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^(TestAgentR2_RenameReresolutionAndFailFast|TestContractEntities_AgentMountHealthMatrix)$' \
  -count=1 -v -timeout 600s
--- PASS: TestContractEntities_AgentMountHealthMatrix (5.86s)
--- PASS: TestAgentR2_RenameReresolutionAndFailFast (6.62s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 7.025s
```

真实 agent 场景创建 function `greeter__hello` 与 handler `greeter.hello`，两者合成同名工具；
系统按就绪竞态在 create 或 invoke 面返回 `AGENT_MOUNT_INVALID`/collision，绝不静默覆盖。
独立 mount-health 场景先证明两个正常工具和 knowledge mount，再删除 knowledge 验证逐挂载
非 fail-fast，最后把 function 改名制造冲突，报告第一挂载健康、第二挂载 unhealthy 且错误含
`collides`。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实 agent HTTP/invoke/mount-health 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
