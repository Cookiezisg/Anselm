# Anselm 文档索引

> AI 与人的文档入口。工程纪律先读 [`CLAUDE.md`](../CLAUDE.md)，文档创建、
> 同步和淘汰规则见 [`GOVERNANCE.md`](GOVERNANCE.md)。

## 当前系统

| 问题 | 权威入口 |
|---|---|
| 产品心智、分层与端到端数据流 | [`concepts/architecture.md`](concepts/architecture.md) |
| 后端整体结构 | [`references/backend/overview.md`](references/backend/overview.md) |
| HTTP / DB / error / SSE 四索引 | [`api`](references/backend/api.md) · [`database`](references/backend/database.md) · [`error-codes`](references/backend/error-codes.md) · [`events`](references/backend/events.md) |
| 某个后端领域 | [`references/backend/domains/`](references/backend/domains/) |
| loop、stream、durable、sandbox、bootstrap 等地基 | [`references/backend/foundation/`](references/backend/foundation/) |
| 本地 sidecar 与已部署 Anselm API 的边界 | [`references/backend/managed-gateway.md`](references/backend/managed-gateway.md) |
| 前端整体结构与产品面 | [`references/frontend/overview.md`](references/frontend/overview.md) |
| 前端架构 / DTO / 设计系统 / 平台宿主 | [`architecture`](references/frontend/architecture.md) · [`contract`](references/frontend/contract.md) · [`design-system`](references/frontend/design-system.md) · [`platform`](references/frontend/platform.md) |
| Chat、Entities、Library、Notifications、Scheduler、Settings | [`references/frontend/features/`](references/frontend/features/) |
| 黑盒 testend 与真实 evals | [`references/testend/overview.md`](references/testend/overview.md) |
| 数据目录、备份与跨机迁移 | [`how-to/data-migration.md`](how-to/data-migration.md) |

## 决策、在研与历史

| 要找 | 去向 |
|---|---|
| 不可变架构取舍及 supersede 关系 | [`decisions/`](decisions/) |
| 后端持续真实体验迭代 | [`working/backend-evolution/README.md`](working/backend-evolution/README.md) |
| 桌面发行与平台未完成面 | [`working/platform-foundation/README.md`](working/platform-foundation/README.md) |
| 当前文档治理战役 | [`working/document-governance/CHARTER.md`](working/document-governance/CHARTER.md) |
| 已完成、终止或被取代的施工证据 | [`archive/`](archive/) |

权威顺序：`CLAUDE.md` → current `references/` → `concepts/` → `working/` →
`archive/`。archive 只用于追溯，不能作为当前实现依据。
