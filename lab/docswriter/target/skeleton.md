# canonical module 文档骨架

> 每篇 `docs/references/backend/<...>.md`（module 文档）都按本骨架。结构可预测 = 反 kitchen-sink。
> frontmatter 必填（`type: reference`，`make docs` 校验）。

## frontmatter

```yaml
---
id: DOC-NNN
type: reference
status: active
owner: @weilin
created: YYYY-MM-DD
reviewed: YYYY-MM-DD
review-due: YYYY-MM-DD
audience: [human, ai]
---
```

## A. 实体域 / 服务模块（7 节）

> function/handler/agent/workflow/trigger/control/approval/skill/mcp/document/conversation/chat/messages/attachment/memory/todo/subagent/catalog/relation/mention/model/apikey/websearch/notification/workspace/sandbox/scheduler/flowrun/aispawn/humanloop/contextmgr/envfix/entitystream

| 节 | 写什么 | 不写什么 |
|---|---|---|
| **1. 定位** | 一段：是什么 + 唯一职责 + 在 Quadrinity/分层里的位置 | — |
| **2. 心智模型** | 让后面都通的核心概念（如 flowrun=节点结果记忆化）。**这是文档的灵魂** | — |
| **3. 物理模型** | 拥有哪些表、列的**设计取舍**（为什么这些列、这个 UNIQUE）；ID 前缀 | schema 全文（引 `database.md`）|
| **4. 生命周期 / 行为** | 状态机、版本模型、关键流程、并发/幂等 | 逐方法复述 |
| **5. 关键设计决策** | 取舍 = Why-not-What 主体（为什么这样、为什么不那样、边界、坑） | 历史演化 |
| **6. 契约** | 拥有的端点/码/事件/工具——**引用** `api.md`/`error-codes.md`/`events.md` 的对应段 | **重列**端点/码/事件 |
| **7. 跨域集成** | relation 边（产出/入向）、依赖谁的端口、谁依赖它 | — |

## B. 地基 / 引擎 / infra / 工具 模块（套用 A，按需取节）

> orm/cel/reqctx/agentstate/idgen-等 pkg · loop（ReAct 引擎）· tool+toolset · llm · db · stream（SSE bus）· crypto · sandbox(infra) · handler(infra RPC) · trigger(infra listeners) · fs(blob) · transport · 工具组(filesystem/search/shell/web/ask)

非实体模块**无表/无端点**时跳 §3/§6 的枚举部分，保留：
| 节 | 写什么 |
|---|---|
| **1. 定位** | 这个地基/机制是什么、解决什么 |
| **2. 心智模型** | 核心抽象（如 orm=链式+自动 workspace 隔离；loop=共享 ReAct，chat/agent/wf 都是调用方） |
| **3. 机制 / 设计** | 怎么实现的关键点 + 取舍（自研 orm 去 GORM 的理由；tool 5 方法 + 三字段注入） |
| **4. API 面** | 它对消费方暴露的接口/端口（不逐方法，列关键面 + 怎么用） |
| **5. 关键决策 / 边界** | 取舍、坑、非目标 |
| **6. 集成** | 谁消费它、它消费谁 |

## 通则

- **只写 Why、不写 What**；高密度、表格 > 列表 > 段落；中文。
- **零历史**：无 R 轮次、无演化。
- **单源**：枚举引索引、绝不重列。
- 行数参考：实体域 ~120–200 行；地基模块 ~60–120 行。超长 = 多半在 What 灌水或重复枚举，砍。
