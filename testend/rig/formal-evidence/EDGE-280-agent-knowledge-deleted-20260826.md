# EDGE-280 · agent 知识文档被删

## L1 focused evidence

- `backend/internal/app/agent/crud_skill_test.go:TestMountHealth_CoversKnowledge` 通过：创建后删除 knowledge doc，mount-health 逐条标 unhealthy。
- `testend/scenarios/agent_test.go:TestAgentR2_RenameReresolutionAndFailFast` 通过 Agent 挂载目标失效后的 fail-fast 线缆行为。

## 判定

L1=`E4`：Agent knowledge 缺失不会静默失去 grounding，预检与 invoke 使用同一具体错误语义。L2-L5 本批未启动真实 App，记 `na`。
