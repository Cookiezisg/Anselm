---
id: DOC-023
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Conversation

## 1. 定位

Conversation 是 Chat thread 的持久容器。它保存身份、列表状态和每回合读取的
配置；Message/Block 由 Chat 与 Messages 负责。

主行包含：

- title、auto-title、archived、pinned、last-message-at、has-unread；
- system prompt、attached documents、model override；
- compaction summary 与覆盖水位；
- fork lineage；
- 可选 workdir residency。

Summary、水位、auto-title、unread 与 lineage 是系统写字段，不进入普通 PATCH。
Attached document 与 ModelRef 在写入时 eager 校验，避免 dangling 配置。

## 2. 列表与运行投影

`last_message_at` 是列表活跃度排序键；rename、pin 或设置变更只更新
`updated_at`，不能意外重排 thread。

三种活动信号：

| 字段 | 来源 | 是否持久 |
|---|---|---|
| `isGenerating` | Chat queue registry | 否 |
| `awaitingInput` | HumanLoop broker | 否 |
| `hasUnread` | 完成回复/seen 状态 | 是 |

用户发送时 unread=false；completed assistant finalize 时 unread=true；error 或
cancelled 不置未读。`:seen` 幂等清除。运行态由 app 服务在 Get/List 时补齐。

List 使用 keyset 分页，支持 active/archived、pin、驻地与搜索投影；GET rail 的默认序是 pinned-first
再按 `last_message_at` 倒序，也可切到 `created` 或 `name`。服务端 cursor 除了排序键与 id，还携带当前
pinned 分区和完整查询 scope，因此置顶线程超过一页时仍能完整走到 unpinned 分区，不依赖“所有置顶都在首页”的假设；
把 cursor 复用到另一查询轴会得到 `MALFORMED_CURSOR`，而不是静默跳页。客户端切换 sort、archive、search、pinned 或
workDir 任一轴时仍必须丢弃旧 cursor。
GET 列表同时以 `X-Anselm-Total-Count` 响应头返回当前完整过滤轴的精确总数；它与分页 body 分离，不参与 cursor，
但必须与 `archived`、`pinned`、`workDir`、`search` 和 workspace 隔离使用完全相同的过滤。前端段头显示这个总数，
不能用已加载窗口的 `rows.length` 代替，否则滚动会让“置顶/最近”计数漂移。
`list_conversations` 的 `limit`
接受原生整数及托管模型可能发出的精确十进制字符串；`includeArchived` 同样接受原生布尔或精确的
`"true"`/`"false"` 字符串。浮点、任意字符串和数组仍拒绝。服务端生成的 cursor 是无填充
base64url(JSON)；解码同时接受等价的标准填充形式，兼容托管模型对不透明字符串自动补齐 `=` 的
规范化，但不会接受无法解码或无法解析的值。LLM 的
`list_conversations` 是忠实分页枚举；`search_conversations` 是内容检索，不能
代替全集。

`search_conversations` 是“过去历史”的上下文检索：在对话回合中自动排除当前 thread，
避免用户要求找旧内容时把正在提问的这条消息算成命中。每个命中返回
`conversationId`、标题、`matchKind`、有界 `snippet` 与 `matchedChunks`；消息命中还返回
命中消息的 `messageId`，标题卡命中则 `matchKind=conversation_title` 且 `messageId` 为空，
不得伪造消息指针。它只作为回到历史的指针，绝不倾倒全文。`total` 是服务端真实命中总数，
助手必须按它报告并保留每个命中的区分；搜索卡保留精确机器值，助手正文对 opaque ID 只指向
搜索卡，不得露出 `the requested item` 这类坏占位符。
部分托管模型会把 `limit` 发成精确十进制字符串；该窄兼容与原生整数等价，浮点、任意
字符串、数组和其它形状仍拒绝。

## 3. 配置与删除

PATCH 可修改 title、system prompt、attached documents、model override、
archived、pinned 与 workdir。给 archived thread 发送新消息会自动 unarchive。
PATCH 只持久化实际变化；空 patch 或所有提供字段都已等值时返回当前实体，但不刷新
`updatedAt`、不写 workdir marker，也不发 `conversation.*` 生命周期通知。ModelOverride
遵守缺键=不变、对象=设置、显式 `null`=清除的三态；workdir 空字符串表示卸载。

Delete 先取消在途生成，再软删主行，并清 relation、touchpoint 与 Chat
per-conversation ephemeral state。Messages 的耐久边界不由 Conversation 主行
删除语义改写。

Auto-title 只在无标题首轮后执行。生成与持久化使用独立有界 context；失败不
影响回合，仍无标题时可在后续回合重试。

## 4. Fork

Fork 创建新 Conversation，并复制选定 Message 之前的 durable prefix；源
thread 零改写。新主行复制 system prompt、attached documents、model override
与 workdir，记录 source conversation/message lineage；archived 与 pinned 不
复制。

所有新 Message/Block ID 在写入前预铸并 remap：

- block parent 可以跨 Message 指向更早 tool_call；
- `superseded_by` 与 `retryOf` 必须指向 fork 内新 ID；
- prefix 外的指针清空，不能悬回源 thread。

只有 prefix 覆盖到源 summary 水位时才携带 summary；携带时按 fork 重排后的
block seq 重定水位。否则 summary 会描述 fork 中不存在的回合。

Fork 是独立 thread，源后续变化不传播。Relation 使用现有 `create` verb 记录
source → fork provenance。

## 5. Workdir residency

Workdir 是 Conversation 的可选绝对目录焦点：

- 相对路径以它解析；
- Bash 从它启动；
- system prompt 明示当前位置；
- 目录外读取仍允许，目录外写入升级 HumanLoop 确认。

它不是 sandbox 或权限模型。修改 workdir 在下一 Chat turn 生效，并写
`marker{kind:"workdir",from,to}`；仅在同一目录切 branch 不写 marker。

`GET /conversations/{id}/workdir` 每次从文件系统/git 计算：

- path、exists、isGitRepo、branch、dirty；
- local branches；
- repository worktrees 与 current 标记。

这些是有界活投影，不另建表。Workdir groups 对整个 workspace 聚合未置顶
threads，分别返回 active/archived count；批量 archive/delete 使用同一集合，
避免分页 UI 自己推导错误计数。

## 6. Git 动作

Conversation 只提供与“住在哪里”有关的三个 git 动作：

- switch existing local branch：重新读取 dirty，脏工作树拒绝；
- create branch at current HEAD：允许 dirty，因为工作树内容不变化；
- add worktree：名称派生 sibling path 与 `wt/<name>` branch，成功后 residency
  移入新 worktree。

路径不由调用方自由指定。已存在目录拒绝；已存在的 worktree branch 可复用。
写操作通过参数数组调用 git，不拼 shell。无法预分类的 git 失败保留稳定错误码，
并把 stderr 放入 details 供排障。

## 7. 契约

精确 CRUD、`:seen`、`:fork`、workdir 与 git action 端点见
[`api.md`](../api.md)。表见 [`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。ID：`cv_`。

LLM 工具为内容搜索、分页列举与当前 Conversation 的 archive/unarchive/
pin/unpin/rename 管理。压缩是自动机制，不暴露手动 compact 动作。

`list_conversations` 的 `lastMessageAt` 是权威 RFC3339 值；当用户要求报告该字段时，LLM 必须逐字保留，
不得用「记录时间」等泛化短语替代。
