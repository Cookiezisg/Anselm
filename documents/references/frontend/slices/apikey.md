---
id: DOC-210
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# entities/apikey — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/apikey）
**状态**：✅ 已实现
**职责**：管理 ApiKey（provider 凭证）的 CRUD + 测试连通性。ApiKey 的 `key` 字段后端只返回掩码（`keyMasked`），前端不持有明文。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/apikey.md`

---

## 1. 职责边界

- 列表 / 创建 / 更新（displayName / baseUrl / key / isDefault）/ 删除
- 连通性测试（:test — 异步检测 API key 可用性并更新 testStatus）

---

## 2. 类型（`model/types.ts`）

```ts
interface ApiKey {
  id: string;     // aki_<16hex>
  userId: string;
  provider: string;
  displayName: string;
  keyMasked: string;      // 后端返回掩码，原始 key 不暴露
  baseUrl: string;
  apiFormat: string;
  testStatus: "pending" | "ok" | "error";
  testError: string;
  lastTestedAt: string | null;
  modelsFound: string[];
  isDefault: boolean;
  createdAt; updatedAt;
}

interface CreateApiKeyBody { provider; displayName; key; baseUrl?; apiFormat? }
interface UpdateApiKeyPatch { displayName?; baseUrl?; key?; isDefault? }
interface TestApiKeyResult { ok: boolean; message; latencyMs: number; modelsFound: string[] }
```

---

## 3. API hooks（`api/apikey.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useApiKeys()` | GET `/api-keys?limit=100` | 列表；select pickList |
| `useCreateApiKey()` | POST `/api-keys` | 创建；invalidate apikeys |
| `useUpdateApiKey(id)` | PATCH `/api-keys/{id}` | 更新；invalidate apikeys |
| `useDeleteApiKey()` | DELETE `/api-keys/{id}` | invalidate apikeys |
| `useTestApiKey()` | POST `/api-keys/{id}:test` | 测试连通；invalidate apikeys（更新 testStatus） |

---

## 4. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/apikey/model/types.ts` | ApiKey / Create* / Update* / Test* 类型 |
| `frontend/src/entities/apikey/api/apikey.ts` | 5 个 hooks |
| `frontend/src/entities/apikey/index.ts` | public API |
