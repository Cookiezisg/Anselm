---
id: DOC-106
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-09
review-due: 2026-09-01
audience: [human, ai]
---
# Conversation Domain — 对话线程容器与配置治理

> **核心职责**：Conversation 域是对话线程的**持久化容器 + 线程级配置**。它**不持有消息**（消息是
> message_blocks，归 chat M5.2），只管理线程身份（标题、置顶、归档、软删）与 chat 运行时每轮要读
> 的配置（system prompt、挂载文档、模型覆盖）。一个干净的 CRUD 垂直切片：无 LLM、无 loop。
>
> **三模块分工**：conversation = 线程记录 + CRUD（本域）· chat（M5.2）= message_blocks + loop 运行时
> + 流式 + 自动命名 + mention 渲染 · contextmgr（M5.3）= 写 `summary`/`summaryCoversUpToSeq`（压缩）。

---

## 1. 物理模型 (Data Anatomy)

### 1.1 `Conversation` 实体（as-built，pkg/orm、无 GORM）
```go
type Conversation struct {
    ID                   string                            `db:"id,pk"`                    // cv_<16hex>
    WorkspaceID          string                            `db:"workspace_id,ws"`          // orm 自动隔离
    Title                string                            `db:"title"`
    AutoTitled           bool                              `db:"auto_titled"`              // chat(M5.2) 写
    SystemPrompt         string                            `db:"system_prompt"`            // PATCH 可改 · chat 读
    Summary              string                            `db:"summary"`                  // contextmgr(M5.3) 写
    SummaryCoversUpToSeq int64                             `db:"summary_covers_up_to_seq"` // contextmgr 写
    AttachedDocuments    []documentdomain.AttachedDocument `db:"attached_documents,json"`  // PATCH 可改 · chat 读
    Archived             bool                              `db:"archived"`
    Pinned               bool                              `db:"pinned"`
    ModelOverride        *modeldomain.ModelRef             `db:"model_override,json"`      // PATCH 可改 · nil=用默认
    CreatedAt            time.Time                         `db:"created_at,created"`
    UpdatedAt            time.Time                         `db:"updated_at,updated"`
    DeletedAt            *time.Time                        `db:"deleted_at,deleted"`       // D1 软删
}
```

**列归属**：本域（M5.1）声明**完整 schema** 并对**用户可改子集**（title / systemPrompt / attachedDocuments /
archived / pinned / modelOverride）开放 PATCH。`summary`/`summaryCoversUpToSeq` 列声明但由 contextmgr（M5.3）写、
`autoTitled` 由 chat（M5.2）写——三者不进 PATCH 面。`summary` 已被 `domain/messages`（BlockTypeCompaction /
ContextRole archived「内容并入 conversation.summary」）前向引用，故在此声明而非投机预留。

---

## 2. 核心原理 (Principles)

### 2.1 置顶气泡列表 (Pinned-First List)
- **物理 SQL**：`ORDER BY pinned DESC, created_at DESC, id DESC`，partial index `WHERE deleted_at IS NULL`。
- **游标**：keyset 键 `(created_at, id)`（pkg/orm `Page`）。pinned 在页内浮顶收藏，**游标只键 (created_at, id)**
  ——单用户本地（对话数 ≪ 页大小、几乎无第二页）不产生跨页漂移；这是「置顶优先」与简单 keyset 游标共存的
  务实取舍（非严格正确，若日后需要可改「置顶单独成段、前端浮顶」）。
- **archived 三态过滤**：缺省排除已归档 · `?archived=true` 仅归档 · `?archived=false` 仅活跃。
- **search**：`title LIKE`（V1；消息内容 / 工具名 FTS5 后续）。

### 2.2 Per-Conversation Model Override (线程级模型覆盖)
- **是什么**：`ModelOverride` = `model.ModelRef{apiKeyId, modelId, options}`——选「哪把 key + 哪个 model + 原生
  旋钮」，provider 由 key 隐含（见 `model.md`）。同一模型可经多把 key 到达 → 「模型下多个 api 可选」。
