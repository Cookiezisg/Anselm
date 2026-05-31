# pages/observe — 前端 slice 详细设计

**所属层**：pages（聚合 widgets/rel-graph）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：实体关系图谱全览页。pane shell（page-header）+ `RelGraph` widget（力导向 + filter + node detail）。无外部 props，直接渲染。

---

## 1. 结构

```
ObservePage
  └─ page-header
       ├─ page-title（GitBranch 图标 + i18n "observePane.title"）
       └─ page-subtitle（i18n "observePane.subtitle"）
  └─ RelGraph（flex: 1, minHeight: 0，防 overflow）
```

`RelGraph` 内部通过 `RGAutoSize`（ResizeObserver）自适应容器宽高；全量实体从 `useEntityDirectory()` 聚合。

---

## 2. 无 props

`ObservePage` 是纯容器，无外部 props；所有交互（filter、node 选中、跳转）全在 RelGraph 内部处理。

---

## 3. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/pages/observe/ui/ObservePage.tsx` | 主组件（pane shell + RelGraph） |
| `frontend/src/pages/observe/index.ts` | public API export |
