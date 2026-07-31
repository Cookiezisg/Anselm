---
id: DOC-026
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Memory

## 1. 定位

Memory 是 workspace 级、跨 Conversation 的长期事实。每条记忆是一个可直接编辑、
可进 Git 的 Markdown 文件：

```text
<workspace data>/memories/<name>.md
```

`name` 是稳定身份，不另铸 ID。合法名称为最长 64 字符的 lowercase slug。Frontmatter
只保存 description、pinned、source，正文保存 content；文件 mtime 投影为 updatedAt。

Source 是 `user | ai`。Description 与正文都必须非空。

## 2. 模型上下文

每次 Chat system prompt 分两层注入：

- pinned：逐条注入完整正文；
- unpinned：只注入 name + description 索引。

非 pinned 内容由模型按需调用 `read_memory`。这样用户可把稳定规则置顶，同时避免全部
长期记忆永久占满上下文。

LLM 工具为 `read_memory`、`write_memory`、`forget_memory`，通过 lazy discovery 提供。
`write_memory` 写入 AI source，不能自行 pin。

## 3. 更新与策展

Upsert 以 name 决定 create/update。更新既有记忆时只改 description/content，并保留：

- `pinned`：只能由专用 pin/unpin 动作改变；
- `source`：作者归属不可由内容更新重写。

因此模型更新用户置顶规则时，不会静默取消置顶或把作者改成 AI。

Create/Update/Delete 发送持久通知并通知 Search 重建；pin/unpin 只广播实时更新，不制造
新的 inbox 行。通知与索引均 best-effort，文件仍是事实源。

## 4. 契约

CRUD 与 pin 端点见 [`api.md`](../api.md)，错误见
[`error-codes.md`](../error-codes.md)。Memory 无数据库表；文件隔离与安全 slug 规则由
filesystem repository 承担。Search 只维护可再生投影。
