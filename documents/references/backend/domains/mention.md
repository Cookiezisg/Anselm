---
id: DOC-114
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# @-Mention 引用 — V1.2 详设计

**状态**：✅ 交付（2026-05-25）：`domain/mention` 端口 + 4 个 `AsMentionResolver()`（document/function/handler/workflow）+ chat `RegisterMentionResolver` 注册表 + `Send` 解析存储 + `buildUserLLMMessage` 渲染。
**关联**：[`chat.md`](./chat.md) · [`document.md`](./document.md) · [`function.md`](./function.md) · [`handler.md`](./handler.md) · [`workflow.md`](./workflow.md) · spec：`docs/superpowers/specs/2026-05-25-at-mention-references-design.md`

---

## 1. 一句话

用户在 chat 里 `@` 一个实体（document / function / handler / workflow）→ 发送时把它的内容**快照**进这条用户消息 → 之后是普通历史消息，LLM 自然看得到，**零每轮重注入**。@ 本质 = "把这个实体的内容附到消息上"（类比附件）。

## 2. 范围 + 判据

可 @ 4 类。判据：**"LLM 自己有工具能拉的就不 @"**。

| 类型 | 注入内容 | LLM 自有工具 |
|---|---|---|
| **document** | name + description + 正文 | **无** → @ 是唯一路径（故 document 移出 catalog）|
| **function** | name + description + active version 代码 | `get_function`（@ 是产品便利捷径，接受冗余）|
| **handler** | name + description + active version 方法 + init schema | `get_handler` |
| **workflow** | name + description + active version Graph(JSON) | `get_workflow` |

**不做**：skill（`activate_skill` 自驱）、mcp（`search/call_mcp_tool`）—— @ 会跟它们自己的 activation 打架。

## 3. 快照语义

发送时解析一次、存进消息、之后不重解析。文档**后被改** → 老消息保留当时那一版（历史不被后续编辑篡改）。代码类块带 `(snapshot at <发送时间>)` 标记，提示 LLM 改前先 `get_X` 最新。

## 4. 架构（与 catalog 对称）

- 端口 `internal/domain/mention`：`MentionType` / `MentionInput{Type,ID}`（前端 wire 形状）/ `Reference{Type,ID,Name,Content}`（已解析快照）/ `Resolver{Type(); Resolve(ctx,id)→*Reference}`。
- 每个 app：`AsMentionResolver() mentiondomain.Resolver`（调 `Service.Get`，versioned 类型再 `GetVersion(ActiveVersionID)` 取代码/方法/图）。
- `chatapp.Service`：`mentionResolvers map[MentionType]Resolver` + `RegisterMentionResolver(r)`（按 `r.Type()` 入表）。main.go 装配 4 个。

## 5. 数据流

```
前端：@ 选 {type,id} → onSend { content, mentions:[{type,id}] }
后端 ChatHandler.SendMessage：sendMessageRequest.Mentions → chatapp.SendInput.Mentions
  chatapp.Service.Send：对每个 mention resolvers[type].Resolve(ctx,id) → Reference（快照）
     · 无 resolver → 跳过 + Warn；resolve 失败（删/瞬时）→ stub Reference{Name:"(无法加载)"}，不阻断发消息
  → 存进 user Message.Attrs["mentions"] = []Reference（零迁移：Attrs 本就 serializer:json）
组 LLM transcript：history.buildUserLLMMessage 读 Attrs["mentions"] → renderMentionsXML → 追加为 text part（text blocks 之后、attachments 之前）
```

## 6. 渲染（镜像 `RenderAttachedAsXML`）

```xml
<mentions>
<mention type="function" id="f_1" name="csv_clean">
(snapshot at 2026-05-25T16:00:00Z)
description...
def csv_clean(args): ...
</mention>
</mentions>
```
document 不带 snapshot 标记（静态参考内容）；stub 渲染 `[引用的实体无法加载]`。

## 7. 不做 / Out of scope

- 会话级钉住：`conversation.AttachedDocuments`（每轮 live 重注入）已覆盖"整对话常驻"；@ 是每消息快照，互补。
- `read_document` LLM 工具：故意不加，document 保持 @-only。
- token 预算裁剪：快照 + 文档 1MB 上限是天然边界。
- 全链路 harness e2e（Send→agent→LLM）：渲染路径已由 `buildUserLLMMessage` 集成测试覆盖；Send 解析-存储 wiring 简单，e2e 留后续。

## 8. 测试

- `domain/mention`：纯类型。
- `app/chat`：`renderMentionsXML`（document 无标记 / 代码带标记 / stub 占位）+ `RegisterMentionResolver` + `buildUserLLMMessage` 渲染存储快照。
- `app/{document,function,handler,workflow}`：resolver `Type()` + document `Resolve` 内容/not-found。
