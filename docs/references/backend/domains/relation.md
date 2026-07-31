---
id: DOC-029
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Relation

## 1. 定位

Relation 是 workspace 内跨实体的当前拓扑投影。节点 kind 为：

```text
function | handler | workflow | agent | document | conversation
| skill | mcp | trigger | control | approval
```

有向边只使用四个动词：

```text
create | edit | equip | link
```

端点类型由 `fromKind/toKind` 承担，因此新增端点组合不需要扩展 edge kind。Relation
展示结构终态，不是操作历史；对话经历由 [`touchpoint.md`](touchpoint.md) 承担。

## 2. 写侧：声明终态

业务域不增量维护边，而是在 Create/Edit/Revert/Activate 后声明一个 scope 的完整目标：

- `SyncOutgoing`：替换某实体指定 kind scope 的全部出边，常用于 equip/link；
- `SyncIncoming`：替换某实体指定 scope 的全部入边，常用于 conversation create/edit
  provenance；
- `PurgeEntity`：实体删除时硬删所有触及它的边。

Sync 以 diff 方式增删并更新 attrs，重复声明同一终态幂等。Conversation fork 使用
conversation → conversation 的 create 入边表达血缘。

Document wikilink、Agent/Workflow tools/knowledge、Trigger 引用以及版本 provenance 都在
各自业务域落定后调用 Relation adapter。Relation adapter 缺席时主业务仍可工作，但
Bootstrap 的完整装配会注入它。

## 3. 读侧与名称

边只持 ID，不复制显示名。读取 List、Neighborhood 或 relgraph 时，通过每个实体域注册的
Namer 批量 hydrate 当前名称；目标已删时退回原始 ID。孤立实体不出现在 relgraph，因为
这里是关系图，不是实体 inventory。

读面包括：

- keyset-paginated edge list；
- 深度 1–3 的 BFS neighborhood；
- workspace 全量 nodes + edges snapshot；
- LLM `get_relations` 工具。

Filter 的 kind/id 必须成对提供；self-loop、未知 entity kind、未知 edge kind 和超界
depth 在 domain 边界拒绝。

## 4. 删除影响

`CountDependents/ListDependents` 只统计指向目标的 equip/link 边，不把 create/edit
provenance 或目标自己的出边误算为依赖。删除工具必须在 Purge 前读取这份影响面，并把
依赖方引用附在结果中。

`PurgeEntity` 同样在抹边前快照 dependents。删除确有引用者时，best-effort 发一条聚合的
`relation.dependency_broken` 持久通知，包含被删目标和去重后的依赖方。通知失败不能反过来
阻止业务删除。

## 5. 契约

Relation 读端点见 [`api.md`](../api.md)，`relations` 表见
[`database.md`](../database.md)，错误见 [`error-codes.md`](../error-codes.md)，
依赖断裂事件见 [`events.md`](../events.md)。

Relation 行是可重建的派生拓扑，实体自身才是 durable truth；因此边随实体删除物理清除，
不引入新的 durable 业务删除例外。
