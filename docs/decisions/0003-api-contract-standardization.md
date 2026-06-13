---
id: DOC-039
type: decision
status: active
owner: @weilin
created: 2026-06-13
reviewed: 2026-06-13
review-due: 2099-12-31
audience: [human, ai]
---

# 0003 — 后端 API 契约标准化（S1-S9）

## 背景

后端由 AI 分阶段写成，同类面在不同实体上长得不一样：Create 有的返 `{entity, version}`、有的返 `{trigger: …}`、有的裸返；异步动作返新 id 的键名五花八门（`messageId`/`flowrunId`/`conversationId`/`fired+triggerId+activationId`）；List 有的 `Paged`、有的裸数组、有的把聚合塞顶层；tool/执行结果有的裹 `{result}`/`{output}`、有的裸返；错误有的走 N1 envelope、有的裸 `http.NotFound`；SSE 点状广播该 ephemeral 的当 durable 占 replay 环；内部构造器/投影/分页签名各写各的。**前端要为每个端点单独建心智** —— 这是该消灭的偶然复杂度，不是要改地基。

## 决策

**确立一套贯穿全后端的统一契约（十轴），逐字落进 reference 文档、由门禁守住。** 关键定型（完整 24 决策台账见 archived `working/standardization-review/CHARTER.md`）：

1. **Create = GET 形状**（MD1）：Create 返**裸实体**，版本实体的当前版本走既有 `activeVersion` 内嵌字段——不另造 `{entity,version}` 包裹、不加冗余 `currentVersion`。
2. **分页恒 `Paged`**（MD2/N4）：所有 List 返 `{data:…, nextCursor, hasMore}`——分页坐标**顶层**、聚合（aggregates/total）进 `data` 子对象。执行·调用·搜索列表同形。
3. **异步动作返单产物 `{id}`**（MD3/N2）：返新建资源 id 的异步动作一律 `202 {data:{id}}`（`messageId`/`flowrunId`/`conversationId`/`activationId` 统一为 `id`；URL 已含的父 id、被 202 蕴含的 `fired` 等冗余键删去）。
4. **动作语义收口**（MD4/MD5/N5）：状态变更动作返实体后置快照（对齐 activate/deactivate）；无可轮询产物的 fire-and-forget（`:reindex`/`:resolve`/DELETE）返 **204**；同步执行（`:run`/`:call`/`:invoke`）返**裸结果**、不裹 `{result}`/`{output}`；真子资源（stream/content）保 CRUD，纯动作（pin/reindex/cancel/mark-read）用 `:action`。执行动词 `:run`/`:call`/`:invoke`/`:trigger`/`:fire` 保留为标准词表。
5. **错误恒走 envelope**（S20）：transport 一切失败经 `responsehttpapi.FromDomainError` → N1 `{error:{code,message,details}}`（Kind→HTTP status）；零裸 `responsehttpapi.Error`/`http.NotFound`/`http.Error`。
6. **SSE ephemeral 分级**（E2）：「DB 行才是真相、流只为实时呈现」的点状广播（flowrun 节点 tick、trigger fire、chat interaction）置 `Ephemeral:true`、不占 replay 环；必达通知信号保 durable。
7. **线缆 camelCase / 物理 snake_case**（N3）：实体结构体补齐 `json` tag、`workspace_id` 等内部列 `json:"-"` 不上线缆；URL 路径占位 camelCase。
8. **内部归一**：app Service 构造器统一 `NewService`；搜索投影抽共享 `searchdomain.EntitySlim`；聚合方法统一 `Compute<LogType>Aggregates`；仓库分页统一 `ListFilter` 结构体；工具列表/搜索输出统一 `toolapp.ToJSON`。

## 取舍

**为何不选：**
- **逐端点打补丁**：用户明确否决（「统一标准、不是改」）——先定标准、再机械归一，避免每处临时决断又长出新分歧。
- **把 agent `:invoke` 也改异步返 `{id}`**：放弃。同步执行器本就阻塞返完整结果，强行异步化是为对齐而牺牲语义。
- **`:reindex` 返 202**：放弃。202 暗示有可轮询产物；reindex 是 fire-and-forget、无产物，故 204（再调返 409 `SEARCH_REINDEX_RUNNING` 即足够探测在跑）。
- **`EntitySlim` 放 `app/tool` / `Compute<Entity>Aggregates`**：放弃。`EntitySlim` 置于 `domain/search`（紧邻同为 json-tagged 结果 DTO 的 `Hit`、既有先例）；聚合命名取 `Compute<LogType>Aggregates`（Execution/Call）以对齐既有 `ComputeCallAggregates`，而非按实体命名。

## 后果

- **前端一套心智**：每类端点（Create/List/action/error/SSE）形状一致，reference 文档（[api.md](../references/backend/api.md) / [error-codes.md](../references/backend/error-codes.md) / [events.md](../references/backend/events.md) / [database.md](../references/backend/database.md) / domains/）= 代码的精确投影。
- **门禁守恒**：`TestTransportErrorsUseFromDomainError` AST 守卫钉死「transport 零裸错误写出」；`TestErrorSentinelsUseErrorsPkg` + `TestWireCodesGloballyUnique` 守错误统一；`make verify` 全绿。
- **执行**：分九波 S1-S9 落地（裸实体 / 异步 id / 动作收口 / URL 占位 / 分页 / 错误 / SSE / 内部 / 文档勘误），各波独立提交 + verify+testend 绿 + 文档同提交 1:1 同步。两轮并发对抗审查（54 agents）确认 + 修了 10 处遗漏 doc/注释、第二轮收敛为零残留。
- **N/D/E/S 契约宪法**（CLAUDE.md）为最高法；本 ADR 记决策与取舍，过程台账（CHARTER/CONFORMANCE）archived。
