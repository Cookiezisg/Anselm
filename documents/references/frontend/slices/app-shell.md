---
id: DOC-213
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# app/AppShell — 前端 slice 详细设计

**所属层**：app（消费 app/model + app/sse + widgets + pages + features）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：布局中枢。sidebar | main 网格；main 最多 2 个 pane 并排（可拖宽中线）；main < 1000px 自动切 narrow 模式（单 pane + 底部 tab 切换）。从所有 store 读状态并以 props 形式向下注入 pages 和 widgets，本层是整个 app 唯一的跨层聚合点。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| 布局引擎 | sidebar（motion.aside，spring 展开）+ main（flex row，pane-wrap） |
| 双 pane 分屏 | `leftPct`（20–80%）拖拽调节；`PaneResizeBetween` 绝对定位在左 pane 右边缘 |
| narrow 模式 | ResizeObserver 检测 main.clientWidth < 1000 → setNarrow；只显示 activeNarrowPane；NarrowSwitch 底部 tab |
| pages 路由 | `renderPaneBody(kind, onClose, pageProps)` switch → 8 种 pane kind |
| props 注入 | 从 paneStore/sidebarStore/overlayStore/SSEHealth 提取 → 传给 Sidebar / pages / widgets |
| navigator 注册 | `setNavigator({...})` 在 mount 时注册 shared/lib/navigation DIP 实现 |
| 键盘快捷键 | `useKeyboardShortcuts()` 挂载全局监听 |
| pane 进出动画 | AnimatePresence mode="popLayout"；每 pane-wrap 独立 opacity + scale 动画 |

---

## 2. 状态来源

```
paneStore:
  openPanes            → 当前打开的 pane 列表（最多 2）
  activeConv           → ChatPage.activeConv
  activeFlowRun        → ExecutePage focusEntity（间接）
  activeDocument       → DocumentsPage.activeDoc
  leftPct              → 分屏比例
  narrow               → 是否窄屏模式
  activeNarrowPane     → narrow 模式下可见的 pane
  focusEntity          → { forge?: id; execute?: id }（一次性跳转队列）
  consumeFocusEntity   → 消费后清除（防 re-trigger）

sidebarStore:
  collapsed / toolsExpanded / recentExpanded / archivedExpanded
  → 全部传给 Sidebar

overlayStore:
  cmdkOpen / notifsOpen / askOpen / settingsOpen / pendingAsk
  → 各对应 widget/modal 开关

SSEHealth (useSSEHealth()):
  overall / eventlog / notifs / forge / unread / clearUnread
  → 传给 Sidebar.sseHealth + NotificationsDrawer.unread/clearUnread
```

---

## 3. props 注入模式

```ts
// AppShell 内构建 pageProps 对象，传给 renderPaneBody
const pageProps = {
  chat:      { activeConv, onSetActiveConv: setActiveConv, onOpenSettings: () => setSettingsOpen(true) },
  forge:     { focusEntity, onConsumeFocusEntity: consumeFocusEntity, onOpenExecute: onOpenExecuteRun },
  execute:   { focusEntity, onConsumeFocusEntity: consumeFocusEntity, onOpenChat },
  documents: { activeDoc: activeDocument, onSetActiveDocument: setActiveDocument },
};
```

pages 层组件**零 app 依赖**——它们只通过 props 拿到回调，不直接 import store。这是 FSD 层级隔离的核心设计。

---

## 4. navigator DIP 注册

```ts
useEffect(() => {
  setNavigator({
    openConv:          (id) => { setActiveConv(id); openPane("chat"); },
    openEntity:        (pane, id) => openEntity(pane, id),
    openPane:          (pane) => openPane(pane),
    setActiveDocument: (id) => { setActiveDocument(id); openPane("documents"); },
  });
}, []);
```

`shared/lib/navigation` 中 `navigate.openConv` 等调用者（EntityLink、RelGraph、AskAiTrigger 等）通过这个 DIP 接口路由，不反向依赖 app 层。

---

## 5. 分屏拖拽

```
PaneResizeBetween（绝对定位在左 pane 右边缘，4px 宽）
  → PaneResize（拖动时 onDrag(clientX)）
     → AppShell.onPaneDrag（useCallback，防 PaneResize 重新 attach 监听）
        → setLeftPct(((clientX - mainLeft) / mainWidth) * 100)  clamp 20–80
```

`onPaneDrag` 必须 useCallback，否则每次 leftPct 变化都产生新函数引用 → PaneResize useEffect 重新 attach/detach → 快速拖动时 mousemove 事件丢失（卡顿）。

---

## 6. narrow 模式

- ResizeObserver 监听 `mainRef.current`；`clientWidth < 1000` → `setNarrow(true)`
- narrow 时 `openPanes.length === 2` 且 `!activeNarrowPane` → 自动激活最后打开的 pane
- 两个 pane-wrap 只渲染 `activeNarrowPane` 那个（hideInNarrow 条件）
- `NarrowSwitch` 渲染底部 tab 行，点击切换 activeNarrowPane

---

## 7. 无 pane 时的 Dashboard

```tsx
{openPanes.length === 0 ? (
  <Dashboard onOpenPane={openPane} onSetActiveConv={setActiveConv} />
) : (
  <AnimatePresence mode="popLayout" ...>
    {openPanes.map(...)}
  </AnimatePresence>
)}
```

Dashboard 展示在 main 区域（无 PaneFrame 包裹），是 panes 为空时的欢迎状态。

---

## 8. 挂载的 overlays

| 组件 | 条件 | 来源 |
|---|---|---|
| `CommandPalette` | `cmdkOpen` | overlayStore |
| `NotificationsDrawer` | `notifsOpen` | overlayStore |
| `AskUserModal` | `askOpen` / `pendingAsk` | overlayStore（SSE notifications 推入 pendingAsk） |
| `SettingsModal` | `settingsOpen` | overlayStore |
| `ToastTray` | 始终挂载 | shared/ui/toastStore |

---

## 9. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/app/AppShell.tsx` | 主组件 + renderPaneBody + PaneResizeBetween |
| `frontend/src/app/shell/PaneFrame.tsx` | pane 外壳（标题栏 + 关闭按钮 + crumbs） |
| `frontend/src/app/shell/PaneResize.tsx` | 拖拽条（mousedown→window mousemove/up） |
| `frontend/src/app/shell/NarrowSwitch.tsx` | 窄屏底部 tab 切换器 |
| `frontend/src/app/lib/useKeyboardShortcuts.ts` | 全局键盘快捷键（⌘K 等） |
