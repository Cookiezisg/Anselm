# app/model — 前端 slice 详细设计

**所属层**：app（被 AppShell + App 消费；不依赖 pages/widgets）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：AppShell 的全局状态层。三个 zustand store（paneStore / sidebarStore / overlayStore）+ useSessionBootstrap hook。

---

## 1. paneStore（`model/paneStore.ts`）

**职责**：pane 布局状态、当前活跃资源（conv/run/doc）、分屏比例、narrow 模式、focus-entity 跳转队列。

```ts
interface PaneState {
  openPanes: string[];          // 当前打开 pane，最多 MAX_PANES=2
  activeConv: string | null;
  activeFlowRun: string | null;
  activeDocument: string | null;
  leftPct: number;              // 分屏比例，clamp 20–80
  narrow: boolean;              // main < 1000px
  activeNarrowPane: string | null;
  focusEntity: Record<string, string>;   // { pane: entityId }，消费后清除

  // actions
  setActiveConv / setActiveFlowRun / setActiveDocument
  togglePane / openPane / closePane
  openEntity(pane, id): 设置 focusEntity[pane] = id + 打开 pane
  consumeFocusEntity(pane): 读取并清除 focusEntity[pane]
  setLeftPct / setNarrow / setActiveNarrowPane
}
```

**MAX_PANES = 2**：超过 2 个 pane 时，openPane/togglePane 丢弃 openPanes[0]（FIFO）。

**cross-user 清理**：App 层监听 `useSessionStore.currentUserId` 变化 → `setActiveConv(null) / setActiveFlowRun(null) / setActiveDocument(null)`（App.tsx 4a.6 节逻辑）。

---

## 2. sidebarStore（`model/sidebarStore.ts`）

**职责**：sidebar 折叠 + 分组展开状态，持久化到 localStorage。

```ts
interface SidebarState {
  collapsed: boolean;
  toolsExpanded: boolean;
  recentExpanded: boolean;
  archivedExpanded: boolean;
  // 每个 setter 同时写 localStorage (key: "sidebar.*")
}
```

localStorage key：`sidebar.collapsed` / `sidebar.toolsExpanded` / `sidebar.recentExpanded` / `sidebar.archivedExpanded`；值 `"1"` = true，`"0"` = false；QuotaExceededError 静默吞掉（sidebar 状态是装饰性的）。

---

## 3. overlayStore（`model/overlayStore.ts`）

**职责**：全局浮层开关状态 + pendingAsk 载荷。

```ts
interface OverlayState {
  cmdkOpen: boolean;
  notifsOpen: boolean;
  askOpen: boolean;
  settingsOpen: boolean;
  pendingAsk: PendingAsk | null;
  // setters: set* 系列
}

interface PendingAsk {
  id: string;
  conversationId: string;
  toolCallId: string;
  question?: string;
  context?: string;
  options?: Array<{ id?; value?; text?; label?; sub? }>;
}
```

`pendingAsk` 由 `useNotifications` SSE hook 在收到 `ask` type 通知时写入；AskUserModal 和 NotificationsDrawer（待办 tab）消费它；答题提交后 `setPendingAsk(null)` 清除。

---

## 4. useSessionBootstrap（`model/useSessionBootstrap.ts`）

**职责**：App 根组件调用一次，完成两件事：

1. **DIP 注册**：把 `sessionStore.currentUserId` 注入 `shared/api/authProvider.setUserIdProvider`，使所有 API 请求自动携带当前用户 ID；把 `resolveSession` 注入 `setOnAuthFailure`，使 401 后自动重新解析身份（根治 401 风暴）。

2. **启动身份解析**：调 `resolveSession()`；若失败（Wails 冷启动竞态：前端挂载早于后端端口就绪），指数退避重试（最大 5s），`attempt * 1000` ms，避免 status 永远卡在 "loading"。

```ts
export function useSessionBootstrap(): "loading" | "onboarding" | "ready"
```

返回值来自 `useSessionStore((s) => s.status)`；App.tsx 根据此值决定渲染 `<Onboarding />` / booting shell / `<AppShell />`。

---

## 5. public API（`model/index.ts`）

```ts
export { usePaneStore } from "./paneStore";
export { useSidebarStore } from "./sidebarStore";
export { useOverlayStore, type PendingAsk } from "./overlayStore";
export { useSessionBootstrap } from "./useSessionBootstrap";
```

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/app/model/paneStore.ts` | pane 布局 + 资源激活 + focusEntity 队列 |
| `frontend/src/app/model/sidebarStore.ts` | sidebar 折叠展开，localStorage 持久化 |
| `frontend/src/app/model/overlayStore.ts` | 浮层开关 + pendingAsk 载荷 |
| `frontend/src/app/model/useSessionBootstrap.ts` | DIP 注册 + 启动身份解析 + 退避重试 |
| `frontend/src/app/model/index.ts` | public API export |
