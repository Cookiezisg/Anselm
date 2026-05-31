---
id: DOC-221
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# features/onboarding — 前端 slice 详细设计

**所属层**：features（对位后端 app/user + app/apikey + app/model-config 多 service 编排）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：封装首次启动向导的全部业务编排（6 步 × 多 mutation）；`Onboarding.tsx` 只负责渲染；hook 向外暴露完整状态 + 动作接口 `OnboardingFlowState`。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 [`../references/backend/domains/user.md`](../references/backend/domains/user.md)
- 后端 [`../references/backend/domains/apikey.md`](../references/backend/domains/apikey.md)
- 实体层 [`user.md`](user.md) / [`apikey.md`](apikey.md) / [`model-config.md`](model-config.md) / [`session.md`](session.md) / [`settings.md`](settings.md)

---

## 1. 职责边界

| 用例 | 说明 |
|---|---|
| 步骤导航 | 6 步线性推进 / 回退（`next` / `back`）；`stepKey` 驱动组件渲染分支 |
| ensureUser | workspace 步骤确认时：幂等创建用户 → 写 sessionStore.currentUserId |
| API Key 创建 / 替换 | 输入 key → createKey（幂等，key 变则先 delete 旧 key 再创建新 key）|
| Key 验证 | testKey → 取 modelsFound 列表；验证失败写 verifyError |
| Model 配置 | 验证成功 + 用户选模型 → **顺序写 3 行 model_configs**：dialogue / utility / agent 各一次 PUT（2026-05-28 model selection redesign）；3 行都引用同一 apiKeyId + 同一 modelId（用户后续在 Settings 调整）|
| Search key 配置 | 可选步骤：createKey(searchProvider) |
| finish | setStatus("ready") + invalidateAll + success toast + 调 onFinish 意图 |
| 语言同步 | `prefs.lang` 变化 → `i18n.changeLanguage`（向导内切语言先于 App mount）|

---

## 2. 步骤定义

```ts
const STEP_KEYS = ["welcome", "workspace", "appearance", "model", "search", "done"] as const;
type StepKey = "welcome" | "workspace" | "appearance" | "model" | "search" | "done";
```

| step | stepKey | 关键操作 |
|---|---|---|
| 0 | welcome | 无副作用；直接 advance |
| 1 | workspace | `ensureUser()` → createUser + setCurrentUser |
| 2 | appearance | 无 API；读写 settingsStore（accent / lang）|
| 3 | model | 若 verified && modelId → `upsertModelConfig` |
| 4 | search | 若 searchProvider && searchKey → `createKey` |
| 5 | done | `finish()` → setStatus("ready") + invalidateAll + toast |

---

## 3. 用例 hook（`model/useOnboardingFlow.ts`）

### 编排步骤（verify 专项）

```
verify():
  1. setBusy(true) via run()
  2. 若 createdKeyId 存在 && key 文本已变 → deleteKey(旧id)，keyId=null
  3. 若 keyId 为 null → createKey(provider, apiKey|"ollama-no-key") → 记录 createdKeyId
  4. testKey(keyId) → modelsFound[]
     成功：setModels / setModelId / setVerified(true) / pushToast(success)
     失败：setVerified(false) / setVerifyError(t("model.verifyFail"))
  5. setBusy(false) via finally
```

### 编排步骤（handleNext 路由表）

```
next(onFinish?):
  "workspace" → run(ensureUser → advance)
  "model"     → run(if verified && modelId:
                       upsertModelConfig("dialogue", {apiKeyId, modelId}) ;
                       upsertModelConfig("utility",  {apiKeyId, modelId}) ;
                       upsertModelConfig("agent",    {apiKeyId, modelId}) ;
                       3 个全部 200 才 → advance)
  "search"    → run(if searchProvider && searchKey: createKey → advance)
  "done"      → finish(onFinish)
  default     → advance()  (welcome / appearance)
```

### ensureUser（幂等）

```
ensureUser():
  if (createdUserId) return   ← 防止 Back→Next 重复创建
  createUser({ username, displayName, avatarColor })
    → setCreatedUserId(user.id)
    → useSessionStore.setCurrentUser(user.id)
```

