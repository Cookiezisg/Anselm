---
id: DOC-027
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# todo —— 对话工作清单（LLM 自管 + 实时呈现）

## 1. 定位 + 心智模型

每对话一份 LLM 自管的工作清单（≤64 项——超出是规划异味；上限同时给 reminder 注入设界）。**整表替换写**（TodoWrite 语义：LLM 每次重写全清单，状态机在 LLM 脑中、存储只管快照）。两条呈现路径：**reminder**（chat host 每步前注入 live 清单为临时 `<system-reminder>`——清单顶在模型眼前、不污染持久历史）+ **messages 流**（写入即推 todo 信号，前端实时渲染面板）。

## 2. 契约（引用）

表 `todos`（按 conversation 一行，items json）→ [database.md](../database.md) · 码 `TODO_*` 3 → [error-codes.md](../error-codes.md)。LLM 工具：todo_write（resident）。被消费：chat（ReminderProvider 端口 + 流）。
