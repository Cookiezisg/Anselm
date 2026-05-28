# features/workflow-edit — 前端 slice 详细设计

**所属层**：features（对位后端 app/workflow 的 `:edit` action）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装 WorkflowEditor 画布的 diff-based 防抖自动保存逻辑；`diffToOps` 三向 diff 算法和 2s 防抖 timer 从原 WorkflowEditor.jsx 逐字提取；`WorkflowEditor.tsx` 只负责渲染和画布事件。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../service-design-documents/workflow.md`](../service-design-documents/workflow.md)
- 实体层 [`workflow.md`](workflow.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| markDirty | 画布变更 → 标记脏 + 重置 2s 防抖 timer |
| diffToOps | 原始图 vs 当前图 → `WorkflowEditOp[]`（add/update/delete × node/edge）|
| autosave | timer 触发 → ops 非空 → POST `/workflows/{id}:edit` |
| dirty / savedAt / isSaving | 状态暴露给 WorkflowEditor 显示保存指示器 |

该 slice **不**管理画布的节点/边状态（由 WorkflowEditor 本地管理）；仅接受变更后的完整图快照，计算 diff，发起保存。

---

## 2. 类型（`model/useWorkflowEdit.ts` 导出）

```ts
export interface CanvasNode {
  id: string; kind: string; label?: string; notes?: string;
  config?: Record<string, unknown>; onError?: string;
  timeout?: number; retry?: unknown;
  x: number; y: number; sub?: string;
}

export interface CanvasEdge {
  id?: string; from: string; to: string;
  fromPort?: string; toPort?: string;
  fromHandle?: string; toHandle?: string;
}

export interface CanvasGraph {
  nodes: CanvasNode[];
  edges: CanvasEdge[];
}

// 与后端 WorkflowEditOp 一一对应（entities/workflow 导出）
// update_node 走 RFC 7396 JSON Merge Patch：{nodeId, patch}（不是整 NodeSpec）。
type WorkflowEditOp =
  | { op: "add_node";    node: NodeSpec }
  | { op: "update_node"; nodeId: string; patch: Partial<NodeSpec> }
  | { op: "delete_node"; id: string }
  | { op: "add_edge";    edge: EdgeSpec }
  | { op: "delete_edge"; id: string };
```

---

## 3. diff 算法（`diffToOps`）

### edgeKey — 边的稳定标识

```ts
edgeKey(e) = `${e.from}|${e.fromPort||""}->${e.to}|${e.toPort||""}`
```

忽略 `e.id`（画布层 id 不稳定）；以端口组合作为唯一键。

### nodeChanged — 字段比较

比较 `type/kind`、`notes`、`position(x,y)`、`timeout`、`onError`、`config`（JSON 序列化比较）。

注意：`orig` 侧节点来自后端响应，可能有 `.type` 和 `.position` 字段而非 `.kind`/`.x/.y`；`nodeChanged` 兼容两种形状（`a.type !== b.kind`、`(a.position?.x ?? a.x) !== b.x`）。

### 三向 diff 流程

```
diffToOps(orig, next) → WorkflowEditOp[]:

  节点：
    oN = Map(orig.nodes, id→node)
    nN = Map(next.nodes, id→node)
    for n of next.nodes:
      !oN.has(n.id)       → add_node
      nodeChanged(o, n)   → update_node
    for o of orig.nodes:
      !nN.has(o.id)       → delete_node

  边：
    oE = Map(orig.edges, edgeKey→edge)
    nE = Map(next.edges, edgeKey→edge)
    for e of next.edges:
      !oE.has(edgeKey(e)) → add_edge
    for e of orig.edges:
      !nE.has(edgeKey(e)) → delete_edge(e.id || edgeKey(e))
```

边没有 update 操作（边语义即端口组合，变化等于 delete + add）。

---

## 4. 用例 hook（`model/useWorkflowEdit.ts`）

### 编排步骤

```
useWorkflowEdit(workflowId, original: CanvasGraph)
  edit = useEditWorkflow(workflowId)   // entities/workflow

  markDirty(graph: CanvasGraph):
    1. setDirty(true)
    2. clearTimeout(saveTimer.current)
    3. saveTimer.current = setTimeout(() => {
         ops = diffToOps(original, graph)
         if ops.length === 0: setDirty(false); return
         edit.mutate({ ops, changeReason:"editor autosave" }, {
           onSuccess: setDirty(false) + setSavedAt(new Date()),
           // 失败: 全局 MutationCache onError
         })
       }, 2000)

  useEffect(() => cleanup: clearTimeout(saveTimer.current), [])
```

### 意图 API

```ts
const { markDirty, resetDirty, dirty, savedAt, isSaving } = useWorkflowEdit(workflowId, original);
```

| 成员 | 类型 | 说明 |
|---|---|---|
| `markDirty` | `(graph: CanvasGraph) => void` | 画布任何变更调用；触发防抖 autosave |
| `resetDirty` | `() => void` | 版本切换时调用：取消在途 timer、清 dirty flag，防止版本 N 的脏态持续到版本 N+1 |
| `dirty` | `boolean` | 有未保存变更 |
| `savedAt` | `Date \| null` | 最近一次成功保存时间 |
| `isSaving` | `boolean` | autosave mutation 进行中 |

---

## 5. 端到端数据流

```
WorkflowEditor 画布事件（节点移动/添加/删除、边添加/删除）
  → WorkflowEditor 本地 setState 更新 nodes/edges
  → markDirty(currentGraph)
      → setDirty(true)
      → clearTimeout(prev)
      → setTimeout(2000ms):
          ops = diffToOps(original, currentGraph)
          if ops.length === 0: 无变化 → setDirty(false)
          else: edit.mutate({ ops })
                  → POST /workflows/{id}:edit  (200)
                  → onSuccess: dirty=false, savedAt=now
                  → 失败: 全局 toast，dirty 保持 true（用户可感知）
```

---

## 6. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| 保存错误 toast | 全局 `MutationCache onError`；feature 不重复 toast |
| 防抖竞态 | 每次 markDirty 清除前一个 timer；只有最后一次变更会发请求 |
| ops 为空时不发请求 | diffToOps 结果长度 0 → early return，避免无意义 API 调用 |
| 卸载清理 | `useEffect` cleanup → `clearTimeout`，防止卸载后 mutate |
| orig 稳定性 | `original` 作为 `useCallback` dep；WorkflowEditor 需保证 prop 引用稳定 |
| 版本切换脏态 | WorkflowEditor 版本变更 effect 调 `resetDirty()`，防止旧版本脏态渗入新版本 |

---

## 7. 纯函数导出（可单独测试）

```ts
export { diffToOps }    // 三向 diff，纯函数
export { nodeToSpec }   // CanvasNode → 后端 NodeSpec（用于 add_node）
export { nodeToPatch }  // CanvasNode → update_node patch（不含 id / modelOverride）
export { edgeToSpec }   // CanvasEdge → 后端 EdgeSpec
export { edgeKey }      // 边的稳定标识符
```

---

## 8. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/workflow-edit/model/useWorkflowEdit.ts` | 核心 hook + diffToOps 算法 + 纯函数导出 |
| `frontend/src/features/workflow-edit/model/useWorkflowEdit.test.ts` | diffToOps 单测 |
| `frontend/src/features/workflow-edit/ui/WorkflowEditor.tsx` | 画布 UI；消费 useWorkflowEdit |
| `frontend/src/features/workflow-edit/index.ts` | public API（hook + 类型 + 纯函数 + 组件）|
