---
id: WRK-026-HISTORY
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
landed-into:
---

# History index

本页只提供历史入口，不复制历史结论。当前产品事实以 backend reference 为准，当前待测
路径以 [`FRONTIER.md`](FRONTIER.md) 为准。

| 历史工作 | 可追溯材料 | 当前落点 |
|---|---|---|
| Backend Iteration v1 | [`archive/backend-evolution-v1/`](../../archive/backend-evolution-v1/) | 本目录 README/CURRENT/FRONTIER |
| 全模态平台 | [`archive/multimodal-output/`](../../archive/multimodal-output/) 与 ADR 0013–0020 | [`attachment`](../../references/backend/domains/attachment.md)、[`architecture`](../../concepts/architecture.md) |
| BYOK 治理 | [`archive/byok-governance/`](../../archive/byok-governance/) | [`stream-llm`](../../references/backend/foundation/stream-llm.md)、[`managed-gateway`](../../references/backend/managed-gateway.md) |

历史直连 `EVALS_MEDIA` 及其 provider-specific recorder 仍存在于 testend，作用是保存旧线缆
证据；它不代表当前生成产品路径，也不属于默认或 managed acceptance 的配置要求。

完整逐轮证据保留在只追加的 [`LOG.md`](LOG.md)。完成场景不会复制到本页。
