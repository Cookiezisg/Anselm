---
id: DOC-049
type: reference
status: active
owner: @weilin
created: 2026-07-02
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Touchpoint

## 1. 定位

Touchpoint 是每个 Conversation 的外部世界触点台账。它回答：

> 这段对话碰过什么、以什么方式、多少次、最近是谁在什么时候碰的？

每个 `(conversation, item kind, item id, verb)` 只有一条聚合行，保存 count、
first/last timestamp、last actor、last message 与显示名快照。它不是逐事件日志；精细过程
仍在 Message Blocks。

Item kind 复用 Relation 的 11 种实体，并额外加入 `attachment`。Verb 是封闭集：

```text
mentioned | created | edited | viewed | executed | attached | deleted
```

Actor 为 `user | assistant | subagent`。

## 2. 与 Relation 的边界

Relation 是会随版本和删除而变化的结构终态；Touchpoint 是只积累的对话历程。实体删除后
Touchpoint 仍保留，并靠最后已知名称与 `deleted` verb 诚实显示过去发生过的事。

Conversation 删除时，其整份 Touchpoint 派生台账物理清除。

## 3. 写入咽喉

三类入口统一写台账：

1. Chat Send
   - mention → `mentioned`；
   - user attachment → `attached`；
   - actor 为 user，锚定 user message。
2. Loop 工具咽喉
   - 只有工具确实派发且没有 Go-level error 时记录；
   - 实体执行返回业务失败仍记 `executed`，因为实体确实被调用过；
   - HumanLoop 拒绝、运行前取消、坏参数或未派发不制造幽灵触点；
   - Subagent 写回父 Conversation，但 actor 为 subagent。
3. Conversation Delete
   - 级联 purge 台账。

实体绑定工具可通过 `TouchEntity()` 自报目标；其余工具由中央 catalog 从 args、结构化
output 或少量显式规则提取。动态 `mcp__<server>__<tool>` 归到对应 MCP。
Bootstrap 门禁要求每个真实注册工具必须出现在 touch catalog 或显式 no-touch 清单，
防止新工具静默漏记。

提取与写入均 best-effort：可以少报，但不能因台账错误阻断工具或 Chat 热路径。

## 4. 名称与消息投影

写入时使用与 Relation 同源的 Namers hydrate 当前显示名；Attachment 使用 filename。
后续非空名称会刷新快照，删除后的空 hydrate 不覆盖已有名称。同一名称解析路径还给
tool-call block 填 `entityName`，让 UI 展示人类名称而不是裸 ID。

每次 Upsert 后，在 messages 流发送 durable `node.type = "touchpoint"` Signal，scope
锚 Conversation，payload 为更新后的单行。DB 是事实源；SSE 漏推由 REST 重新读取收敛。

## 5. 读面与契约

`GET /conversations/{id}/touchpoints` 按 `(lastAt DESC, id)` keyset 分页，并可按 kind、
verb 过滤。无台账返回空页，不把它当 Conversation 错误。

表见 [`database.md`](../database.md)，端点见 [`api.md`](../api.md)，Signal 见
[`events.md`](../events.md)，错误见 [`error-codes.md`](../error-codes.md)。
当前没有 LLM 读工具；Conversation 上下文由前端右岛和 REST 使用。
