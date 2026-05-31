---
id: DOC-216
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/document — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/document）
**状态**：✅ 已实现
**职责**：管理 Document（知识库文档节点）的 CRUD + 树形结构查询 + 移动排序。Document 是层级结构（parentId），侧边栏以树形渲染。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/document.md`

---

## 1. 职责边界

- 树形节点列表（GET /documents/tree — 扁平含 path，前端重建树）
- 文档 CRUD（create / read / update / delete）
- 节点移动排序（:move — 修改 parentId 和 position）

不含 wiki-link 解析（后端 pkg/wikilink）、document 关联边（entities/relation）。

---

## 2. 类型（`model/types.ts`）

```ts
interface Document {
  id: string;       // doc_<16hex>
  userId: string;
  parentId: string | null;   // null = 根节点
  name: string;
  description: string;
  content: string;
  tags: string[];
  position: number;
  path: string;       // 祖先路径，如 "Root/Notes"
  sizeBytes: number;
  createdAt: string; updatedAt: string;
}

interface DocTreeNode {    // GET /documents/tree 的轻量节点（无 content）
  id; userId; parentId; name; description; tags;
  position; path; sizeBytes; createdAt; updatedAt;
}

interface CreateDocumentBody { name; parentId?; content?; description?; tags? }
interface UpdateDocumentPatch { name?; content?; description?; tags? }
interface MoveDocumentVars { id; parentId: string | null; position? }
```

`DocTreeNode` 比 `Document` 少 `content` 字段，用于树形渲染时不拉取全文内容。

---

## 3. API hooks（`api/document.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useDocumentTree()` | GET `/documents/tree` | 扁平节点列表（含 path），前端构建树形 |
| `useDocuments()` | GET `/documents?limit=200` | 平铺文档列表 |
| `useDocument(id)` | GET `/documents/{id}` | 单条详情（含 content） |
| `useCreateDocument()` | POST `/documents` | 创建；invalidate documents + tree |
| `useUpdateDocument(id)` | PATCH `/documents/{id}` | 更新内容/名称/标签；invalidate document(id) + tree |
| `useDeleteDocument()` | DELETE `/documents/{id}` | invalidate documents + tree |
| `useMoveDocument()` | POST `/documents/{id}:move` body `{parentId, position}` | 移动节点；invalidate tree |

tree 端点走独立 query key `["documents","tree"]`（不走 `qk.documents()`），与 document 详情缓存分开管理。

---

## 4. 端到端数据流

### 4.1 侧边栏树渲染

```
Sidebar → useDocumentTree()
  → GET /documents/tree
  → 返回 DocTreeNode[] 扁平列表（每个节点含 path）
  → 前端按 parentId 分组重建树形结构
  → 渲染折叠/展开树节点
```

### 4.2 拖拽移动

```
用户拖拽节点到新父节点
  → useMoveDocument().mutate({id, parentId: newParentId, position: newPos})
      → POST /documents/{id}:move  {parentId, position}
      → onSuccess: invalidate ["documents","tree"]
      → 侧边栏重取 tree 重渲染
```

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/document/model/types.ts` | Document / DocTreeNode / Create* / Update* / Move* 类型 |
| `frontend/src/entities/document/api/document.ts` | 7 个 hooks |
| `frontend/src/entities/document/index.ts` | public API |
