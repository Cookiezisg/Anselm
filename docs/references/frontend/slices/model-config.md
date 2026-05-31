---
id: DOC-230
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/model-config — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/model）
**状态**：✅ 已实现；2026-05-28 model selection redesign：3 scenarios + apiKeyId
**职责**：管理 ModelConfig（scenario → apiKeyId + modelId 映射）的查询 + upsert，以及辅助的 providers / scenarios 白名单查询。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/model.md`
- spec `docs/superpowers/specs/2026-05-28-model-selection-redesign-design.md`

---

## 1. 职责边界

- ModelConfig CRUD（upsert，按 scenario 为键；3 scenarios：`dialogue` / `utility` / `agent`）
- providers 静态白名单查询（GET /providers）
- scenarios 权威列表查询（GET /scenarios）

conversation 级 modelOverride 由 entities/conversation PATCH 处理（共享 ModelRef 类型 + KeyModelPicker 共享组件）。
workflow node 级 modelOverride 由 entities/workflow 维护（NodeSpec.modelOverride；2026-05-28 redesign 加，详 workflow.md）。

---

## 2. 类型（`model/types.ts`）

```ts
type Scenario = "dialogue" | "utility" | "agent";   // 2026-05-28 redesign：封闭 3 值

interface ModelConfig {
  id: string;     // mc_<16hex>
  scenario: Scenario;
  apiKeyId: string;     // aki_<16hex>（2026-05-28 redesign：原 provider 字段已删）
  modelId: string;
  createdAt; updatedAt;
}

interface Provider {
  name; displayName; category;
  defaultBaseUrl?; baseUrlRequired: boolean;
}

interface ModelRef { apiKeyId: string; modelId: string }  // 共享值类型，conv.modelOverride / node.modelOverride 同形状
interface UpsertModelConfigBody { apiKeyId: string; modelId: string }
```

`Scenario` 字面量联合（不再是结构 `{ name }`）；后端 `GET /scenarios` 返 `[{name:"dialogue"},{name:"utility"},{name:"agent"}]`，前端 hook 取 `name`。

---

## 3. API hooks（`api/model-config.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useProviders()` | GET `/providers` | provider 静态白名单 |
| `useScenarios()` | GET `/scenarios` | scenario 权威列表（3 项）；staleTime 5min |
| `useModelConfigs()` | GET `/model-configs` | 全量 model config 列表；select pickList |
| `useUpsertModelConfig()` | PUT `/model-configs/{scenario}` body `{apiKeyId, modelId}` | upsert（无论新建/更新都返 200）；invalidate modelConfigs |

`useScenarios` 用 `staleTime: 5 * 60 * 1000`——scenario 列表基本不变，减少不必要请求。

---

## 4. 端到端数据流

```
用户在 SettingsModal > 模型默认 section 选择 scenario + apiKey + model
  → useUpsertModelConfig().mutate({scenario, apiKeyId, modelId})
      → PUT /model-configs/{scenario}  {apiKeyId, modelId}
      → 后端 F1 校验 keys.ResolveCredentialsByID（apiKeyId 存在 + 跨用户隔离）
        失败 → 404 API_KEY_NOT_FOUND
      → 后端 upsert
      → onSuccess: invalidate modelConfigs
      → useModelConfigs() 重取 → ModelDefaultsSection 刷新显示
```

**Onboarding 3 行写入**（`features/onboarding`）：用户加完 1 把 key + 验证 + 选 modelId → 拿到 `apiKeyId` → 顺序调 3 次 PUT（dialogue / utility / agent），3 行都引用同一把 key + 同一 modelId（用户后续在 Settings 调整）。

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/model-config/model/types.ts` | ModelConfig / Provider / Scenario / ModelRef / Upsert* 类型 |
| `frontend/src/entities/model-config/api/model-config.ts` | 4 个 hooks |
| `frontend/src/entities/model-config/index.ts` | public API |
| `frontend/src/features/settings/ui/ModelDefaultsSection.tsx` | 3 行卡片 UI（dialogue/utility/agent），独立 upsert |
| `frontend/src/features/settings/ui/KeyModelPicker.tsx` | 按 apiKeyId 分组的 picker 下层组件（ConvModelOverride / WorkflowEditor InspectorBody / ModelDefaultsSection 共享）|
