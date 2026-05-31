---
id: DOC-237
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/relation — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/relation / relgraph）
**状态**：✅ 已实现
**职责**：只读查询 relation 图谱（有向边 + 邻域）。前端不创建/删除边（由后端 domain 级联写入）。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/relation.md`

---

## 1. 职责边界

- 全量关系列表（按 fromKind / toKind / kind 过滤）
- 实体邻域查询（给定 kind+id，返回 depth 跳以内的节点 + 边）
- 单实体关系列表（关系面板小组件用）

前端不写边——边的创建/删除由后端各 domain service 级联触发（forge / workflow / document）。

---

## 2. 类型（`model/types.ts`）

```ts
type EntityKind = "conversation" | "function" | "handler" | "workflow" | "document" | "skill" | "mcp";
type RelationKind =
  | "conversation_forged_entity"
  | "conversation_edited_entity"
  | "workflow_uses_function"
  | "workflow_uses_handler"
  | "workflow_uses_mcp"
  | "workflow_uses_skill"
  | "workflow_uses_document"
  | "document_links_entity";

interface Relation {
  id: string;     // rel_<16hex>
  userId; fromKind; fromId; toKind; toId;
  kind: RelationKind;
  attrs?: Record<string,unknown>;
  createdAt; updatedAt;
}

interface GraphNode { kind; id; label; sub? }
interface Neighborhood { nodes: GraphNode[]; edges: Relation[] }
interface RelationFilter { fromKind?; toKind?; kind? }
interface NeighborhoodVars { kind; id; depth?: number }
```

`Neighborhood.nodes` 包含每个节点的 label / sub（由后端 relgraph `GetMetaBatch` 计算）。

---

## 3. API hooks（`api/relation.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useAllRelations()` | GET `/relations?limit=1000` | 全量关系（RelGraph 页面用） |
| `useRelationFilter(filter)` | GET `/relations?{fromKind/toKind/kind}` | 按维度过滤 |
| `useNeighborhood({kind,id,depth})` | GET `/relations/neighborhood?kind=&id=&depth=` | 邻域图（RelGraph 展开节点用） |
| `useRelations(entityId, limit)` | GET `/relations?entityId=&limit=` | 单实体关系面板 |

---

## 4. 端到端数据流

### 4.1 关系图谱渲染

```
widgets/RelGraph → useAllRelations()
  → GET /relations?limit=1000
  → Relation[] → 按 fromKind/toKind 分组构建图节点
  → 渲染 D3 / force-directed 图

用户点击节点展开邻域
  → useNeighborhood({kind, id, depth:2})
      → GET /relations/neighborhood?...
      → {nodes: GraphNode[], edges: Relation[]}
      → 增量叠加到图中
```

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/relation/model/types.ts` | Relation / GraphNode / Neighborhood / Filter* 类型 |
| `frontend/src/entities/relation/api/relation.ts` | 4 个只读 hooks |
| `frontend/src/entities/relation/index.ts` | public API |
