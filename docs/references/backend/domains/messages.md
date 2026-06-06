---
id: DOC-301
type: reference
status: active
owner: @weilin
created: 2026-06-06
reviewed: 2026-06-06
review-due: 2026-09-01
audience: [human, ai]
---
# Messages Domain — 对话回合的内容模型

> **核心地位**：messages 是「一个 assistant 回合**由什么组成**」的中立内容模型——`Block` 树（reasoning / text / tool_call / tool_result）+ 流式 tool call 解析出的 `ToolCallData`。
>
> **与 `domain/stream` 正交**：stream 是**传输**（一帧怎么到前端：`Envelope/Frame/Node`），messages 是**内容**（回合由什么块组成）。共享 ReAct 引擎 `app/loop` 产 `Block` 并依赖**本包**、而非依赖 `chat` 这种具体消费者——故 `chat / agent / subagent / workflow-agent` 共享一个中立内容模型。这修正了旧架构「共享引擎 `loop` 依赖 `domain/chat`」的耦合反向。

---

## 1. 物理模型 (Data Anatomy)

```go
type Block struct {
    ID             string         `db:"id,pk"`             // blk_<16hex>
    ConversationID string         `db:"conversation_id"`
    MessageID      string         `db:"message_id"`        // 所属回合；block 的 stream parentId
    ParentBlockID  string         `db:"parent_block_id"`   // tool_result → 其 tool_call
    Seq            int64          `db:"seq"`               // 落盘时分配（loop 不设）
    Type           string         `db:"type"`              // BlockType*
    Attrs          map[string]any `db:"attrs,json"`        // tool_call: {tool,summary,danger}; reasoning: {signature}
    Content        string         `db:"content"`
    Status         string         `db:"status"`            // Status*
    Error          string         `db:"error"`
    ContextRole    string         `db:"context_role"`      // 压缩器投影（contextmgr M5.3）；落盘默认 hot
    CreatedAt      time.Time      `db:"created_at,created"`
    UpdatedAt      time.Time      `db:"updated_at,updated"`
}

type ToolCallData struct {        // 内存解析形态，不原样落库（转成 tool_call Block）
    ID             string         `json:"id"`
    Name           string         `json:"name"`
    Summary        string         `json:"summary"`         // LLM 自报：本次调用意图
    Danger         string         `json:"danger"`          // LLM 自报：safe/cautious/dangerous（纯字符串，不引 app/tool）
    ExecutionGroup int            `json:"executionGroup"`  // 并行批键
    Arguments      map[string]any `json:"arguments"`       // 已剥 3 标准字段的业务 args
}
```

`Block` 落 `message_blocks` 表（`blk_` 前缀），但**store / 落盘 / History 查询留 chat M5.2**——本轮（loop M2.2）只立类型契约 + 词表，loop 内存产 `Block`、经 `host.WriteFinalize` 外包落盘，自身不碰表。`Danger` 在 domain 存为**纯字符串**：`tool.DangerLevel` 是 app 层概念，domain 不能反向依赖 app，故 loop 在 `collectToolCalls` 做 `DangerLevel`→`string` 转换。

---

## 2. 词表 (Vocabularies)

| 词表 | 取值 | 说明 |
|---|---|---|
| `BlockType*` | `text` `reasoning` `tool_call` `tool_result` `compaction` | loop 发的内容树节点种类。旧 eventlog 的 `progress`/`message` **已砍**——更深层级（subagent 子树）经 stream `Open.ParentID` 表达，不靠新增块型。 |
| `Status*` | `pending` `streaming` `completed` `error` `cancelled` | message 与 block 共用一套。message 回合开始前为 `pending`；block 在 open↔close 间隐含 `streaming`；三终态与 `stream.Close` 状态 1:1。 |
| `StopReason*` | `end_turn` `max_tokens` `max_steps` `cancelled` `error` | 回合结束原因。`max_steps` 是**非成功**终态——loop 撞步数上限，诚实暴露使 UI 提供「继续」（不冒充 completed end_turn）。 |
| `ContextRole*` | `hot` `warm` `cold` `archived` | 压缩器（contextmgr M5.3）投影 block 如何进 LLM 历史而**不改写**落库 Content：hot 全文 / warm 截断预览 / cold 省略带标记 / archived 丢弃（并入 conversation.summary）。 |

---

## 3. messages 流的 Node content 形状（loop 那一份词表）

loop 是 messages 流的 producer，定义它发的 4 种 node 的 `Node.Content` 形状（「词表下放 producer」）。`open` 帧带最小元数据；**`close` 帧带完整快照**——`delta` 是 ephemeral（不入 replay buffer），buffer 内重连只见 open/close，故 close 的 `Result` 必须能重建内容。

| node.type | open content | delta | close result |
|---|---|---|---|
| `text` | —（空） | token 文本 | `{content}` |
| `reasoning` | —（空） | token 文本 | `{content, signature?}` |
| `tool_call` | `{name}` | args JSON 增量 | `{name, arguments, summary?, danger?}` |
| `tool_result` | `{content}`（一次性产出，无 delta） | — | —（close 只带 status/error） |

**danger 纯标记**（M2.2「纯信任」）：LLM 自报的 `danger`/`summary` 随 `tool_call` 节点上行（close result + 落库 `Attrs`），前端据此显示一句话摘要、标记 `cautious`/`dangerous` 调用。**本轮不阻塞执行**——`dangerous` 调用的确认暂停在 loop 层留接口位，待 ask 通道就绪（波次 6）接入。

---

## 4. 与 stream / loop 的关系

```
              produces                streams (transport)
  loop  ───────────────►  Block  ──────────────────────►  stream.Bridge (messages)
   │                        │                                   open / delta / close
   │  host.WriteFinalize    │  collectToolCalls
   ▼                        ▼
  message_blocks 表      ToolCallData (内存，loop 用 danger/group 决策)
```

- **stream = 怎么推**：`Envelope{seq,scope,id,frame}`，scope 锚 `conversation:<id>`，frame ∈ open/delta/close/signal。
- **messages = 由什么组成**：`Block` + 词表 + node content 形状。
- loop 产 `Block` → 一路经 `stream.Bridge` 实时推前端（Node.Content 装 block 内容）、一路经 `host.WriteFinalize` 落 `message_blocks` 表。两条路都保留：推流在 loop 内（best-effort，无 bridge/conv 自禁用），落盘外包给 host。

---

## 5. 契约边界（本轮 vs 后续）

| 范围 | 归属 |
|---|---|
| `Block` / `ToolCallData` / 词表 / node content 形状 | **messages domain（本轮 M2.2）** |
| `message_blocks` 表 store / DDL / workspace 隔离列 / History 查询 / `Message` 实体 | chat M5.2 |
| `ContextRole` 的写入（压缩） | contextmgr M5.3 |
| 前端按 frame + node.type 重渲（events.md 全量重写） | 覆盖阶段（见 contract-changes #2 / #11） |

> **过渡态注记**：旧 `domains/chat.md` 仍描述 `Block`（旧 chat domain）。backend-new 把 `Block` 移到本包；`chat.md` 在 chat M5.2 重写时清理为只剩 `Message` / conversation messaging。
