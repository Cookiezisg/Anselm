---
id: DOC-024
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# subagent —— 递归子对话引擎（运行时机制，非实体）

## 1. 定位 + 心智模型

`Subagent`（Task）工具与 fork 模式 skill 调 `Spawn` 在聚焦任务上跑隔离子 agent、**同步**拿回最终答案。**subagent ≈ 递归 chat 但无自己的表**：回合作为 **sub-message 落父对话**（标 `SubagentID`、blocks 经 E3 嵌在派它的 tool_call 下；`attrParentBlockID` 供 reload 重建嵌套）。与 [agent 实体无关](agent.md)（agent 是持久化配置实体，subagent 是运行时机制）——两者只共享 loop 引擎。

**混血 host**：agentHost 的 prompt 历史 + 静态工具白名单，加 chatHost 的 Detached 落盘 + message_stop（被取消的 subagent 仍落终态防孤儿）。

**双层递归守卫**：① `Subagent` 工具名总从子集剔除（深度 1，子不能再派子）；② 内置类型硬编码（非用户实体）——`Explore`（只读侦察：Read/LS/Glob/Grep，30 轮）/ `Plan`（规划：+WebFetch/WebSearch，25 轮）/ `general-purpose`（父的全部工具减 Subagent，25 轮）。白名单按工具 `Name()` 动词匹配（与 agent 挂载的 ref 合成是**两套正确但不同**的机制——见 agent.md#3）。

模型 = workspace dialogue 模型（常见情形即父的 effective 模型；承袭显式 per-conversation override 刻意延后）。

## 2. 契约（引用）

无表、无端点、无码（纯运行时）。消费：messages（落 sub-message）/ loop / model resolver / 父工具集。被消费：chat 的 `Subagent` 工具、skill 的 fork 模式（`skilldomain.SubagentRunner` 端口）。
