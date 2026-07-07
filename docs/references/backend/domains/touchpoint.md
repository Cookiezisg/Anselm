---
id: DOC-049
type: reference
status: active
owner: @weilin
created: 2026-07-02
reviewed: 2026-07-02
review-due: 2026-10-02
audience: [human, ai]
---

# touchpoint —— 对话触点台账

## 1. 定位 + 心智模型

**每个对话一份「外部世界触点记录」**：凡这个对话碰过的东西——用户 **@ 过的**（mentioned）、带进来的**附件**（attached）、AI **创建/编辑/看过/执行/删除过的**实体（created/edited/viewed/executed/deleted）——中央落盘、可查询、实时流出。**每 (对话, 物, 动词) 一条聚合行**（count + first_at/last_at + last_actor + last_message_id），**非**事件日志（逐事件历史已在 message blocks，右岛要的是「碰过什么、怎么碰、多新鲜」）。与 **relation 分工**：relation 答「现在谁挂着谁」（结构**终态**，diff-sync、edit 边随 active 版本覆盖）；touchpoint 答「这个对话碰过什么」（**历程**，只积累）。物 kind = relation 11 种 EntityKind 逐字复用 + 台账独有 `attachment`；**item_name 显示名快照**写入时经 Namers hydrate（与 relation 同一批 source-domain resolver + attachment 的 filename namer），实体删除后台账行**保留**、名字仍诚实可显（配 `deleted` 动词）。**同一 Namer 路径复用**：`Service.ResolveName(ctx, toolName, args)`（`ExtractTouches` 定主目标 + `lookupName` hydrate）供 loop 在**关帧时**给 tool_call 块盖目标实体的显示名（`toolCallContent.entityName` + block attrs，`loop/stream.go`），使前端卡头显「Run Function «sync_inventory»」而非裸 id——名解析单一来源、与台账零漂移；无可命名目标返 ""（前端退回 id）。

**写入三个水龙头（全 best-effort：nil 容忍、失败仅 log 绝不阻断热路径）**：① **chat Send**——mention 快照 → `mentioned`、attachmentIds → `attached`（actor=user，锚 user 消息）；② **loop 工具咽喉**（`runOneTool`，全系统每次工具执行的唯一汇流点）——**真派发并跑到返回**的调用才记（门 = `ok && executed`：`executed` 是 `dispatchWithGate` 第四返回值[工具是否派发并跑]、`ok` 是工具层无 Go error。**「不记」的是工具层没发生**——被拒的危险调用 / 运行前取消[executed=false] 或坏 ref / 畸形参数令工具返 Go error[ok=false]，拒绝的 delete_agent 绝不产生 `deleted` 幽灵行）。**注意「成功」是工具层语义,非实体操作的内部结果**：一个**真被执行**的实体在内部 raise / 返 `{ok:false}`（如 run_function 跑真函数而它抛异常、invoke_agent 的 agent run status=failed）**仍记 executed**——台账是「对话碰过什么」的事实足迹（该实体确被执行过一次），与 viewed/created 无条件记同理、跨工具一致；执行成功与否属执行审计（`*_executions` 的 ok/failed rollup）的职责，非台账。目标提取两条路：**带 `TouchEntity()` 标记的实体绑定工具**（agent 挂载的 function/handler/mcp + 动态 `mcp__` 工具——以实体自己的名字运行，自报 `{kind,id,name}` 记 `executed`、完全绕过目录[用户实体撞目录键名也不会误提取]；mcp 报 `mcp_` id 与 install 键收敛），其余走 `app/touchpoint/catalog.go` **中央目录**提取 `{kind,id,verb}`（args 键 / 输出 JSON 键 / create_document 散文正则 / mcp__ 前缀回退；skill 短名即显示名）；actor 按 reqctx subagent 判（记到父对话名下）、记账器经 ctx 种入（chat runner 种、subagent/invoke 继承、无对话路径天然不见）；③ **conversation 删除**——`PurgeConversation` 级联硬删整份台账（`SetTouchpointPurger`，与 relation purge 同款）。**目录穷尽性门禁**：bootstrap 内 `TestTouchpointCatalog_CoversEveryTool` 走真装配工具集，断言每个工具 ∈ 提取目录 ∪ 显式 no-touch 清单——新工具不表态即门禁红。失败调用不记（失败的触碰不是触碰）；提取宁少报不报错。**已知边界**：`deleted` 行的名字快照经 store **兄弟借名**（同 (对话,物) 任意有名行——hydrate 只查活体、删除时必落空；对话没碰过就删的孤儿行诚实空名）；invoke_agent 嵌套运行内的触碰 `lastMessageId` 锚的是外层 tool_call block id（invoke 路径 reseed 所致，前端跳转仍可达）；`uninstall_mcp_server`/`reconnect_mcp` 以短名为键（args 只有短名、纯提取不查库——F166 双键老疣的残留，显示名经 namer 双键解析仍收敛）。

**读侧**：`GET /conversations/{id}/touchpoints`（keyset 分页 `last_at DESC, id`，可选 kind/verb 枚举过滤）；未知对话返回空页（同 todos——无台账非错误）。**实时**：每次记账推 **messages 流 durable Signal**（`node.type="touchpoint"`，scope=conversation，payload=单行视图——幂等 upsert、重放安全、每触碰 O(1)），DB 行是真相、漏推 REST 兜回（E1 三流不破，先例=todo 信号）。

## 2. 契约（引用）

表 `conversation_touchpoints`（聚合行 + 唯一索引 + 硬删语义）→ [database.md](../database.md) · 码 `TP_*` 4 → [error-codes.md](../error-codes.md) · 端点 `GET /conversations/{id}/touchpoints` → [api.md](../api.md) · 信号帧 → [events.md](../events.md)。写方：chat Send（`app/chat/touches.go`）+ loop 咽喉（`app/loop/touches.go` → `app/touchpoint/catalog.go`）+ conversation Delete 级联。消费：右岛 entity-workspace（Phase 4.2 V8，前端数据缝随右岛建）。无 LLM 工具（未来可加 get_conversation_context）。
