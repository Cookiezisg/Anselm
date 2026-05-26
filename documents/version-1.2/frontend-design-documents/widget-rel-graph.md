# widgets/rel-graph — 前端 slice 详细设计

**所属层**：widgets（聚合 features/entity-link + entities/relation + shared/lib/navigation）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：力导向实体关系图（Obsidian-style）。节点 = 工作区所有实体；边 = 8 种 relation kind。支持拖节点、滚轮缩放、画布平移。右侧 FloatingInspector 列出选中节点的入/出引用，点击可跳转对应 pane。额外导出 `RelGraphPopover`（mini 聚焦图）和 `RelMore`（"…" 触发按钮）。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| 全图视图 `RelGraph` | `useEntityDirectory()` 聚合 8 种实体 → nodes+edges；自管 kind filter + selected state |
| 力导向引擎 `GraphCanvas` | 纯 canvas/SVG；repulse+spring+center 三力；rAF tick；degree → 节点半径 |
| 节点详情面板 `NodeDetail` | FloatingInspector 内；入/出引用 `AdjacencySection` 列表；`navigate` DIP 跳转 |
| Mini 聚焦图 `RelGraphPopover` | `useNeighborhood(depth=2)` 取邻域；固定 420×300 canvas；portal 到最近 `.pane` |
| 触发按钮 `RelMore` | "…" icon-btn；点击 → 查询最近 `.pane` + 挂载 RelGraphPopover |

---

## 2. 导出接口

```ts
// 全图（Observe 页面）
export function RelGraph(): JSX.Element

// 聚焦图 popover（实体详情头部附近弹出）
export function RelGraphPopover(props: {
  entityId: string;
  kind?: string;
  onClose: () => void;
  paneEl?: Element | null;   // portal 目标；null 则渲染到 document.body
}): JSX.Element

// "..." 触发按钮（自管 popover 开关）
export function RelMore(props: {
  entityId: string;
  kind?: string;
  label?: string;
}): JSX.Element

// SplitDiff + CodeView (版本对比/代码显示，也定义在此文件)
export function SplitDiff(...): JSX.Element
export function CodeView(...): JSX.Element
```

---

## 3. 数据流

```
useEntityDirectory()          (features/entity-link) 聚合所有实体 → EntityNode[]/EntityEdge[]
useNeighborhood(kind, id, 2)  (entities/relation)   邻域子图（RelGraphPopover 用）

navigate.openConv(id)         )
navigate.openEntity(pane, id) ) (shared/lib/navigation DIP) — NodeDetail 点击跳转
navigate.openPane("observe")  )
```

`useEntityDirectory` 返回的 `normEdges` 去重 + 归一化方向；`guessKind(entityId)` 按 ID 前缀推断实体类型。

---

## 4. 力导向参数

| 参数 | 值 | 说明 |
|---|---|---|
| `repulseK` | 2200 | 节点间排斥强度 |
| `springK` | 0.04 | 边弹簧强度 |
| `springLen` | 110 | 弹簧自然长度（px） |
| `damping` | 0.82 | 速度阻尼系数 |
| `centerK` | 0.002 | 中心引力系数 |
| 节点半径 | `3 + min(5, degree * 0.6)` | 度越大节点越大；focusId 节点固定 8px |

---

## 5. 节点颜色 / 图标

| kind | 颜色 | Lucide 图标 |
|---|---|---|
| function | #2383E2 | Code |
| handler | #0F7B6C | Server |
| workflow | #D97757 | Workflow |
| skill | #B25E10 | Sparkles |
| mcp | #6940A5 | Server |
| memory | #9A4A6F | Brain |
| conversation | #3D5A80 | MessageSquare |
| document | #5E6470 | FileText |
| flowrun | #888888 | Play |

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/widgets/rel-graph/RelGraph.tsx` | RelGraph / RelGraphPopover / RelMore / GraphCanvas / NodeDetail / SplitDiff / CodeView |
| `frontend/src/widgets/rel-graph/index.ts` | public API export |
