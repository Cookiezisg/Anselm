---
id: DOC-217
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# features/ask-user — 前端 slice 详细设计

**所属层**：features（对位后端 app/conversation 的 pending-questions `:resolve` action）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装 AskUser 应答提交编排；`AskUserModal` 只负责渲染；`pending` 和 `onClose` 由组件从 overlay store 读取后传入；feature 只持有提交逻辑，不感知 overlay 状态。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../references/backend/domains/conversation.md`](../references/backend/domains/conversation.md)
- 实体层 [`conversation.md`](conversation.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| submit | 校验 answer 非空 → POST `:resolve` → success toast → onClose |
| 提交失败 toast | 直接调 `apiFetch`（不经 useMutation）→ feature 独占错误 toast |
| submitting 状态 | 局部 useState，防止重复提交 |

overlay store（`AskUserModal` 持有的 pending 问题队列）由组件层管理；feature 只接受 `pending` 和 `onClose` 作为入参，不依赖任何 overlay store。

---

## 2. 类型

```ts
interface PendingAsk {
  id: string;
  conversationId: string;
  toolCallId: string;
  question?: string;
  context?: string;
  options?: Array<{
    id?: string; value?: string;
    text?: string; label?: string; sub?: string;
  }>;
}

interface UseAskUserAnswerOptions {
  pending: PendingAsk | null;
  onClose: () => void;
}
```

`options` 字段兼容后端可能返回的多种键名（`id/value/text/label/sub`），模态框渲染时取第一个非空值。

---

## 3. 用例 hook（`model/useAskUserAnswer.ts`）

### 编排步骤

```
useAskUserAnswer({ pending, onClose })
  [submitting, setSubmitting] = useState(false)

  submit(answer):
    1. if (!answer) return       ← 空答案 guard，不发请求
    2. setSubmitting(true)
    3. try:
         await apiFetch(
           `/conversations/${pending.conversationId}/pending-questions/${pending.toolCallId}:resolve`,
           { method:"POST", body:{ answer } }
         )
         pushToast({ kind:"success", title:t("ask.submitSuccess") })
         onClose()               ← 意图回传：组件关闭模态框
       catch(err):
         // apiFetch 不经 useMutation，全局 onError 不触发
         // feature 独占 error toast
         pushToast({ kind:"error", title:t("ask.submitFail"), desc:err.message })
    4. finally: setSubmitting(false)
```

### 为什么不用 useMutation

`:resolve` 是一次性操作，且 `pending` 对象（含 `toolCallId`）在 submit 时才确定；直接 `apiFetch` 更简洁，不需要缓存/retry 语义。代价是全局 `MutationCache onError` 不触发，feature 自行 catch + toast。

### 意图 API

```ts
const { submitting, submit } = useAskUserAnswer({ pending, onClose });
```

| 成员 | 类型 | 说明 |
|---|---|---|
| `submit` | `(answer: string) => Promise<void>` | 提交答案；空值直接 return |
| `submitting` | `boolean` | 请求进行中（禁止重复提交）|

---

## 4. 端到端数据流

```
后端 chat 流遇到 ask_user tool → push notifications SSE "ask_user" 事件
  → app/SSEProvider → overlay store.setPending(pendingAsk)
  → AskUserModal 渲染（pending 非空时显示）

用户填写答案 / 选择选项 → AskUserModal.onSubmit(answer)
  → useAskUserAnswer.submit(answer)
      → POST /conversations/{convId}/pending-questions/{toolCallId}:resolve
          body: { answer }
          → 204  (成功解除 pending)
          → 后端 chat 流继续执行
      → toast("ask.submitSuccess")
      → onClose() → overlay store.clearPending() → 模态框消失
      → 失败: error toast（feature 独占）
```

---

## 5. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| 错误 toast | feature 独占（apiFetch 不经 MutationCache）；catch 中直接 pushToast |
| 空答案 | 前端 early return；不发请求 |
| onClose 意图 | 组件传入；feature 不直接操作 overlay store |
| pending 为 null | submit 调用前组件已确保 pending 非 null（`pending!.conversationId`）|

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/ask-user/model/useAskUserAnswer.ts` | 提交编排；直接 apiFetch；独占错误 toast |
| `frontend/src/features/ask-user/ui/AskUserModal.tsx` | 应答模态框 UI；消费 useAskUserAnswer |
| `frontend/src/features/ask-user/ui/AskUserModal.test.tsx` | 单测 |
| `frontend/src/features/ask-user/index.ts` | public API（hook + 组件）|
