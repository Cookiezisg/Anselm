---
id: DOC-241
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/user — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/user）
**状态**：✅ 已实现
**职责**：管理 User 实体（资料 CRUD）+ `useDisplayName` 辅助 hook。User 在本地单用户环境下通常只有一条记录，但架构支持多用户（onboarding 时用户可切换）。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `references/backend/domains/user.md`
- `entities/session` — 持有 currentUserId，user entity 不含身份状态

---

## 1. 职责边界

- User CRUD（列表 / 创建 / 更新资料 / 删除）
- `useDisplayName` — 当前激活用户的显示名，读 users 列表，写回 PATCH /users/{id}

不含身份状态（currentUserId / status）——那是 entities/session 的职责。

---

## 2. 类型（`model/types.ts`）

```ts
interface User {
  id: string;     // u_<16hex>
  username: string;
  displayName: string;
  avatarColor: string;
  language: string;
  lastUsedAt: string | null;
  createdAt; updatedAt;
}

interface CreateUserBody { username; displayName?; avatarColor?; language? }
interface UpdateUserPatch { displayName?; avatarColor?; language? }
```

---

## 3. API hooks（`api/user.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useUsers()` | GET `/users` | 全量列表；select pickList |
| `useCreateUser()` | POST `/users` | 创建（onboarding 用）；invalidate users |
| `useUpdateUser()` | PATCH `/users/{id}` | 更新资料；invalidate users |
| `useDeleteUser()` | DELETE `/users/{id}` | invalidate users |

---

## 4. 辅助 lib（`lib/useDisplayName.ts`）

```
useDisplayName()
  → useSessionStore → currentUserId        (来自 entities/session @x/user)
  → useUsers()                              (来自本 slice api)
  → user = users.find(u => u.id === currentUserId)
  → value = user.displayName || user.username || ""
  → setValue(next) → useUpdateUser().mutate({id, patch:{displayName}})
  → 返回 [value, setValue]
```

`useDisplayName` 通过 `@x/user` DIP 机制消费 session，而不直接 import sessionStore（避免 entities 层循环依赖）。

---

## 5. @x 边界

`entities/user/@x/session.ts` 暴露 `User` 类型给 entities/session 使用（session.api 需要知道 User 形状以做类型约束），是标准 FSD cross-entity 机制。

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/user/model/types.ts` | User / Create* / Update* 类型 |
| `frontend/src/entities/user/api/user.ts` | 4 个 hooks |
| `frontend/src/entities/user/lib/useDisplayName.ts` | 当前用户显示名读写 |
| `frontend/src/entities/user/@x/session.ts` | 暴露 User 类型给 session slice |
| `frontend/src/entities/user/index.ts` | public API |
