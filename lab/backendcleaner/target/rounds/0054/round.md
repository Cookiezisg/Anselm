# Round 0054 — messages 持久化（波次 5 · M5.2 chat 子轮 1/3：落盘地基）

类型 / 目标：给 chat runner 建**消息持久化底座**——`domain/messages` 加 `Message` 实体（一个对话回合 = turn 记录）+ `Repository` 接口；`infra/store/messages` 建 `messages` + `message_blocks` 两表（orm、手写 DDL、seq 单调分配）。这是 chat host 的 `LoadHistory`（读历史）/ `WriteFinalize`（落终态）的落盘层。M5.2 拆 3 子轮：**R0054 落盘地基** → R0055 chat Service+host+runner 核心 → R0056 chat HTTP+auto-title+跨域接线。

依赖扫描：
- **上游就绪**：`domain/messages`（R0031 已立 `Block`/`ToolCallData`/全套词表 status/type/contextRole/stopReason）；`domain/conversation`（R0050，线程容器，已有 summary/summaryCoversUpToSeq 列供压缩器写）；`pkg/orm`（`Transaction` 多表事务 + `For[T]` + `Pluck` 聚合 + 软删按 `deleted` tag 判定 + workspace 按 `ws` tag 自动隔离）；`pkg/idgen`（`msg_`/`blk_` 前缀 database.md 已登记）；`errorsdomain`。
- **下游消费者（本子轮的客户）**：chat（R0055）—— `CreateMessage`（user 回合 + 开 assistant 回合拿 msgID 喂 reqctx/SSE message_start）/ `FinalizeMessage`（`WriteFinalize` 落终态+blocks）/ `LoadThread`（`LoadHistory` 全量历史）；chat HTTP（R0056）—— `ListMessages`（REST 分页历史）/ `GetMessage`（trace）。**5 法皆有已知消费者，无投机**。
- **考古**：旧 `domain/chat/chat.go`（Message+Block 同包）+ `infra/store/chat/chat.go`（443 行，GORM）。backend-new 已把 `Block` 移到中立 `domain/messages`（修正旧「共享引擎 loop 依赖 chat」耦合反向）；本轮 `Message` 跟随落 **`domain/messages`（非复活 `domain/chat`）**——turn 记录与 Block 同属内容模型、agent/subagent/chat 共享。

设计要点：
- **Message → `domain/messages`**：turn 记录（拥有 Block 树）。字段：`ID(msg_)/ConversationID/WorkspaceID/Role/Status/StopReason/ErrorCode/ErrorMessage/InputTokens/OutputTokens/Provider/ModelID/Attrs/CreatedAt/UpdatedAt` + `Blocks []Block`（非 DB 列，store hydrate）。`Role` ∈ user/assistant（`RoleUser`/`RoleAssistant` + `IsValidRole`）。`Attrs` 装 attachments/mentions 快照（freeze-on-send）。复用既有 Status/StopReason 词表。
- **两表，皆 append-only（无 `deleted_at`，D1「Journal/Log 禁删」）**：
  - `messages`（`msg_`）：turn 记录。`workspace_id`（D2，orm `,ws` 自动隔离）。`role`/`status` CHECK。索引 `(workspace_id, conversation_id, created_at, id)` 供按对话时序列。
  - `message_blocks`（`blk_`）：内容日志。`UNIQUE(conversation_id, seq)`（D3 风格幂等键 `idx_blocks_conv_seq`）。`type` CHECK(text|reasoning|tool_call|tool_result|compaction)、`status` CHECK(5 态)、`context_role` CHECK(hot|warm|cold|archived) DEFAULT 'hot'。`parent_block_id`（tool_result→其 tool_call）。`workspace_id`（D2）。
- **seq 单调分配**：per-conversation `MAX(seq)+1`，在 `CreateMessage`/`FinalizeMessage` 的 `db.Transaction` 内一次性算（`blockRepo.WhereEq("conversation_id",id).Order("seq DESC").Limit(1).Pluck("seq")`，agent `NextVersionNumber` 范式），按块顺序递增赋值。**安全性靠 chat convQueue（R0055）per-conv 串行写**——同对话同一时刻只有一个 AI 协程落盘，无并发 seq 竞争。
- **Repository 5 法**：
  - `CreateMessage(ctx, m *Message, blocks []Block) error`——tx：insert message 行 + seq 分配 + insert blocks。user 回合（role=user/status=completed/1 text block）；开 assistant 回合（role=assistant/status=streaming/blocks=nil）。
  - `FinalizeMessage(ctx, m *Message, blocks []Block) error`——tx：update message 终态列（status/stopReason/errCode/errMsg/tokens/provider/modelId）+ seq 分配 + insert blocks。chat `WriteFinalize` 用。
  - `GetMessage(ctx, id) (*Message, error)`——+ blocks hydrate；缺失 → `ErrMessageNotFound`。
  - `ListMessages(ctx, convID, cursor, limit) ([]*Message, next, error)`——N4 分页、按 (created_at, id) 时序、+ blocks（REST 历史）。
  - `LoadThread(ctx, convID) ([]*Message, error)`——全量回合（chat `LoadHistory`，单用户本地不分页）、+ blocks 按 seq。
