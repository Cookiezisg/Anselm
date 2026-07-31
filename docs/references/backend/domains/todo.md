---
id: DOC-027
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Todo

## 1. 定位

Todo 是 Agent 的短期工作清单，不是业务任务实体或审计日志。每个执行 scope 只有一张：

- 主 Agent：scope ID = Conversation ID；
- Subagent：scope ID = Subagent run ID，同时保留父 Conversation ID。

每项没有 ID，只包含 content、activeForm 与状态：

```text
pending | in_progress | completed
```

一次 Write 整体替换当前清单；空数组明确表示清空。单张最多 64 项，content 必填，
activeForm 缺席时回退到 content，status 缺席时默认为 pending。

## 2. 模型可见性

Loop 每一步前读取当前 scope，把有未完成项的清单注入临时 system reminder。Reminder：

- 显示全部项和 open/done 计数；
- 要求保持一个 in_progress；
- 不写入 Message 历史；
- 清单为空或全部 completed 时不注入。

`todo_read` 始终可读完整持久清单，包括 completed 项。它解决 reminder 在全部完成后
主动消失、模型却仍需诚实回顾清单的问题。`todo_write` 回显刚写入的完整 Markdown。

## 3. 持久化与实时投影

`todos` 每 scope 一行，items 作为 JSON value 整体覆盖。无行和空清单对读取者语义相同，
不是错误。

每次 Write 后在 messages 流发送 durable `node.type = "todo"` Signal，scope 锚父
Conversation；Subagent ID 放在 payload，允许 UI 嵌入正确运行树。DB 是事实源，漏掉实时
推送时由 REST 重新读取。

## 4. 契约

Conversation Todo 读端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，Signal 见 [`events.md`](../events.md)，错误见
[`error-codes.md`](../error-codes.md)。Todo 由 Loop 的 ReminderProvider 消费，不进入
Relation 或 Touchpoint。
