# 02 — Agent 节点

脑爆结论笔记(2026-05-27)。

---

## Agent 是 first-class forge 实体

**Agent 已升级为独立 forge domain**(跟 function / handler 平级)。详 [`09-agent-domain.md`](./09-agent-domain.md)。

workflow 里的 agent 节点变成 **thin wrapper** — 只引用 agent entity,不直接配挂载。所有 prompt / skill / knowledge / tools / model 都在 agent entity 上配。

---

## 节点形态

```yaml
type: agent
config:
  agentRef: ag_xxx      # 必填 — 引用 agent entity(永远 active version,无 pin;见 00 总纲 3「永远 prod」)
```

节点 config 就这一个字段。极简。

跑时:

1. 节点 consume 上游消息
2. 平台按 agentRef 查 agent active version 的所有配置(prompt / skill / knowledge / tools / model / outputSchema)
3. 用消息 payload 作为 prompt 模板插值数据
4. 跑 LLM ReAct loop(像 chat 主 agent 一样)
5. emit 一条新消息进下游 queue,payload = LLM 输出(按 outputSchema 约束)

---

## 跟 tool 节点的关系

tool 节点也能调 agent(callable ref `ag_xxx`,详 [`03-tool-node.md`](./03-tool-node.md))。

agent 节点 vs tool 节点(都调 agent)的差异:

| | agent 节点 | tool 节点(调 agent) |
|---|---|---|
| UX | 在画布上明确标识"这一步是 LLM" | 跟其他 callable 视觉一致 |
| Inspector | 显示 agent 的 prompt / skill / tools 等(只读 + 跳 ag entity 编辑) | 显示 callable + args |
| 适合 | 主要的"思考 / 决策"步骤,产品上凸显 | 当 agent 只是"调一下"被消费的步骤 |
| 实际机制 | 完全一样(都调同一个 agent entity) | 同左 |

**实际是 syntax sugar 区别** — 选哪个不影响行为,只影响编辑 UX。

---

## chat agent vs workflow agent 的产品对照

| | chat agent | workflow agent entity |
|---|---|---|
| 角色 | **老板** | **员工** |
| 任务来源 | 用户对话 / 探索 | workflow 节点喂的消息 / 试跑接口 |
| skill | 自己 search + activate | entity 上配死(预激活) |
| tools | 自己挑 + 临场 forge | entity 上配死 |
| subagent | 可 spawn | 不能 |
| 改流程 | 自由探索 | 不能 |
| 是 forge 实体? | ❌ 主对话直接跑 | ✅ entity 化(详 09) |

Forgify narrative:**chat 是探索 / 设计 / 锻造的地方;workflow 是沉淀 / 自动化 / 规模化的地方**。锻造完的 agent → 沉淀成 entity → 被 workflow 节点引用,员工无人值守干活。

---

## 跨页一致性

跟 01 polling-function-as-trigger / 03 tool 节点 callable 模型 / 09 agent domain 同源:**整个 workflow 体系里,所有外部世界的能力接入都从 forge 流出**(function / handler / agent),无平台黑盒 escape hatch。
