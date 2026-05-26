# entities/model-config — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/model）
**状态**：✅ 已实现
**职责**：管理 ModelConfig（scenario → provider + modelId 映射）的查询 + upsert，以及辅助的 providers / scenarios 白名单查询。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/model.md`

---

## 1. 职责边界

- ModelConfig CRUD（upsert，按 scenario 为键）
- providers 静态白名单查询（GET /providers）
- scenarios 权威列表查询（GET /scenarios）

不含 conversation 级 modelOverride（由 entities/conversation PATCH 处理）。

---

## 2. 类型（`model/types.ts`）

```ts
interface ModelConfig {
  id: string;     // mc_<16hex>
  scenario: string;   // 主键（chat / forge / ...）
  provider: string;
  modelId: string;
  createdAt; updatedAt;
}

interface Provider {
  name; displayName; category;
  defaultBaseUrl?; baseUrlRequired: boolean;
}

interface Scenario { name: string }
interface UpsertModelConfigBody { provider: string; modelId: string }
```

`Scenario` 结构极简（仅 name），后端权威列表防止前端硬编码 scenario 白名单漂移。

---

## 3. API hooks（`api/model-config.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useProviders()` | GET `/providers` | provider 静态白名单 |
| `useScenarios()` | GET `/scenarios` | scenario 权威列表；staleTime 5min |
| `useModelConfigs()` | GET `/model-configs` | 全量 model config 列表；select pickList |
| `useUpsertModelConfig()` | PUT `/model-configs/{scenario}` body `{provider, modelId}` | upsert（无论新建/更新都返 200）；invalidate modelConfigs |

`useScenarios` 用 `staleTime: 5 * 60 * 1000`——scenario 列表基本不变，减少不必要请求。

---

## 4. 端到端数据流

```
用户在 Settings > Models 选择 scenario + provider + model
  → useUpsertModelConfig().mutate({scenario, provider, modelId})
      → PUT /model-configs/{scenario}  {provider, modelId}
      → 后端 upsert，校验 provider 有 api-key
      → onSuccess: invalidate modelConfigs
      → useModelConfigs() 重取 → ModelsTab 刷新显示
```

---

## 5. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/model-config/model/types.ts` | ModelConfig / Provider / Scenario / Upsert* 类型 |
| `frontend/src/entities/model-config/api/model-config.ts` | 4 个 hooks |
| `frontend/src/entities/model-config/index.ts` | public API |
