# widgets/command-palette — 前端 slice 详细设计

**所属层**：widgets（聚合 entities/conversation + entities/function + entities/handler + entities/workflow + entities/flowrun）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：⌘K 调起的全局命令板。模糊搜索导航项 + 对话 + forge 实体 + flowrun。键盘优先（↑↓导航、Enter 选中、Esc 关闭）；鼠标 hover 同步 active index。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| 候选项聚合 | 8 个导航项 + 最近 6 条对话 + Function/Handler/Workflow/FlowRun 各前 5 条 |
| 模糊过滤 | `label + desc` 联合字符串 `.includes(query)` |
| 分组渲染 | 相同 group 的 items 聚合展示，group 名作 section header |
| 键盘导航 | ArrowUp/Down 移动 active；Enter 触发 action；Esc 关闭 |
| 动画 | AnimatePresence + `scaleIn` / `fadeIn`（shared/lib/motion） |

---

## 2. Props 接口

```ts
interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
  onOpenPane: (pane: string) => void;
  onOpenEntity: (pane: string, id: string) => void;
  onSetActiveConv: (id: string | null) => void;
  onOpenSettings: () => void;
}
```

所有回调均由 AppShell 传入；组件自身无 app/model 依赖。

---

## 3. 数据流

```
useConversations()  → 最近对话组（最多 6 条）
useFunctions()      → Function 组（最多 5 条）
useHandlers()       → Handler 组（最多 5 条）
useWorkflows()      → Workflow 组（最多 5 条）
useFlowRuns()       → FlowRun 组（最多 5 条）

全部 useMemo 组合 → CmdItem[] → 模糊过滤 → 分组渲染
```

---

## 4. 候选项 action 映射

| 来源 | action |
|---|---|
| 导航项（非 settings） | `onOpenPane(target)` |
| settings 导航项 | `onOpenSettings()` |
| 对话 | `onSetActiveConv(id)` + `onOpenPane("chat")` |
| Function / Handler / Workflow | `onOpenEntity("forge", id)` |
| FlowRun | `onOpenEntity("execute", id)` |

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/widgets/command-palette/CommandPalette.tsx` | 主组件 |
| `frontend/src/widgets/command-palette/index.ts` | public API export |
