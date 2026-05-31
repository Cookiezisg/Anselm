---
id: DOC-231
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# pages/chat — 前端 slice 详细设计

**所属层**：pages（聚合 entities/conversation + entities/apikey + entities/model-config + features/send-message）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：对话详情页。ChatHeader + 滚动消息流 + Composer 三段结构。chatStore（SSE 驱动）是消息树的真实来源；切换对话时 REST 历史 hydrate 一次。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| API key / 模型 gate | 无 key 显示 NoApiKeyGate；有 key 但无 chat scenario 模型显示 NoModelGate |
| REST hydrate | `useConversationMessages(convId)` → `chatStore.hydrateConv()`；每 conv 只执行一次 |
| 404 自愈 | `useConversation(id)` 返回 `CONVERSATION_NOT_FOUND` → onSetActiveConv(null) + invalidate |
| 发送/取消 | `useSendMessageFlow(convId)` → POST messages / DELETE stream |
| auto-scroll | topMsgIds.length 变化时 double-rAF 滚动到底 |
| streaming 检测 | chatStore 扫 messages.values()，有 status=streaming → isStreaming=true |

---

## 2. Props 接口

```ts
interface ChatPageProps {
  activeConv: string | null;
  onSetActiveConv: (id: string | null) => void;
  onClose?: () => void;
  onOpenSettings?: () => void;
}
```

AppShell 从 paneStore 提取 `activeConv`/`setActiveConv` 后传入。

---

## 3. UI 子组件

| 组件 | 文件 | 职责 |
|---|---|---|
| `ChatHeader` | `ui/ChatHeader.tsx` | 对话标题 + pane 关闭按钮 |
| `MessageView` | `ui/MessageView.tsx` | 单条消息递归渲染（blocks 树） |
| `Composer` | `features/send-message` | 输入框 + 附件 + 发送/取消 |
| `NoApiKeyGate` | `ui/NoApiKeyGate.tsx` | 无 API key 引导跳设置 |
| `NoModelGate` | `ui/NoModelGate.tsx` | 无 chat 模型引导跳设置 |
| `EmptyConvPlaceholder` | 内联 | activeConv=null 时占位卡片 |
| `EmptyConvHero` | 内联 | 新建对话但还没发消息时居中提示 |

---

## 4. 数据流

```
REST:
  useConversation(id)          → conv 元数据（ChatHeader + 404 自愈）
  useConversationMessages(id)  → historyMessages → chatStore.hydrateConv()

SSE (来自 app/sse SSEProvider):
  message_start/stop           → chatStore.onMessageStart/Stop
  block_start/delta/stop       → chatStore.onBlock*（rAF batch）

发送:
  useSendMessageFlow(convId).submit(payload)
  → POST /conversations/{id}/messages
  → SSE 驱动 UI 渲染（无 REST 轮询）

取消:
  cancelStream()
  → DELETE /conversations/{id}/stream
```

---

## 5. gate 逻辑顺序

1. `keysLoading` 为 false 且 `apiKeys.length === 0` → `<NoApiKeyGate />`
2. `cfgLoading` 为 false 且没有 scenario=chat 的 modelConfig → `<NoModelGate />`
3. `activeConv === null` → `<EmptyConvPlaceholder />`
4. 正常渲染消息流

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/pages/chat/ChatPage.tsx` | 主组件 |
| `frontend/src/pages/chat/ui/ChatHeader.tsx` | 对话头部 |
| `frontend/src/pages/chat/ui/MessageView.tsx` | 消息/块树递归渲染 |
| `frontend/src/pages/chat/ui/NoApiKeyGate.tsx` | 无 key 引导 |
| `frontend/src/pages/chat/ui/NoModelGate.tsx` | 无模型引导 |
| `frontend/src/pages/chat/index.ts` | public API export |
