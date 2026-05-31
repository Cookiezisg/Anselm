---
id: DOC-243
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# widgets/notifications-drawer — 前端 slice 详细设计

**所属层**：widgets（聚合 shared/api/httpClient + shared/ui/toastStore + app/model/overlayStore）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：右侧滑入抽屉。两个 tab：「待办」（显示 pending AskUser 问题并提交答案）和「通知」（REST snapshot 列表 + 点击跳转对应 pane）。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| 抽屉动画 | 右侧滑入（x: 360→0），scrim 淡入；AnimatePresence 控制挂载 |
| 待办 tab | 展示 pendingAsk（question + options），选中后 POST `:resolve`，清除 pendingAsk |
| 通知 tab | `useNotificationsSnapshot(50)` REST 快照；type→icon/pane 映射；点击跳转 |
| 未读清除 | 关闭或点"全部已读"时调 `clearUnread()` |

---

## 2. Props 接口

```ts
interface NotificationsDrawerProps {
  open: boolean;
  onClose: () => void;
  onOpenPane: (pane: string) => void;
  onOpenEntity: (pane: string, id: string) => void;
  onSetActiveConv: (id: string | null) => void;
  pendingAsk?: PendingAsk | null;
  onSetPendingAsk: (ask: PendingAsk | null) => void;
  unread?: number;
  clearUnread?: () => void;
}

interface PendingAsk {          // 来自 app/model/overlayStore
  id: string;
  conversationId: string;
  toolCallId: string;
  question?: string;
  context?: string;
  options?: Array<{ id?: string; value?: string; text?: string; label?: string; sub?: string }>;
}
```

---

## 3. 子组件

| 组件 | 职责 |
|---|---|
| `TodoTab` | 渲染 pendingAsk 问题 + 选项列表；POST `:resolve` 提交答案 |
| `NotifsTab` | 渲染 REST 快照；每条 notif 点击按 TYPE_TO_PANE 路由 |

---

## 4. 通知类型路由表

| type | 跳转 pane |
|---|---|
| conversation | chat（同时 setActiveConv） |
| function / handler / workflow | forge（openEntity） |
| flowrun | execute（openEntity） |
| mcp_server | mcp |
| skill | skills |
| memory | memory |
| todo | execute |
| ask | chat |

---

## 5. 待办提交流程

```
用户选中 option → selected state
→ 点击提交
→ POST /conversations/{conversationId}/pending-questions/{toolCallId}:resolve
    body: { answer: selected }
→ 成功: pushToast(success) + onSetPendingAsk(null)
→ 失败: pushToast(error)
```

---

## 6. 数据流

```
useNotificationsSnapshot(50)   (widgets/notifications-drawer/useNotificationsSnapshot)
→ GET /notifications?limit=50  初始快照

pendingAsk                     (来自 app/model/overlayStore，SSE notifications hook 推入)
→ 展示在待办 tab

unread / clearUnread           (来自 SSEProvider → AppShell props 链)
→ 头部 badge + "全部已读" 按钮
```

---

## 7. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/widgets/notifications-drawer/NotificationsDrawer.tsx` | 主组件 + TodoTab + NotifsTab |
| `frontend/src/widgets/notifications-drawer/useNotificationsSnapshot.ts` | GET /notifications 快照 hook |
| `frontend/src/widgets/notifications-drawer/index.ts` | public API export |
