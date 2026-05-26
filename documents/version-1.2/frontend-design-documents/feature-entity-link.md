# features/entity-link — 前端 slice 详细设计

**所属层**：features（对位后端 app/relation 的查询用例；聚合 7 类 entity list）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：提供两个跨实体聚合 hook：`useEntityDirectory`（全量 7 类 entity + 边聚合，用于关系图）和 `useEntityNeighborhood`（单实体邻居查询，用于 detail 侧边栏关系摘要）；两者均无 UI，纯数据聚合。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../service-design-documents/relation.md`](../service-design-documents/relation.md)
- 实体层 [`relation.md`](relation.md) / [`function.md`](function.md) / [`handler.md`](handler.md) / [`workflow.md`](workflow.md) / [`document.md`](document.md) / [`skill.md`](skill.md) / [`mcp.md`](mcp.md) / [`conversation.md`](conversation.md)

---

## 1. 职责边界

| Hook | 用例 |
|---|---|
| `useEntityDirectory` | 聚合全部 7 类 entity list query + useAllRelations → `{ nodes, edges }` 供关系图渲染 |
| `useEntityNeighborhood` | 单实体邻居查询 → 去重 + 限制数量 → `{ neighbours, guessedKind }` 供 detail 侧边栏 |
| `normEdges` | 纯函数：`Relation[]` → `EntityEdge[]`（过滤 malformed）|
| `guessKind` | 纯函数：从 id 前缀猜测 entity kind（闭合枚举）|

---

## 2. 类型

```ts
// useEntityDirectory 输出
export interface EntityNode {
  id: string;
  kind: string;    // "function"|"handler"|"workflow"|"document"|"skill"|"mcp"|"conversation"
  label: string;
  sub: string;
}

export interface EntityEdge {
  from: string;
  to: string;
  kind: string;
}

export interface EntityDirectory {
  nodes: EntityNode[];
  edges: EntityEdge[];
}

// useEntityNeighborhood 输出
export interface NeighborhoodResult {
  neighbours: string[];    // 邻居实体 id（去重，上限 limit）
  guessedKind: string;     // 传入 kind || guessKind(entityId)
}
```

---

## 3. useEntityDirectory（`model/useEntityDirectory.ts`）

### 聚合策略

```
useEntityDirectory():
  // 并发发起 8 个 query（7 entity lists + 1 relation list）
  fnQ  = useFunctions()
  hdQ  = useHandlers()
  wfQ  = useWorkflows()
  dcQ  = useDocuments()
  skQ  = useSkills()
  mcQ  = useMcpServers()
  cvQ  = useConversations()
  { data: rawRel } = useAllRelations()

  nodes = useMemo(
    concat 7 list queries → EntityNode[]
    每类映射规则：
      function:    { id: x.id,   label: x.name || x.id, sub: x.description }
      handler:     { id: x.id,   label: x.name || x.id, sub: x.description }
      workflow:    { id: x.id,   label: x.name || x.id, sub: x.description }
      document:    { id: x.id,   label: x.name || x.id, sub: t("relGraph.subDocument") }
      skill:       { id: x.name, label: x.name,          sub: x.description }
      mcp:         { id: x.name, label: x.name,          sub: t("relGraph.subTools", { count }) }
      conversation:{ id: x.id,   label: x.title || x.id, sub: "" }
    deps: 7 个 .data 引用
  )

  edges = useMemo(
    normEdges(rawRel)
    deps: rawRel
  )

  return { nodes, edges }
```

注意：skill 和 mcp 以 `name` 作 id（无数字 id，与后端 S15 一致）。

### normEdges（纯函数）

```ts
normEdges(relations: Relation[]): EntityEdge[]
  // 过滤 malformed（无 fromId 或 toId 的行）
  relations
    .map(r => ({ from: r.fromId, to: r.toId, kind: r.kind }))
    .filter(e => e.from && e.to)
```

---

## 4. useEntityNeighborhood（`model/useEntityNeighborhood.ts`）

### guessKind — id 前缀映射

```ts
guessKind(id): string
  prefix = id.split("_")[0]
  {
    f/fn: "function",   h/hd: "handler",
    w/wf: "workflow",   cv: "conversation",
    d/doc: "document",  s/sk: "skill",
    mcp: "mcp",         m/mem: "memory",
    fr: "flowrun",
  }[prefix] || "function"   ← 默认 function
```

覆盖后端 S15 前缀白名单；未知前缀 fallback "function"（最常见类型）。

### 编排步骤

```
useEntityNeighborhood(entityId, kind?, limit=3):
  guessedKind = kind || guessKind(entityId)

  { data: rels } = useNeighborhood({ kind: guessedKind, id: entityId, depth: 1 })
    → GET /relations/neighborhood?kind=...&id=...&depth=1

  neighbours = []
  seen = Set([entityId])
  for r of rels:
    otherId = r.fromId === entityId ? r.toId : r.fromId
    if !otherId || seen.has(otherId): continue
    seen.add(otherId)
    neighbours.push(otherId)
    if neighbours.length >= limit: break

  return { neighbours, guessedKind }
```

去重逻辑：`seen` Set 包含自身 id，保证邻居中不出现自身；多条同向边去重。

### 意图 API

```ts
const { neighbours, guessedKind } = useEntityNeighborhood(entityId, kind, limit);
// neighbours: string[] (id list, len ≤ limit)
// guessedKind: string (传入 kind 或推断值，供调用方渲染 kind 标签)
```

---

## 5. 端到端数据流

### 关系图（useEntityDirectory）

```
RelGraph 组件挂载
  → useEntityDirectory()
      → 并发 8 个 TanStack Query
          GET /functions?limit=200
          GET /handlers?limit=200
          GET /workflows?limit=200
          GET /documents?limit=200
          GET /skills
          GET /mcp-servers
          GET /conversations?limit=100
          GET /relations?limit=500
      → useMemo 合并为 { nodes, edges }
  → 力导向图渲染
```

### 实体详情侧边栏（useEntityNeighborhood）

```
FunctionDetail / HandlerDetail / WorkflowDetail 侧边栏
  → useEntityNeighborhood(entityId, "function")
      → GET /relations/neighborhood?kind=function&id={id}&depth=1
      → 取对端 id，去重，取前 3
  → 渲染邻居 chip 列表（id → label 由调用方再查 entity）
```

---

## 6. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| query 并发 | 8 个 useXxx() 并发发起；TanStack Query 自动去重 + 缓存 |
| malformed 边过滤 | `normEdges` filter `e.from && e.to`；不抛错 |
| limit 截断 | 邻居超过 limit 时截断，detail 侧边栏不显示全量 |
| skill/mcp id 特殊性 | 以 name 作 id；guessKind 对 skill/mcp 前缀的覆盖有限（name 无前缀下划线时 fallback）|

---

## 7. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/entity-link/model/useEntityDirectory.ts` | 7 entity + relation 聚合；normEdges 纯函数 |
| `frontend/src/features/entity-link/model/useEntityNeighborhood.ts` | 邻居查询；guessKind 纯函数 |
| `frontend/src/features/entity-link/index.ts` | public API（两 hook + 两纯函数 + 类型）|
