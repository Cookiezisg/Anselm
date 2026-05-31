---
id: DOC-219
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# features/forge-iterate — 前端 slice 详细设计

**所属层**：features（对位后端 app/function + app/handler + app/workflow 的 `:iterate` action）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装 trinity（function / handler / workflow）detail header 的 AI 编辑触发编排；`conversationId` 取值、warn toast（空响应）由 feature 处理；导航返回意图由组件负责。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../references/backend/domains/function.md`](../references/backend/domains/function.md)
- N5：`:iterate` 是标准 action，返 `{conversationId}` (201)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| iterate 调用 | POST `/{kind}s/{id}:iterate` → 返 `{conversationId}` |
| conversationId 取值 | 兼容 `res.conversationId` 或 `res.id` 两种后端响应字段 |
| 空响应 warn | 服务返回 200 但无 conversationId → warn toast（全局 onError 感知不到）|
| 导航意图回传 | `submit()` 返回 `string | null`；组件拿到 cid 后自行执行 setActiveConv + openPane |

该 slice **不**执行路由跳转和 pane 操作；这些由消费组件（AskAiTrigger）负责。

---

## 2. 类型

```ts
interface IterateParams {
  kind: string;   // "function" | "handler" | "workflow"
  id: string;
  prompt: string;
}

// useIterateForge: 底层 mutation（可单独使用）
// useForgeIterate: 包含 warn toast 和 conversationId 提取的上层 hook
```

---

## 3. 用例 hook（`model/useForgeIterate.ts`）

### 双层结构

```
useIterateForge()       ← 底层：纯 useMutation，无 toast 逻辑
  mutationFn: ({ kind, id, prompt }) =>
    apiFetch(`/${kind}s/${id}:iterate`, { method:"POST", body:{ prompt } })

useForgeIterate()       ← 上层：提取 conversationId + warn toast
  iterate = useIterateForge()
  submit(kind, id, prompt) → Promise<string | null>:
    try:
      res = await iterate.mutateAsync({ kind, id, prompt })
      cid = res.conversationId || res.id
      if (!cid) → pushToast({ kind:"warn", title, desc }) → return null
      return cid
    catch:
      // 全局 onError 处理 ApiError toast；此处不重复
      return null
```

### 意图 API

```ts
const { submit, isPending } = useForgeIterate();

// 返回 conversationId（成功）或 null（失败/空响应）
const cid = await submit("function", fnId, prompt);
if (cid) {
  setActiveConv(cid);   // 组件执行导航
  openPane("chat");
}
```

| 成员 | 类型 | 说明 |
|---|---|---|
| `submit` | `(kind, id, prompt) => Promise<string \| null>` | 触发 iterate；返导航所需的 conversationId |
| `isPending` | `boolean` | iterate mutation 进行中 |

---

## 4. 端到端数据流

```
用户在 FunctionDetail / HandlerDetail / WorkflowDetail 输入 prompt → AskAiTrigger.onSubmit
  → useForgeIterate.submit(kind, id, prompt)
      → useIterateForge.mutateAsync({ kind, id, prompt })
          → POST /{kind}s/{id}:iterate  (201)
          → 后端 chatapp 创建对话 + 注入系统 prompt + 启动 agent
          → 返 { conversationId }
      → 提取 cid = res.conversationId || res.id
      → 若空：warn toast（"iterate 返回无 conversationId"）→ return null
      → 返 cid
  → 组件：setActiveConv(cid) + openPane("chat")
      → ChatPane 渲染，SSE eventlog 实时更新
```

### 失败路径

```
iterate 网络/业务错误:
  → useMutation onError → 全局 MutationCache onError → errorMap → toast
  → submit catch → return null
  → 组件不执行导航（cid === null）
```

---

## 5. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| API 错误 toast | 全局 `MutationCache onError`；feature catch 不重复 toast |
| 空 conversationId warn | feature 独占 warn toast（非 ApiError，全局不感知）|
| 导航 | 返回意图（cid string），组件执行；feature 不持有 store 引用 |

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/forge-iterate/model/useForgeIterate.ts` | 双层 hook：useIterateForge（底层）+ useForgeIterate（上层）|
| `frontend/src/features/forge-iterate/index.ts` | public API（useForgeIterate + useIterateForge）|
