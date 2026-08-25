# EDGE-155 agent 挂载目标被删

- 结论：`pass`（L1 agent dangling-mount fail-fast and mount-health semantics）；L2-L5 按当前
  台架边界记 `na`。
- 预期：agent 已挂载的 function/knowledge 被删除后，invoke 不能静默降级为成功或伪造空能力；
  工具目标应在执行时大声失败并可审计，knowledge 则在 mount-health 逐项显示 unhealthy。

## real HTTP agent path

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestAgentR2_RenameReresolutionAndFailFast$' -count=1 -v -timeout 600s
--- PASS: TestAgentR2_RenameReresolutionAndFailFast (6.62s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 7.025s
```

真实 agent 先成功挂载并 invoke function，随后 DELETE function；再次 invoke 落为 failed，错误
保留 `not found` 原因，未伪造成成功执行。该场景也覆盖改名后的现名重解析和 `ag_` 拒挂，证明
不是只测单一空指针分支。

## focused knowledge and create/edit guards

```text
cd backend && mise exec -- go test ./internal/app/agent \
  -run '^(TestMountHealth_CoversKnowledge|Test.*Knowledge|Test.*Mount)' -count=1 -race -v
=== RUN   TestCreateEdit_RejectsDanglingMounts
--- PASS: TestCreateEdit_RejectsDanglingMounts (0.02s)
=== RUN   TestMountHealth_CoversKnowledge
--- PASS: TestMountHealth_CoversKnowledge (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/agent 2.030s
```

focused 回归锁住 create/edit 对 dangling knowledge/tool 的拒绝，以及已有 agent 的 knowledge
被删除后 mount-health 保留该行并标 unhealthy，而不是 GetBatch 丢行造成静默成功。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实 agent HTTP 与 focused mount-health 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
