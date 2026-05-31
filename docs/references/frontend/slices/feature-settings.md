---
id: DOC-223
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# features/settings — 前端 slice 详细设计

**所属层**：features（对位后端 app/user 的创建用例；account switch 为纯前端 session 操作）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装 SettingsModal 的账户切换和新增账户编排；`AccountRegion` 组件只负责渲染；切换账户触发全量 invalidate 确保数据归属正确；错误由全局 onError 处理。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../service-design-documents/user.md`](../service-design-documents/user.md)
- 实体层 [`user.md`](user.md) / [`session.md`](session.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| switchTo | 更新 sessionStore.currentUserId + 全量 invalidate + success toast |
| addAccount | 创建用户 → 自动 switchTo 新账户 → 清空 name input |

该 slice 仅包含 `useAccountManager`；其他 settings 子区域（API Keys、Model Config、Appearance、Search、System、**Advanced Capabilities**）直接在 UI 组件中消费对应 entity hooks，无需 feature 层编排。**2026-05-31**：新增 `ui/AdvancedCapabilitiesSection.tsx`——运行上限「高级能力」区，读 `entities/settings` 的 `useLimits`/`useUpdateLimits`（↔ `GET/PUT /settings/limits`），分组数字输入 + 恢复默认；组件零业务（只调 hook）；详 [`../adhoc-topic-documents/limits-optimization/02-advanced-settings-ui.md`](../adhoc-topic-documents/limits-optimization/02-advanced-settings-ui.md)。

---

## 2. 类型

```ts
export interface AccountManagerState {
  name: string;
  setName: (v: string) => void;
  switchTo: (id: string) => void;
  addAccount: () => Promise<void>;
  isAdding: boolean;
}
```

---

## 3. 用例 hook（`model/useAccountManager.ts`）

### switchTo — 切换账户

```
switchTo(id):
  1. useSessionStore.getState().setCurrentUser(id)
     → sessionStore.currentUserId 更新 → 所有下游 query 感知新 userId
  2. qc.invalidateQueries()
     → 全量 stale + refetch → 确保各页面数据属于新账户
  3. pushToast({ kind:"success", title:t("account.switchedTo", { id }) })
```

全量 invalidate 是必要的：后端接口按 `userId`（从 session cookie / header 读取）返回数据，切换账户后所有 query 缓存均失效。

### addAccount — 新增账户

```
addAccount():
  1. username = name.trim()
  2. if (!username) return   ← 前端 guard，防止空提交
  3. try:
       created = await createUser.mutateAsync({ username })
       switchTo(created.id)   ← 创建即切换
       setName("")             ← 清空输入框
     catch:
       // 全局 MutationCache onError 处理 toast；此处不重复
```

### 意图 API

```ts
const { name, setName, switchTo, addAccount, isAdding } = useAccountManager();
```

| 成员 | 类型 | 说明 |
|---|---|---|
| `name` | `string` | 新账户名输入值 |
| `setName` | `(v: string) => void` | 受控输入 |
| `switchTo` | `(id: string) => void` | 切换到已有账户 |
| `addAccount` | `() => Promise<void>` | 创建并切换到新账户 |
| `isAdding` | `boolean` | createUser mutation 进行中 |

---

## 4. 端到端数据流

### 切换已有账户

```
用户在 AccountRegion 点击账户条目 → switchTo(user.id)
  → sessionStore.currentUserId = user.id
  → qc.invalidateQueries()   ← 全量失效
  → 所有 query refetch（useConversations / useFunctions / ...）
  → toast("account.switchedTo")
```

### 新增账户

```
用户填写 name → addAccount()
  → createUser.mutateAsync({ username })
      → POST /users  (201)
      → 返 { id, username, ... }
  → switchTo(created.id)
      → sessionStore + invalidateAll + toast
  → setName("")
```

---

## 5. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| 创建用户失败 toast | 全局 `MutationCache onError`；addAccount catch 不重复 toast |
| 全量 invalidate 性能 | 单用户本地 app，query 数量有限；invalidateAll 可接受 |
| 空 username guard | 前端 early return（`if (!username) return`）；后端亦有 required 校验 |

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/settings/model/useAccountManager.ts` | switchTo + addAccount 编排 |
| `frontend/src/features/settings/ui/SettingsModal.tsx` | 设置模态框主体；含 AccountRegion（消费 useAccountManager）|
| `frontend/src/features/settings/ui/SettingsModal.test.tsx` | 单测 |
| `frontend/src/features/settings/ui/ApiKeysSection.tsx` | API Keys 管理区（直消费 entities/apikey）|
| `frontend/src/features/settings/ui/ApiKeysSection.test.tsx` | 单测 |
| `frontend/src/features/settings/ui/ModelDefaultsSection.tsx` | **2026-05-28 model selection redesign**：3 行卡片（dialogue/utility/agent）；每行独立 PUT `/model-configs/{scenario}` body `{apiKeyId, modelId}`；候选 = `useApiKeys().filter(testStatus==="ok")` 平铺成 `{apiKeyId, modelId}` 项并按 apiKeyId 分组 |
| `frontend/src/features/settings/ui/KeyModelPicker.tsx` | 按 apiKeyId 分组的下拉选择器；ModelDefaultsSection + ConvModelOverride + WorkflowEditor InspectorBody 共享|
| `frontend/src/features/settings/ui/AppearanceSection.tsx` | 外观设置（直消费 entities/settings）|
| `frontend/src/features/settings/ui/AppearanceSection.test.tsx` | 单测 |
| `frontend/src/features/settings/ui/SearchSection.tsx` | 搜索 key 设置（直消费 entities/apikey）|
| `frontend/src/features/settings/ui/SearchSection.test.tsx` | 单测 |
| `frontend/src/features/settings/ui/SystemSection.tsx` | 系统信息展示（直消费 entities/session）|
| `frontend/src/features/settings/ui/ProviderGrid.tsx` | Provider 选择 grid（共用 UI）|
| `frontend/src/features/settings/ui/KeyVerifyField.tsx` | Key 输入 + 验证字段（共用 UI）|
| `frontend/src/features/settings/ui/ModelSelect.tsx` | Model 下拉选择（共用 UI）|
| `frontend/src/features/settings/index.ts` | public API |