- **blocks hydrate 助手**：读 message 行后 `blockRepo.WhereIn("message_id", ids).Order("seq").Find` → 按 message_id 归组挂回。

强化地基：无（orm `Transaction`/`For`-on-tx 已具，本轮是首个用多表事务的 store——合法用法，非补地基）。

修改后完整逻辑：
- **domain/messages/messages.go**：+ `Message` struct + `RoleUser`/`RoleAssistant`/`IsValidRole` + `Repository` 接口 + `ErrMessageNotFound`（errorsdomain，NotFound→404）。
- **infra/store/messages/messages.go**（新）：`Schema`（两表 + 索引）+ `Store`（持 db + Repo[Message] + Repo[Block]）+ 5 法 + `nextSeq`/`hydrateBlocks` 助手。

删除 / 合并：无（纯增）。Block 已在 domain/messages（R0031），不动。

契约变更（→ contract-changes #36）：
- `domains/messages.md`：§1 加 `Message` struct；§5 边界表「`message_blocks` store / `Message` 实体」由「chat M5.2」改为「**R0054 ✅（落 domain/messages）**」；过渡态注记更新（domain/chat 不复活，Message 归 messages 域）。
- `database.md` §2.2：Message/Block 由 as-designed（旧 GORM tag、字段不全）重写为 as-built（db tag、全字段、workspace_id、两表索引）。
- **无新 REST / SSE**（store 层）；error-codes 加 `MESSAGE_NOT_FOUND`（404）若 GetMessage 冒泡（R0056 接 trace 时定，本轮先登记 domain 错误）。

新测试（全离线，store）：
- `CreateMessage` round-trip（user msg + text block → GetMessage 取回，blocks 挂对）。
- seq 跨 2 message 单调递增（msg1 占 1,2；msg2 续 3,4——验 per-conv 连续不重置）。
- block 树（tool_call + tool_result，tool_result.ParentBlockID = tool_call.ID 往返）。
- `FinalizeMessage`（开 assistant 回合 status=streaming → finalize 改 completed + 追加 blocks，终态列回写对）。
- `ListMessages` 分页时序（≥limit 条→next cursor，按 created_at 升序）。
- `LoadThread` 全量（多回合按时序、每回合 blocks 按 seq）。
- workspace 隔离（A 工作区落盘、B 工作区 LoadThread 空）。
- `GetMessage` 缺失 → `ErrMessageNotFound`。

验证：gofmt clean / `go build ./...` exit 0 / vet clean / `go test ./...` 全绿。

是否更干净（自证）：① Message 归中立 `domain/messages`（agent/subagent/chat 共享、修正旧 loop→chat 反向耦合）；② 两表 append-only 对齐 D1（内容日志不可删，省掉级联软删复杂度）；③ seq 单调靠 convQueue 串行（无分布式锁/序列表，单进程单用户的本质简化）；④ `CreateMessage`/`FinalizeMessage` 两段对齐 loop 契约（host 在 Run 前建 message 行拿 msgID、Run 后落终态）；⑤ 5 法皆有已知下游消费者、无投机方法（反校验剧场）。

遗留 / 下一步：**R0055 chat Service + host + runner 核心**——chatHost 实现 loop.Host（LoadHistory 拼历史〔LoadThread + conv.Summary + attachment ToContentParts + mention 渲染〕/ Tools〔toolset + AutoActivator + ReminderProvider todo〕/ WriteFinalize〔FinalizeMessage + message_stop 发射〕）+ convQueue（per-conv channel 容量 5 + idle GC + STREAM_IN_PROGRESS）+ System Prompt（Section 容器 + locale）+ message_start 发射 + reqctx 埋种子（msgID/convID/Bridge）+ Detached Context 终态 + model resolve（conv.ModelOverride→workspace 默认）。
