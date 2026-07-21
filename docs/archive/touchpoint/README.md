---
id: WRK-051
type: working
status: archived
owner: @weilin
created: 2026-07-02
reviewed: 2026-07-02
review-due: 2026-09-30
audience: [human, ai]
landed-into: references/backend/domains/touchpoint.md, references/backend/api.md, references/backend/database.md, references/backend/events.md, references/backend/error-codes.md
---

# WRK-051 — touchpoint 对话触点台账(建造规范,已落地归档)

> 右岛(chat entity-workspace)的后端地基:**每个对话一份「外部世界触点记录」**——用户 @ 过的、AI 创建/编辑/看过/执行过的实体、附件——中央落盘、可查询、实时流出。用户 2026-07-02 拍板:仅后端全套(表/写入咽喉/REST/SSE/测试/文档),前端数据缝随右岛(V8)再建。
> 建完 → 结论提取进 `references/backend/domains/touchpoint.md` + 四索引,本页归 `archive/`。

## 0. 与 relation 的分工(边界铁律)

- **relation** 答「现在谁挂着谁」——结构**终态**(diff-sync,edit 边随 active 版本覆盖)。不动。
- **touchpoint** 答「这个对话碰过什么」——**历程**(聚合行,只增不覆盖语义)。新域。
- 两者共享 EntityKind 词表与 Namers hydrate;touchpoint 多一个 `attachment` kind。

## 1. 锁定决策(用户已拍板 + 设计内锁)

| 决策 | 取值 |
|---|---|
| viewed 记录 | 记(「碰过就算」);前端可按动词分层显示 |
| 聚合 vs 逐事件 | **聚合行**:`UNIQUE(ws, cv, item_kind, item_id, verb)` + count/first_at/last_at;逐事件历史已在 blocks,不重复造 journal |
| subagent 触碰 | 记到父对话名下,`last_actor='subagent'` |
| 实体被删后 | 台账行**保留**(历程真相),`item_name` 快照落行内,hydrate 失败回落快照 |
| 域名/前缀 | 域 `touchpoint`,表 `conversation_touchpoints`,ID `tp_`,错误码 `TP_*` |
| SSE 通道 | **messages 流** durable Signal `node.type="touchpoint"`(先例:todo 信号),scope=conversation,payload=单行视图(幂等 upsert,replay 安全) |
| LLM 读工具 | 本轮不建(未来可加 get_conversation_context) |

## 2. 表(D 系列)

```sql
CREATE TABLE IF NOT EXISTS conversation_touchpoints (
  id              TEXT PRIMARY KEY,           -- tp_<16hex>
  workspace_id    TEXT NOT NULL,              -- D2
  conversation_id TEXT NOT NULL,
  item_kind       TEXT NOT NULL,              -- relation 11 kind + 'attachment'(CHECK)
  item_id         TEXT NOT NULL,
  item_name       TEXT NOT NULL DEFAULT '',   -- 最后已知显示名快照(删后诚实显示)
  verb            TEXT NOT NULL CHECK (verb IN ('mentioned','created','edited','viewed','executed','attached','deleted')),
  last_actor      TEXT NOT NULL CHECK (last_actor IN ('user','assistant','subagent')),
  count           INTEGER NOT NULL DEFAULT 1,
  first_at        DATETIME NOT NULL,
  last_at         DATETIME NOT NULL,
  last_message_id TEXT NOT NULL DEFAULT '',
  UNIQUE (workspace_id, conversation_id, item_kind, item_id, verb)
);
CREATE INDEX idx_tp_conv ON conversation_touchpoints (workspace_id, conversation_id, last_at);
```

- **硬删表**(同 relations:派生台账、无 deleted_at);对话删除级联 `PurgeConversation`。实体删除**不**清行(见 §1)。
- upsert 语义:撞唯一键 → `count+1, last_at=now, last_actor, last_message_id, item_name` 更新。

## 3. 动词与写入口(三个,全 nil 容忍、失败仅 log 绝不阻断)

| 动词 | 入口 | actor | 说明 |
|---|---|---|---|
| `mentioned` | chat `Send`(mentions 解析处) | user | 每个 MentionInput 一记 |
| `attached` | chat `Send`(attachmentIds 冻结处) | user | kind=attachment,名=filename |
| `created` / `edited` / `deleted` | loop 咽喉(runOneTool 成功后) | assistant / subagent | id 从 args 或 output JSON 提取(目录) |
| `viewed` | loop 咽喉(get/read/search 类) | assistant / subagent | 仅当 args 直接携带实体 id;search 类无单一目标 → 不记 |
| `executed` | loop 咽喉(run/call/invoke/trigger/fire + MCP 动态) | assistant / subagent | MCP 动态工具按前缀取 server |

- **咽喉落账规则**:工具执行 `ok==true` 才记(失败调用不是触碰);actor 由 `reqctx.GetSubagentID` 判;conversation id 缺失(纯 workflow/REST 路径)→ 整体 no-op。
- **目录 + 穷尽性门禁**:`app/touchpoint/catalog.go` 中央目录(toolName → kind/verb/id 来源);单测走 bootstrap 全量工具注册表,断言每个工具 ∈ 目录 ∪ 显式 no-touch 清单——新工具不表态即编译期外的门禁红。
- no-touch 清单(理由):resident 文件/网/子代理工具(不触实体)、todo_*(task 页有自己的缝)、memory_*(非实体)、blocks/model/list-search 类无单一目标者、flowrun 类(flowrun 非 item kind,不做二跳查 workflow)、approval decide(flowrun 侧)。

## 4. API(N 系列)

`GET /api/v1/conversations/{conversationId}/touchpoints?kind=&verb=&cursor=&limit=`

- N1 envelope;N4 keyset 分页(排序 `last_at DESC, id`);kind/verb 可选过滤(枚举校验)。
- 返回视图:`{id, itemKind, itemId, itemName, verb, lastActor, count, firstAt, lastAt, lastMessageId}`——itemName = 行快照(写入时经 Namers hydrate,attachment 用 filename)。
- 错误码:`TP_INVALID_KIND` / `TP_INVALID_VERB` / `TP_INVALID_ACTOR`(400,`errorspkg.New`)。

## 5. SSE(E 系列)

- messages 流 durable `Signal`:`node.type="touchpoint"`,scope=`conversation:<id>`,payload=单行视图(同 §4)。E1 三流不破;E2:durable(入 buffer、可 replay;行视图幂等 upsert,重放安全);前端自滤。
- best-effort:漏推由 REST 兜底(DB 行是真相)。

## 6. 验收

- 单测:domain(验证/upsert 语义)+ store(唯一键/分页)+ app(记账/快照/信号)+ 目录穷尽性门禁。
- testend 黑盒(llmmock 零 token):send 带 mention+attachment → 脚本化工具调用(create/get/edit)→ 断言 REST 聚合行(count/verb/actor)+ messages 流 touchpoint 帧。
- `make verify` + `make -C backend testend` + `make -C docs verify` 全绿。

## 7. 文档 1:1(同提交)

`references/backend/domains/touchpoint.md` 新建 · `api.md`(端点)· `database.md`(表 + tp_ 前缀)· `events.md`(信号帧)· `error-codes.md`(TP_*)· `conversation.md`/`relation.md`(消费关系/分工)· `concepts/architecture.md` + `CLAUDE.md` 相关节整体重述。

