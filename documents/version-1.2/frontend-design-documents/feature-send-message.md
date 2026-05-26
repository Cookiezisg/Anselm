# features/send-message — 前端 slice 详细设计

**所属层**：features（对位后端 app/chat service 的发送/取消用例）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装单次对话的消息发送、流式取消、CONVERSATION_NOT_FOUND 自愈三个用例的编排逻辑；ChatPane 只负责渲染，不含业务决策。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../service-design-documents/conversation.md`](../service-design-documents/conversation.md)
- 实体层 [`conversation.md`](conversation.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| 组装发送 body | `SendPayload`（content + attachments + mentions）→ 转换为后端 `SendMessageBody` wire 格式 |
| 发送消息 | `useSendMessage(convId).mutate(body)` → POST `/conversations/{convId}/messages` |
| CONVERSATION_NOT_FOUND 自愈 | 捕捉该错误码 → invalidate conversations + 触发 `onConvGone` 意图 |
| 取消流 | `useCancelStream(convId).mutate()` → DELETE `/conversations/{convId}/stream` |
| 取消失败 toast | cancel 标记 `suppressGlobal=true`，feature 独占处理 warn toast |

该 slice **不**管理对话切换、pane 状态或路由导航；这些意图通过 `onConvGone` 回调向上回传，由 ChatPane 持有的 pane store 执行。

---

## 2. 类型

```ts
// 前端 feature 内部组装形状（超集，字段比 SendMessageBody 多）
interface SendPayload {
  content: string;
  attachments?: Array<{ name: string; size: number }>;
  mentions?: Array<{ type: string; id: string }>;
}

// 与后端 wire 一致的发送体（entities/conversation 导出）
interface SendMessageBody {
  content: string;
  attachmentIds?: string[];
}

// feature hook 选项
interface SendMessageFlowOptions {
  onConvGone?: () => void;   // 后端返回 CONVERSATION_NOT_FOUND 时触发
}
```

---

## 3. 用例 hook（`model/useSendMessageFlow.ts`）

### 编排步骤

```
useSendMessageFlow(convId, { onConvGone })
  ├─ send  = useSendMessage(convId)        // entities/conversation
  ├─ cancel = useCancelStream(convId)      // entities/conversation
  │
  ├─ submit(payload):
  │    1. 组装 body：content + attachments rename（name→fileName, size→sizeBytes）
  │                        + mentions passthrough
  │    2. send.mutate(body, { onError })
  │         onError: if err.code === "CONVERSATION_NOT_FOUND"
  │                      qc.invalidateQueries(qk.conversations())
  │                      onConvGone?.()
  │                  else: 全局 MutationCache onError 处理（不重复 toast）
  │
  └─ cancelStream():
       cancel.mutate(undefined, {
         onError: pushToast({ kind:"warn", title:t("toast.cancelFailTitle"), desc })
       })
```

### 意图 API

```ts
const { submit, cancelStream, isPending } = useSendMessageFlow(convId, options);
```

| 成员 | 类型 | 说明 |
|---|---|---|
| `submit` | `(payload: SendPayload) => void` | 组装并发送消息 |
| `cancelStream` | `() => void` | 取消当前流（suppressGlobal，错误在此 toast） |
| `isPending` | `boolean` | 发送 mutation 进行中（禁止重复提交） |

---

## 4. 端到端数据流

```
用户输入 → Composer.onSubmit(payload)
  → useSendMessageFlow.submit(payload)
      → 组装 body（attachments/mentions 字段转换）
      → useSendMessage.mutate(body)
          → POST /conversations/{convId}/messages  (202)
          → 后端启动 chat 流
          → SSE eventlog 推 message.start / block.* / message.stop
          → entities/conversation chatStore 更新
          → React 组件通过 selectTopMessageIds / selectBlock 响应
      → onError: CONVERSATION_NOT_FOUND
          → invalidate conversations → 侧边栏刷新
          → onConvGone() → ChatPane pane store 执行自愈（切到其他 conv 或 null）
```

### 取消流

```
用户点取消 → Composer.onCancel()
  → useSendMessageFlow.cancelStream()
      → useCancelStream.mutate()
          → DELETE /conversations/{convId}/stream  (204)
          → 后端 cancel 信号 → SSE 推 message.stop(cancelled)
      → onError → warn toast（suppressGlobal，不经全局 onError）
```

---

## 5. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| 发送错误 toast | 全局 `MutationCache onError` via `errorMap`；feature 不重复 toast |
| 取消失败 toast | `suppressGlobal=true`；feature 独占 `pushToast({ kind:"warn" })` |
| CONVERSATION_NOT_FOUND | feature 独占：invalidate + `onConvGone()` 意图向上传 |
| convId 为 null | `useSendMessage(null)` / `useCancelStream(null)` 不发请求（entities 层 guard） |

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/send-message/model/useSendMessageFlow.ts` | 核心编排 hook：组装 body + 自愈 + cancelStream |
| `frontend/src/features/send-message/ui/Composer.tsx` | 输入框 UI；消费 useSendMessageFlow |
| `frontend/src/features/send-message/ui/Composer.test.tsx` | 单测 |
| `frontend/src/features/send-message/index.ts` | public API（useSendMessageFlow + Composer） |
