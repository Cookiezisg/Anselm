# pages/library — 前端 slice 详细设计

**所属层**：pages（聚合 entities/document + entities/skill + entities/mcp + entities/memory）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**覆盖**：DocumentsPage / SkillsPage / McpPage / MemoryPage（均在 `pages/library/`）

---

## DocumentsPage

**职责**：Notion-style 文档树 + 所见即所得 Tiptap 编辑器。左侧树，右侧 title input + body editor；无双列 preview 模式。

### Props

```ts
interface DocumentsPageProps {
  activeDoc?: string | null;
  onSetActiveDocument: (id: string | null) => void;
}
```

AppShell 从 paneStore 提取 `activeDocument` / `setActiveDocument` 后传入。

### 子组件

| 组件 | 职责 |
|---|---|
| `DocSidebar` | 树形侧边栏；搜索过滤 + 展开/折叠；ActionMenu（删除）+ 新建子节点 |
| `DocTreeNode` | 单节点行（递归）；缩进 `4 + depth * 14`px |
| `DocPage` | title input + Tiptap body；1500ms debounce 自动保存 |
| `DocEditor` | Tiptap 富文本；markdown shortcuts；`/` 命令面板；`@` 文档引用 |

### 数据流

```
useDocumentTree()         → 平铺列表 → buildTree() → 递归树结构
useDocument(docId)        → 当前文档内容
useCreateDocument()       → 新建后自动 setActiveDocument + pendingFocusTitle
useUpdateDocument(docId)  → PATCH name/content（1500ms debounce）
useDeleteDocument()       → 软删
```

### 保存状态机

`status = update.isPending ? "saving" : dirty ? "dirty" : "clean"` → 头部 `.wf-saved is-{status}` 指示器。

### 侧边栏折叠

`useCollapsible("documents-sidebar", true)` 持久化到 localStorage；折叠后显示 `PaneCollapseToggle` 展开按钮。

---

## SkillsPage / McpPage / MemoryPage

这三个页面结构相似：只读列表 + 点击查看详情（或配置弹窗）。无外部 props，各自直接调 entities 层 hooks。

| 页面 | entities hook | 主要操作 |
|---|---|---|
| `SkillsPage` | `useSkills()` | 列表；技能详情（名称/描述/参数） |
| `McpPage` | `useMcpServers()` | 列表；服务器状态；连接/断开 |
| `MemoryPage` | `useMemories()` | 列表；查看/删除记忆条目 |

---

## 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/pages/library/DocumentsPage.tsx` | 文档页主组件 + DocSidebar + DocPage + DocTreeNode |
| `frontend/src/pages/library/DocumentsPage.tsx ui/DocEditor.tsx` | Tiptap 编辑器 |
| `frontend/src/pages/library/SkillsPage.tsx` | 技能列表 |
| `frontend/src/pages/library/McpPage.tsx` | MCP 服务器列表 |
| `frontend/src/pages/library/MemoryPage.tsx` | 记忆条目列表 |