- **校验**：仅**结构校验**（apiKeyId + modelId 都非空 → `CONVERSATION_INVALID_MODEL_OVERRIDE`），照 agent 先例
  ——**不探 key 存在性**（弱引用范式：前端只给可达 (key,model) 对、删 key 在 chat 时优雅失败）。**conversation
  对 apikey 零依赖**。
- **三态 PATCH**：`modelOverride` 缺省 = 不变 · 显式 `null` = 清除 · object = 设置（handler `UnmarshalJSON` 探 key
  存在性区分缺/null）。
- **解析（chat M5.2）**：host 调 `model.Resolve(ctx, dialogue, conv.ModelOverride, workspacePicker)`——override 非空
  即胜出，否则回落 workspace 的 dialogue 默认模型。

### 2.3 自动命名（chat M5.2，非本域）
标题可手动改（PATCH title）；**自动命名属 chat 运行时**——chat 在首轮 assistant 回复后识别 `autoTitled==false`、
调 utility 模型生成标题、写回 DB 并经 notifications SSE 通知前端。本域只声明 `auto_titled` 列。

### 2.4 压缩摘要 + 水位（contextmgr M5.3，非本域）
`Summary`（滚动压缩摘要）+ `SummaryCoversUpToSeq`（水位线：摘要已并入的最大 block seq）二列由 **contextmgr 运行时**写，本域只提供写入路径 `Service.SetSummary(id, summary, coversUpToSeq)`（Get→写二列→Update→emit `conversation.compacted {coversUpToSeq, summaryBytes}`；PATCH 不暴露）。**水位是「已并入摘要」的真相源**：chat `LoadHistory` 丢弃 `seq ≤ 水位` 的块（崩溃安全 + 幂等重摘）。压缩原理详见 `compaction.md`。

---

## 3. 生命周期 (Lifecycle)

1. **新建**：`POST /conversations`（或 `CreateWithSystemPrompt`，ask-ai/triage M6 用，首轮即带 entity 上下文）。
2. **活跃**：chat（M5.2）向此 ID 挂载 message_blocks。
3. **改配置**：`PATCH /conversations/{id}`——title / systemPrompt / attachedDocuments / archived / pinned /
   modelOverride（三态）。
4. **归档**：PATCH `archived=true`——默认列表隐藏、不物理删。
5. **软删**：`DELETE`——置 `deleted_at`（D1，留墓碑）+ 清 relation 边（PurgeEntity）。**M5.1 不级联删
   message_blocks**（消息表归 chat，其 conversation_id 仍指向墓碑；级联策略随 chat M5.2 定）。

每个 mutation 经 `notification.Emitter` 广播 `conversation.<action>`（created / updated / archived / unarchived /
pinned / unpinned / model_override / deleted）——持久化 + notifications SSE signal，前端列表实时刷新。

---

## 4. 跨域集成 (Interactions)

- **chat（M5.2）**：消息根容器；读 systemPrompt / attachedDocuments / modelOverride 拼每轮上下文 + 自动命名。
- **contextmgr（M5.3）**：写 summary / summaryCoversUpToSeq（压缩）。
- **document**：`AttachedDocuments` 引用（chat 运行时 `ResolveAttached` 展开单篇、无子树）。
- **model**：`ModelRef` 值 + `Resolve` 规则。
- **relation**：第 8 类节点——实现 `Namer`（id→Title/Summary 预览/占位 hydrate）+ Delete 时 `PurgeEntity`。
- **notification**：`Emitter` 发 `conversation.*` 事件。

**留 chat M5.2**：`GET /conversations/{id}` 的 `tokensUsed` 富化（聚合自 message_blocks）+
`GET /conversations/{id}/system-prompt-preview`（prompt 拼装）——二者本质是 chat 数据，本域不引 chat 类型。

---

## 5. 错误字典 (Sentinels)

| Sentinel | HTTP | Wire Code | 备注 |
|---|---|---|---|
| `ErrNotFound` | 404 | `CONVERSATION_NOT_FOUND` | id 不存在 / 已软删 / 属于另一 workspace。 |
| `ErrInvalidModelOverride` | 422 | `CONVERSATION_INVALID_MODEL_OVERRIDE` | 已设的 modelOverride 缺 apiKeyId 或 modelId（结构校验，照 agent）。 |
