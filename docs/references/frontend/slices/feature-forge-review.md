---
id: DOC-220
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# features/forge-review — 前端 slice 详细设计

**所属层**：features（对位后端 app/function + app/handler + app/workflow 的 accept / reject / revert action）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装 trinity detail header 的三类审核动作（accept / reject / revert）和 ForgeList 的批量删除编排；所有 entity mutation 无条件调用，按 `kind` 路由；UI 组件只负责渲染。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../references/backend/domains/function.md`](../references/backend/domains/function.md)
- 实体层 [`function.md`](function.md) / [`handler.md`](handler.md) / [`workflow.md`](workflow.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| accept | 接受 pending → PATCH `/{kind}s/{id}:accept` → success toast |
| reject | 拒绝 pending → PATCH `/{kind}s/{id}:reject` → warn toast |
| revert（function 专属）| 回退 live → PATCH `/functions/{id}:revert` → warn toast |
| batchDelete | ForgeList 多选 → confirm → 逐 kind DELETE → clearSel |

`useForgeReview` 和 `useForgeBatchDelete` 是同一 slice 的两个独立 hook，分别服务 detail header 和列表页。

---

## 2. 类型

```ts
type ForgeKind = "function" | "handler" | "workflow";

interface ReviewActions {
  accept: () => void;
  reject: () => void;
  revert?: () => void;   // 仅 function 有
}

interface ForgeItem {
  id: string;
  kind: ForgeKind;
  name?: string;
}
```

---

## 3. 用例 hook — useForgeReview（`model/useForgeReview.ts`）

### 编排策略：hooks 无条件调用 + kind 路由

所有 7 个 entity mutation hook 在顶层无条件调用（满足 React Hooks 规则）；`kind` 决定返回哪一组回调：

```
useForgeReview(kind, id, name?) → ReviewActions

  // 无条件声明全部 mutation
  acceptFn / rejectFn / revertFn  (entities/function)
  acceptHd / rejectHd             (entities/handler)
  acceptWf / rejectWf             (entities/workflow)

  kind === "function" →
    accept:  acceptFn.mutate(id, { onSuccess: toast("success", "Accepted", name) })
    reject:  rejectFn.mutate(id, { onSuccess: toast("warn", "Reverted pending", name) })
    revert:  revertFn.mutate(id, { onSuccess: toast("warn", "Reverted pending", name) })

  kind === "handler" →
    accept:  acceptHd.mutate(id, { onSuccess: toast("success", "Accepted") })
    reject:  rejectHd.mutate(id, { onSuccess: toast("warn", "Reverted pending") })

  kind === "workflow" →
    accept:  acceptWf.mutate(id, { onSuccess: toast("success", "Accepted") })
    reject:  rejectWf.mutate(id, { onSuccess: toast("warn", "Reverted pending") })
```

`revert` 仅在 function 返回；handler / workflow 的 `ReviewActions.revert` 为 `undefined`。

### 意图 API

```ts
const { accept, reject, revert } = useForgeReview("function", fn.id, fn.name);
```

---

## 4. 用例 hook — useForgeBatchDelete（`model/useForgeBatchDelete.ts`）

### 编排步骤

```
batchDelete(items, clearSel):
  1. confirm(t("forge:list.batch.deleteConfirm", { count }))
     → 用户取消：return
  2. items.forEach(f => {
       mutation = f.kind==="function" ? deleteFn
                : f.kind==="handler"  ? deleteHd
                :                       deleteWf
       mutation.mutate(f.id)
     })
  3. clearSel()
```

批量删除不串行等待（fire-and-forget 逐项 mutate）；删除成功/失败均由全局 `MutationCache onError` 和各 entity hook 的 invalidate 处理。

### 意图 API

```ts
const { batchDelete } = useForgeBatchDelete();
// clearSel 由 ForgeList 提供，执行选择集清空
batchDelete(selectedItems, clearSel);
```

---

## 5. 端到端数据流

### accept / reject / revert

```
用户点 detail header 按钮 → FunctionDetail / HandlerDetail / WorkflowDetail
  → useForgeReview(kind, id, name)
      → {accept}|{reject}|{revert}.mutate(id)
          → PATCH /{kind}s/{id}:accept|:reject|:revert
          → onSuccess: pushToast
          → 失败: 全局 MutationCache onError → errorMap toast
      → entities 层 invalidate：
          functions()|handlers()|workflows() + 对应 detail query
```

### batchDelete

```
用户多选 + 点批量删除 → ForgeList
  → useForgeBatchDelete.batchDelete(items, clearSel)
      → confirm()
      → 逐项：DELETE /{kind}s/{id}
          → 全局 onError 处理失败 toast
          → 成功：entity invalidate → 列表刷新
      → clearSel()
```

---

## 6. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| 成功 toast | feature 在 `onSuccess` 回调中调 `pushToast`（detail 组件不感知）|
| 失败 toast | 全局 `MutationCache onError`；feature 不重复 toast |
| hooks 规则 | 所有 mutation 无条件声明；用 `if(kind)` 路由返回值，不用条件 hook |

---

## 7. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/forge-review/model/useForgeReview.ts` | accept / reject / revert 编排；7 mutation + kind 路由 |
| `frontend/src/features/forge-review/model/useForgeBatchDelete.ts` | 批量删除编排；confirm + 逐项 mutate + clearSel |
| `frontend/src/features/forge-review/index.ts` | public API |
