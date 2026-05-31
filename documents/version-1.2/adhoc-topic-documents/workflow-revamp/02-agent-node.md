# 02 — Agent 节点

脑爆结论笔记(2026-05-27)。
2026-05-31 改向 durable execution(详 [`00-overview.md`](./00-overview.md))。

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

**在执行模型里,agent 节点 = 一串子-activity(不是一条原子 activity)**:它内部是多步 LLM ReAct 循环,**每一步(每次 LLM turn、每个 tool-call)各自记一笔账进事件日志**——而这正好就是 eventlog 已经在记的 `reasoning` / `tool_call` / `tool_result` block。所以"agent 跑一次" = 一串子-activity 依次记账。**重放粒度因此是子步级**:崩在第 5 个 tool-call,重放把日志里已记账的前 4 个 tool-call 结果**直接抄**(不重调 LLM、不重跑那 4 个工具),停在第 5 个(第一个没记账的子步)真跑、记账、接着往下。这样 [`07-error-handling.md`](./07-error-handling.md) 的"零重复"按子步成立——**不会因为 agent 中途崩就把整个循环连同已发生的工具副作用重放一遍**。这一子-activity 记账语义、确定性约束、exactly-once 边界统一由 [`00-overview.md`](./00-overview.md) 的执行底盘负责,本节不重述。

跑时:

1. 执行器照图走到本节点,**读其前驱节点的输出**(程序数据流,该输出已记进事件日志)
2. 平台按 agentRef 查 agent active version 的所有配置(prompt / skill / knowledge / tools / model / outputSchema)
3. 用前驱输出作为 prompt 模板插值数据
4. 跑 LLM ReAct loop(像 chat 主 agent 一样)
5. **产出结果**(按 outputSchema 约束),**记进事件日志**,**传给下游节点**(下游沿图的出边读到本节点的输出)

> 注:agent.prompt 是 `{{ CEL }}` 模板字符串(`{{ }}` 内为 CEL,求值后字符串化插入),详 [`04-case-node.md`](./04-case-node.md) 表达式语言段。

---

## 跟 tool 节点的关系

tool 节点也能调 agent(callable ref `ag_xxx`,详 [`03-tool-node.md`](./03-tool-node.md))。

agent 节点 vs tool 节点(都调 agent)的差异:

| | agent 节点 | tool 节点(调 agent) |
|---|---|---|
| UX | 在画布上明确标识"这一步是 LLM" | 跟其他 callable 视觉一致 |
| Inspector | 显示 agent 的 prompt / skill / tools 等(只读 + 跳 ag entity 编辑) | 显示 callable + args |
| 适合 | 主要的"思考 / 决策"步骤,产品上凸显 | 当 agent 只是"调一下"被消费的步骤 |
| 实际机制 | 完全一样(都是一个 activity、调同一个 agent entity) | 同左 |

**基本是 syntax sugar** — 同一个 activity、调同一个 agent entity,选哪个主要影响编辑 UX。**唯一行为差(D4)**:`retry` / `timeout` 两个旋钮在 **tool 节点**上暴露;agent 节点取默认(不重试 / 无超时,保持极简)。要给 agent 调用自定义 retry/timeout,就用 tool 节点调它(`ag_xxx`)。

---

## chat agent vs workflow agent 的产品对照

| | chat agent | workflow agent entity |
|---|---|---|
| 角色 | **老板** | **员工** |
| 任务来源 | 用户对话 / 探索 | 程序走到这一步喂给它的输入 / 试跑接口 |
| skill | 自己 search + activate | entity 上配死(预激活) |
| tools | 自己挑 + 临场 forge | entity 上配死 |
| subagent | 可 spawn | 不能 |
| 改流程 | 自由探索 | 不能 |
| 是 forge 实体? | ❌ 主对话直接跑 | ✅ entity 化(详 09) |

Forgify narrative:**chat 是探索 / 设计 / 锻造的地方;workflow 是沉淀 / 自动化 / 规模化的地方**。锻造完的 agent → 沉淀成 entity → 被 workflow 节点引用,员工无人值守干活。

---

## 跨页一致性

跟 01 polling-function-as-trigger / 03 tool 节点 callable 模型 / 09 agent domain 同源:**整个 workflow 体系里,所有外部世界的能力接入都从 forge 流出**(function / handler / agent),无平台黑盒 escape hatch。
