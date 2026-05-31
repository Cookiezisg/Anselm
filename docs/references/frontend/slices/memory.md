---
id: DOC-229
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/memory — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/memory）
**状态**：✅ 已实现
**职责**：管理 Memory 条目（用户 / AI 生成的知识片段）的 CRUD + 置顶。Memory 使用 `id` 为主键，但 `name` 唯一且用于 API 路径。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `references/backend/domains/memory.md`

---

## 1. 职责边界

- 按类型过滤查询（user / feedback / project / reference）
- 单条详情
- 创建 / 更新（PATCH）/ 删除
- 置顶 / 取消置顶（通过 PATCH pinned 字段）

---

## 2. 类型（`model/types.ts`）

```ts
interface Memory {
  id: string;       // mem_<16hex>
  name: string;     // 唯一，API 路径键
  type: "user" | "feedback" | "project" | "reference";
  description: string;
  content: string;
  pinned: boolean;
  source: "user" | "ai";
  metadata?: Record<string,unknown>;
  createdAt; updatedAt; accessedAt?;
  accessCount: number;
}

interface CreateMemoryBody { name; type; description; content; pinned?; source? }
interface UpdateMemoryBody { description?; content?; type?; pinned? }
interface PinMemoryVars { name: string; pinned: boolean }
```

API 路径使用 `name`（encodeURIComponent 编码），不用 `id`——与后端 HTTP handler 对齐。

---

## 3. API hooks（`api/memory.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useMemories(type?)` | GET `/memories?type={type}` | 列表，type 可选；select pickList |
| `useMemory(name)` | GET `/memories/{name}` | 单条详情 |
| `useCreateMemory()` | POST `/memories` | 创建；invalidate ["memories"] |
| `useUpdateMemory()` | PATCH `/memories/{name}` body | 更新内容/类型/pinned；invalidate ["memories"] |
| `useDeleteMemory()` | DELETE `/memories/{name}` | invalidate ["memories"] |
| `usePinMemory()` | PATCH `/memories/{name}` body `{pinned}` | 置顶快捷封装；invalidate ["memories"] |

`usePinMemory` 是 `useUpdateMemory` 的便利封装，减少调用方 boilerplate。

---

## 4. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/memory/model/types.ts` | Memory / Create* / Update* / Pin* 类型 |
| `frontend/src/entities/memory/api/memory.ts` | 6 个 hooks |
| `frontend/src/entities/memory/index.ts` | public API |
