---
id: DOC-232
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# pages/dashboard — 前端 slice 详细设计

**所属层**：pages（聚合 entities/conversation + entities/user + entities/flowrun + shared/api/httpClient）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：Gemini-style 欢迎页。openPanes 为空时由 AppShell 展示。居中 greeting + pill 输入框 + context strip。Enter 提交第一条消息后创建对话并切换到 chat pane。

---

## 1. Props 接口

```ts
interface DashboardProps {
  onOpenPane: (pane: string, id?: string) => void;
  onSetActiveConv: (id: string | null) => void;
}
```

AppShell 直接传 paneStore 的 `openPane` / `setActiveConv`。

---

## 2. 子组件

| 组件 | 文件 | 职责 |
|---|---|---|
| `WelcomeInput` | `ui/WelcomeInput.tsx` | pill 风格输入框；onSubmit + isSubmitting |
| `ContextStrip` | 内联 | 智能上下文条（等待审批 / 失败 / 运行中 / 最近对话） |

---

## 3. Greeting 生成

`useGreeting({ hasRecentConv, displayName })` — 根据是否有 24h 内对话以及用户名，选择不同问候语变体（早/午/晚 + 首次 vs 欢迎回来）。

---

## 4. ContextStrip 四种状态

| kind | 触发条件 | 显示内容 |
|---|---|---|
| `waiting` | 有 flowrun 等待人工审批 | warn 点 + 等待 N 个 + 跳 execute |
| `failed` | 最近有 flowrun 失败 | error 点 + 失败 N 个 + 跳 execute |
| `running` | 有 flowrun 正在运行 | info 点 + 运行 N 个 + RelTime |
| `recent` | 最近 8h 有对话活动 | 灰点 + 对话标题 + RelTime |

`useContextStrip()`（`lib/useContextStrip.ts`）从 `useFlowRuns()` + `useConversations()` 聚合得出优先级最高的一种状态。

---

## 5. 提交流程

```
用户在 WelcomeInput 输入 → onSubmit(text)
  → useCreateConversation().mutateAsync({})   创建新对话
  → setActiveConv(created.id) + openPane("chat")   先切换到 chat
  → POST /conversations/{id}/messages { content: text }   发送第一条消息
  → 失败 → pushToast(error)
```

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/pages/dashboard/Dashboard.tsx` | 主组件 + ContextStrip |
| `frontend/src/pages/dashboard/ui/WelcomeInput.tsx` | pill 输入框 |
| `frontend/src/pages/dashboard/lib/useGreeting.ts` | 问候语生成 hook |
| `frontend/src/pages/dashboard/lib/useContextStrip.ts` | 上下文条数据 hook |
| `frontend/src/pages/dashboard/index.ts` | public API export |
