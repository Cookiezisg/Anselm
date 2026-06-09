# Round 0050 — conversation（波次 5 · M5.1）

类型 / 目标：波次 5「对话与上下文」第一站。对话线程的**持久化容器 + 线程级配置**——一个干净的 CRUD 垂直切片（无 LLM、无 loop、无消息）。document 范式的同构叶子。

依赖扫描：
- 上游就绪：documentdomain（`AttachedDocument`）、modeldomain（`ModelRef`，R0020）、notificationdomain（`Emitter`，R0024）、relation（`PurgeEntity`/`Namer`/`EntityKindConversation`，R0021）、pkg/orm（`Repo[T]`/`Query.Page` keyset/`ErrNotFound`/自动 ws 隔离 + 软删 + 时间戳）、idgen（`cv_`，S15 已登记）。
- 下游接口（消费者）：chat（M5.2）读 SystemPrompt/AttachedDocuments/ModelOverride + 写 AutoTitled；contextmgr（M5.3）写 Summary/SummaryCoversUpToSeq；relation 经 Namer hydrate。
- 考古：旧 `backend` conversation（domain 60 + store 156 + app 215 + relations 53）——GORM + user_id + `AnyReferencesApiKey` 反查 + notif.Publish。**只读、不照搬结构**。

旧实现历史包袱：GORM tag + `gorm.DeletedAt` + `UserID` + `reqctx.RequireUserID` 手写谓词 + `notificationspkg.Publisher` + `AnyReferencesApiKey`（apikey 反查）+ `errors.New` 命名错误。**全卸**。

修改后完整逻辑（= domains/conversation.md DOC-106 as-built）：
- **schema 一次到位**：`conversations`（cv_）单表，13 列。**全配置列声明**（summary/summaryCoversUpToSeq/autoTitled 由后续轮写，但 `summary` 已被 `domain/messages` 前向引用故非投机）；PATCH 只暴露用户可改子集（title/systemPrompt/attachedDocuments/archived/pinned/modelOverride）。业务表软删（`deleted_at`，D1）。
- **List 置顶优先**：`ORDER BY pinned DESC, created_at DESC, id DESC`，partial index `WHERE deleted_at IS NULL`；keyset 游标键 `(created_at, id)`（pkg/orm `Page`）——pinned 页内浮顶、单用户本地不跨页漂移（务实取舍，D5）。archived 三态过滤 + title LIKE search。
- **modelOverride** = `model.ModelRef{apiKeyId, modelId, options}`，**仅结构校验**（apiKeyId+modelId 非空 → `CONVERSATION_INVALID_MODEL_OVERRIDE`，照 agent 先例）——**不探 key 存在性**（弱引用 + chat 时 `model.Resolve` 优雅失败）→ **conversation 对 apikey 零依赖**。handler `UnmarshalJSON` 探 key 存在性做三态（缺/null/object）。
- **广播** `conversation.<action>` 经 `notification.Emitter`（created/updated/archived/unarchived/pinned/unpinned/model_override/deleted）——持久化 + notifications SSE signal（document 先例）。
- **relation 第 8 节点**：`NamesByIDs`（Title/Summary 预览/占位）+ Delete 时 `PurgeEntity`，均 nil-tolerant。

删除 / 合并：GORM/user_id/`AnyReferencesApiKey`（零消费者）/旧虚构错误码（`ErrTitleTooLong=INVALID_REQUEST`/`ErrDeleteFailed=INTERNAL_ERROR`）。**deferred M5.2**：`tokensUsed` 富化（message_blocks token 和）+ `/system-prompt-preview`（prompt 拼装）——本质是 chat 数据，不引 chat 类型。**M5.1 不级联删 message_blocks**（消息表归 chat）。

契约变更（→ contract-changes #32）：domains/conversation.md DOC-106 整篇重写；database §2.2 Conversation struct as-built（+ idx 注释，Message/Block 标 chat M5.2）；api §对话端点标 M5.1 ✅ / system-prompt-preview 标 M5.2；error-codes §2.4 加 `CONVERSATION_INVALID_MODEL_OVERRIDE`(422)；S15/cv_ 已登记无改。

新实现要点：domain（Conversation 13 列 + Repository 6 法 + ListFilter + UpdateInput〔modelOverride `**ModelRef` 三态〕 + 2 errorsdomain）；store（`var Schema`〔1 表 + 1 partial 索引〕 + orm 包装，List 用 `Query().WhereEq/Where/Order/Page`）；app（Service CRUD/PATCH + `emit` + `validateModelOverride` + relations.go〔Namer/purge nil-tolerant〕）；handler（5 纯 REST 端点，无 :action）。

新测试（store + app 全离线 in-memory sqlite）：
- store（13）：InsertGet 往返（ws 戳 + 时间戳）、Get NotFound、modelOverride+attached JSON 往返、List 置顶优先+最新（seed 钉 created_at 确定排序）、archived 三态、search LIKE、cursor 翻页、软删后 Get/List 排除 + 重删 NotFound、ws 隔离、GetBatch。
- app（8）：Create trim+emit、CreateWithSystemPrompt、modelOverride 三态 set→clear、invalid override、pin/archive emit 动作名、Update NotFound、Delete emit+purge、NamesByIDs label 回退。

验证：gofmt clean / `go build ./...`（整仓）exit 0 / vet（conversation + handlers）clean / `go test`（store + app）全绿。

是否更干净（自证）：分支减少（无 user_id 谓词、无 generation）；fallback/alias 减少（无 GORM serializer、无 `AnyReferencesApiKey` 反查、无虚构错误码）；职责更直接（持久化容器 + 配置，消息/LLM/压缩明确不在本域）；无多余抽象（modelOverride 复用 ModelRef + 照 agent 校验范式、对 apikey 零依赖）。

覆盖状态（capability-ledger）：对话线程容器 + 线程级配置（标题/置顶/归档/软删/systemPrompt/attachedDocuments/modelOverride）落地；消息/运行时归 chat M5.2。

遗留 / 下一步：**M5.2 chat** 🔴 核心模块——message_blocks 表 + loop 运行时 + 流式 + 自动命名 + mention 渲染 + **折叠 subagent + tool/subagent**；按铁律先出契约给用户审再写码。chat 轮补回 conversation 的 `tokensUsed` 富化 + `/system-prompt-preview`。M5.3 contextmgr 写 summary。M7：conversation Namer/PurgeEntity 注入 relation、emitter 接真 notification。
