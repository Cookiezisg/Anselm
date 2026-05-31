---
id: DOC-238
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/session — 前端 slice 详细设计

**所属层**：entities（对位后端 reqctx user identity + domain/user）
**状态**：✅ 已实现（FSD Revamp 阶段 3–4 重点修复，根治 401 风暴）
**职责**：维护前端身份三元组（currentUserId / status / resolveSession），是全局唯一的身份真相源。所有需要 userId 的组件通过本 slice 读取，而非直接读 localStorage 或 settings。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `references/backend/domains/user.md`（/users 端点）
- 前端 `app` 层 `useSessionBootstrap`（boot gate 消费方）

---

## 1. 为什么需要独立的 session slice

V1.2 Revamp 前，身份自愈逻辑散在 5 处（App.jsx 两个 effect + client.js + shared.js + boot.js），互相竞态，导致 401 死循环风暴。根治方案：

- **唯一身份真相源**：`useSessionStore`（Zustand persist）持有 `currentUserId`
- **Fresh resolve 优先**：`resolveSession` 永远基于 fresh `/users` fetch，不依赖 TanStack 缓存快照
- **Boot gate**：App 层 `useSessionBootstrap` 在 status="ready" 前阻塞渲染，防止脏 userId 喂给 SSE/API

---

## 2. 类型（`model/sessionStore.ts`）

```ts
interface SessionState {
  currentUserId: string | null;
  status: "loading" | "onboarding" | "ready";
  setCurrentUser(id: string | null): void;
  setStatus(s: SessionState["status"]): void;
}
```

| 状态 | 含义 |
|---|---|
| `loading` | resolveSession 正在执行 /users fetch |
| `onboarding` | /users 返回空列表，需要创建第一个用户 |
| `ready` | currentUserId 有效，可正常使用 |

---

## 3. model（`model/sessionStore.ts`）

```ts
export const useSessionStore = create<SessionState>()(
  persist(
    (set) => ({
      currentUserId: null,
      status: "loading",
      setCurrentUser: (id) => set({ currentUserId: id }),
      setStatus: (status) => set({ status }),
    }),
    {
      name: "forgify-session",
      partialize: (s) => ({ currentUserId: s.currentUserId }),
    }
  )
);
```

`partialize` 只持久化 `currentUserId`，不持久化 `status`（每次启动重新 resolve）。`status` 初始值为 `"loading"` 使 boot gate 默认拦住。

---

## 4. resolveSession（`model/resolve.ts`）

```ts
let inflight: Promise<void> | null = null;

export async function resolveSession(): Promise<void> {
  if (inflight) return inflight;
  inflight = _resolve().finally(() => { inflight = null; });
  return inflight;
}

async function _resolve(): Promise<void> {
  const s = useSessionStore.getState();
  s.setStatus("loading");
  const users = await fetchUsers();   // 直接 apiFetch，不经 TanStack 缓存

  if (users.length === 0) {
    s.setCurrentUser(null);  // 清 stale userId，防止 SSE 以旧 id 尝试连接
    s.setStatus("onboarding");
    return;
  }

  const valid = !!s.currentUserId && users.some((u) => u.id === s.currentUserId);
  if (!valid) s.setCurrentUser(users[0].id);
  s.setStatus("ready");
}
```

关键设计：
- **模块级 in-flight 去重**：StrictMode 双调、多路 SSE 断连同时触发时复用同一 Promise，只发一次 `/users` 请求
- `fetchUsers` 直接调 `apiFetch`（绕过 TanStack 缓存）——确保 resolve 基于最新 /users 数据，不受 stale 快照影响
- **onboarding 分支清空 userId**：`setCurrentUser(null)` 防止空用户列表时 stale userId 仍触发 SSE 连接
- stale/null `currentUserId` 自动 fallback 到 `users[0]`（单用户场景无感切换）
- 不循环重试——失败抛到 App 层处理

---

## 5. API（`api/session.ts`）

```ts
export function fetchUsers(): Promise<User[]> {
  return apiFetch("/users").then(pickList<User>);
}
```

`fetchUsers` 是裸 Promise，不是 TanStack hook——resolve 时需要即时数据而非缓存。

---

## 6. @x DIP 注册（`@x/user.ts`）

```ts
export { useSessionStore } from "../model/sessionStore";
export type { SessionState } from "../model/sessionStore";
```

`entities/session/@x/user.ts` 暴露 sessionStore 给 `entities/user`（useDisplayName 需要 currentUserId）和 `shared/api`（httpClient 需要 userId 注入 header）。这是 FSD cross-entity 标准机制，避免直接层间跨越。

---

## 7. 端到端数据流（boot gate）

```
App 启动
  → app/useSessionBootstrap (effect)
      → resolveSession()
          → fetchUsers() 直接 apiFetch("/users")
          → users.length === 0 → setStatus("onboarding")
                                 → Onboarding 组件接管
          → currentUserId 无效 → setCurrentUser(users[0].id)
          → setStatus("ready")
  → App render 等待 status !== "loading"
      → status = "onboarding" → 渲染 Onboarding
      → status = "ready" → 渲染主 UI + 启动 SSE

SSE / apiFetch userId 注入路径：
  shared/api/httpClient 通过 DIP 注册点（@x/user）读取 currentUserId
  → 注入 X-User-Id 请求头（或 URL 参数）
  → 后端 InjectUserID 中间件解析
```

---

## 8. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/session/model/sessionStore.ts` | useSessionStore（persist，currentUserId + status） |
| `frontend/src/entities/session/model/resolve.ts` | resolveSession（fresh fetch + fallback 逻辑） |
| `frontend/src/entities/session/api/session.ts` | fetchUsers（裸 Promise，绕 TanStack 缓存） |
| `frontend/src/entities/session/@x/user.ts` | 暴露 sessionStore 给 user slice + shared/api |
| `frontend/src/entities/session/index.ts` | public API |