### pickProvider（切换 provider 清理）

```
pickProvider(n):
  if (createdKeyId) deleteKey(createdKeyId)   ← best-effort 清理孤儿 key
  setProvider(n) + 清空 apiKey / keyId / verified / models / modelId / verifyError
```

### finish

```
finish(onFinish?):
  useSessionStore.setStatus("ready")
  qc.invalidateQueries()   ← 全量 refetch，确保首页数据就绪
  pushToast({ kind:"success", title:t("toast.welcome"), desc:name })
  onFinish?.()             ← 意图回传：组件关闭向导、跳转主页
```

### 意图 API（`OnboardingFlowState`）

```ts
export interface OnboardingFlowState {
  step: number; stepKey: StepKey; busy: boolean;
  next: (onFinish?: () => void) => void;
  back: () => void;
  canNext: () => boolean;
  advance: () => void;                       // 跳过按钮直接推进，不经 run()

  // workspace
  name: string; setName: (v: string) => void; createdUserId: string | null;

  // model
  provider: string; pickProvider: (n: string) => void;
  apiKey: string; onKeyChange: (v: string) => void;
  verify: () => void; verifying: boolean; verified: boolean; verifyError: string;
  models: string[]; modelId: string; setModelId: (v: string) => void;
  llmProviders: ProviderEntry[];

  // search
  searchProvider: string; setSearchProvider: (v: string) => void;
  searchKey: string; setSearchKey: (v: string) => void;
  searchProviders: ProviderEntry[];

  // display helpers
  providerDisplay: (n: string) => string;
  jdesc: (key: string, fallback: string) => string;  // 已完成步骤的已选值摘要

  // finish
  finish: (onFinish?: () => void) => void;
}
```

---

## 4. 端到端数据流

```
App 检测 sessionStore.status === "onboarding"
  → 渲染 <Onboarding />
      → useOnboardingFlow()
          → useProviders()  (GET /model-configs/providers)

用户填 workspace → next()
  → ensureUser()
      → POST /users → user.id
      → sessionStore.setCurrentUser(id)
  → step 推进

用户选 provider / 输 key → verify()
  → POST /api-keys (createKey)
  → POST /api-keys/{id}:test (testKey)
  → 成功：setVerified + models list

用户选模型 → next()（model step）
  → 顺序 3 次 PUT /model-configs/{scenario}  body={apiKeyId, modelId}
       scenario=dialogue → 200
       scenario=utility  → 200
       scenario=agent    → 200
     任一失败 → abort，不 advance；用户重试

用户（可选）输 searchKey → next()（search step）
  → POST /api-keys (createKey, searchProvider)

用户 done → next(onFinish)
  → finish():
      sessionStore.setStatus("ready")
      qc.invalidateQueries()  ← 触发所有 stale query refetch
      toast
      onFinish() → App 路由到主界面
```

---

## 5. 横切关注点

| 关注点 | 处理方式 |
|---|---|
| mutation 错误 toast | 全局 `MutationCache onError`；`run()` 的 catch 仅清 busy，不重复 toast |
| verify 内部错误 | `try/catch` 在 `verify()` 内部；写 `verifyError` 字符串显示在 UI |
| skip 按钮 | 调 `advance()` 直接推进，绕过 `run()` 避免 busy 闪烁 |
| 孤儿 key | `pickProvider` 时 best-effort deleteKey（不 await，失败不影响流程）|
| 语言切换时序 | `useEffect([prefs.lang])` → `i18n.changeLanguage`；早于 App.useEffect |

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/features/onboarding/model/useOnboardingFlow.ts` | 核心编排 hook（6 步 × 多 mutation）|
| `frontend/src/features/onboarding/model/useOnboardingFlow.test.ts` | 单测 |
| `frontend/src/features/onboarding/ui/Onboarding.tsx` | 向导 UI；消费 OnboardingFlowState |
| `frontend/src/features/onboarding/ui/Onboarding.test.tsx` | UI 单测 |
| `frontend/src/features/onboarding/index.ts` | public API（hook + 类型 + 组件）|
