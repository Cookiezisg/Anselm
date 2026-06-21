---
id: DOC-023
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# conversation —— 对话线程容器

## 1. 定位 + 心智模型

线程**容器**实体：身份（title/pin/archive/软删）+ 线程级配置（systemPrompt / attachedDocuments / modelOverride——用户可改，chat 运行时消费）。**消息不在这**（归 messages/chat）。三个系统写字段在记录里但**不进 PATCH 面**：`Summary`/`SummaryCoversUpToSeq`（压缩器写）、`AutoTitled`（chat 首回合自动命名后写、绝不覆盖用户标题）。

**PATCH 三态**：`ModelOverride **ModelRef`——nil=不变、&nil=清除、&(&ref)=设置（指针的指针表达三态）。List：Archived nil=排除归档（默认）/&true=仅归档/&false=仅活跃；**Sort 可选**——`activity`（默认，置顶优先再 `last_message_at` 降序，最近聊过）或 `created`（置顶优先再 `created_at` 降序）。store 据 Sort 切 `Order(... <key> ...)` + `PageKeyset(<key>)`，游标键随排序列对齐（见 [orm.md](../foundation/orm.md)）；故**切换 Sort 须丢弃游标**（一种排序下的游标在另一种下无意义）。未知/空 Sort → activity（不报 400）。

**last_message_at**（最近活跃排序键）：普通列（非 `,updated` tag，故 pin/改名/换模型不重排）。创建时种为 now，chat 经 `ConversationReader.TouchLastMessage` 在每个用户回合刷新——"最近聊过"上浮，ChatGPT 式 Today/Yesterday 分组的依据。

**isGenerating**（派生只读，`db:"-"`）：List/Get 据 chat 注入的 `GeneratingQuerier` 端口逐行填——该对话当前是否有在途 assistant 回合。让刚连上 / SSE 重连的客户端冷启动活动圆点（无需等下一帧）；纯运行时状态、不落库、不进 PATCH。与 canceler 同款后注入端口破 chat↔conversation 环。

**Unarchive**：chat Send 的自动解档入口（给归档线程发消息即隐式唤回）。**Delete 连带停生成**：可选 `GenerationCanceler` 端口（chat 满足、后注入破环）——删对话先 cancel 在途生成，已删线程不再烧 LLM/推流。

## 2. 契约（引用）

LLM 工具：`search_conversations`（内容混合检索历史对话——只返 conversationId/title/snippet/messageId，绝不返全文；回忆是指针、不是上下文倾倒。**是内容回忆、非枚举**：只返消息匹配查询的线程、无匹配文本的漏掉，描述明禁当作完整列表，F146）· `list_conversations`（**忠实游标分页枚举**——答「列出我所有对话」的正路、补 search 的内容回忆缺口；复用 `Service.List`（ListFilter）、无新端点/表/码；返 id/title/archived/pinned/lastMessageAt 轻量行；默认仅 active、`includeArchived` 含归档；剩余页时返 `nextCursor` 使一页不被误当全集）· `manage_conversation`（归档/置顶/**改名本**对话——`action: archive|unarchive|pin|unpin|rename`（rename 需 `title`、复用 `UpdateInput.Title`），复用 `Service.Update` 的 PATCH 面、无新端点/表/码；从 ctx 取 conversationId，对话外降级 tool-result 串。描述声明**压缩是自动的**——无手动 compact/summarize 动作、无 UI 按钮，杜绝 agent 臆造按钮（含 rename 不臆造 UI 手势，F107）+ **给归档线程发消息会自动解档**（F106——使 agent 能警告，而非让下条消息静默撤销 archive 当前 thread）；chat system prompt 的 `conversation_management` 段同述此真相）。

端点（CRUD）→ [api.md](../api.md) · 表 `conversations` → [database.md](../database.md) · 码 `CONVERSATION_*` 2 个 → [error-codes.md](../error-codes.md) · ID：`cv_`。被消费：chat（每回合读配置）、relation（conversation↔实体的 create/edit 边的另一端）、aispawn（`:iterate`/`:triage` 创建）。
