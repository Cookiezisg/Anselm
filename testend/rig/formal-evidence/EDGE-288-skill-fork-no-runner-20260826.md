# EDGE-288 · fork skill 无 runner

## L1 focused evidence

- `backend/internal/app/skill/skill_test.go:TestActivate_Fork_NoRunner_Degrades` 通过：没有 subagent runner 时返回 ErrSubagentUnavailable。
- `TestCreate_ForkRequiresAgent` 与 `TestCreate_ForkRejectsUnknownAgentType` 通过：创建阶段拒绝缺失或未知 agent 配置。
- 有 runner 的 `TestActivate_Fork_WithRunner` 同时通过，证明降级不是把 fork 静默当 inline。

## 判定

L1=`E4`：fork 能力缺失时诚实降级，并保留可修复的配置原因。L2-L5 本批未启动真实 App，记 `na`。
