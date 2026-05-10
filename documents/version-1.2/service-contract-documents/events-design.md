# Events Design — V1.2 SSE 事件契约（双协议）

**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../event-log-protocol.md`](../event-log-protocol.md) — 完整 eventlog 协议设计文档（事件流示例 / 后端架构 / migration SQL / 风险）
- **配套实现**（eventlog）：
  - `domain/eventlog/` — Event 接口 + 5 events + 6 block types + Bridge 接口 + ValidateEvent
  - `infra/eventlog/` — in-process Bridge（per-conv 单调 seq + 4096 replay buffer + 慢订阅者阻塞）
  - `pkg/eventlog/` — Emitter (auto-mint ID + ctx-injected) + ctx helpers
- **配套实现**（notifications）：
  - `domain/notifications/` — 1 通用 Event envelope + Bridge 接口 + ValidateEvent
  - `infra/notifications/` — global broadcast Bridge（per-key 单调 seq + replay buffer + Last-Event-ID 重连）
  - `pkg/notifications/` — Publisher (ctx-injected) + With/From/MustFrom helpers
- **SSE 端点**：
  - `GET /api/v1/eventlog?conversationId=xxx` — per-conversation 流式内容（eventlog 协议）
  - `GET /api/v1/notifications` — global broadcast entity 状态（notifications 协议）
- **历史 refetch**：`GET /api/v1/conversations/{id}/eventlog?from=<seq>` (eventlog 协议 — 410 Gone 时的全态刷新)

**双协议（CLAUDE.md §E1）**：本契约覆盖后端唯二两个 SSE 流：
1. **eventlog**（per-conversation）— recursive event log 协议（5 events × 6 block types），流式 chat 内容
2. **notifications**（global broadcast）— 1 通用 envelope，entity 状态更新

两者共享 Bridge pattern（per-key seq + replay buffer + Last-Event-ID 重连），但订阅域 / 路由 / 演化规则不同。§1-§10 是 eventlog 主体；§11 是 notifications 协议；§12 是测试参考。

**遵守标准**：§E1（双协议；eventlog 5 events + 6 block types 封闭；notifications 开放词表）/ §E2（eventlog parentId 路由；notifications 按 type 过滤）/ §N7（SSE wire format）/ §S21（事件流 invariants）

---

## 1. 事件总览

| Event Type | 用途 | 触发频率 | DB 写入 |
|---|---|---|---|
| `message_start` | 开新 message（user / assistant / subagent） | 每 message 1 次 | ✅ → `messages` 行（终态时 SaveMessage） |
| `message_stop` | 关 message（终态） | 每 message 1 次 | ✅ → 同上 |
| `block_start` | 开新 block | 每 block 1 次 | ✅ → `message_blocks` |
| `block_delta` | 给 block append 内容 | 每 token / chunk | ✅ → AppendBlockContent |
| `block_stop` | 关 block | 每 block 1 次 | ✅ → FinalizeBlock |

## 2. Block 类型枚举（6 种穷举）

| Block Type | 含义 | content 形态 | attrs | 子 block 允许？ |
|---|---|---|---|---|
| `text` | LLM 主文本（含 tool_call 间叙述） | string，append | — | ❌ |
| `reasoning` | LLM 思考（extended thinking） | string，append | — | ❌ |
| `tool_call` | LLM 发起的工具调用 | args JSON 流式拼 | `{tool: string}` | ✅（progress / nested / tool_result） |
| `tool_result` | 工具最终返回 | result string | — | ❌ |
| `progress` | 工具进度文字（sandbox 装包 / 网络拉块） | string，append | `{stage?: string}` 自由文本 | ❌ |
| `message` | 嵌套消息占位（subagent 等） | — | `{messageId: string, ...}` | ✅（递归到下层） |

新增 block 类型必须先改 [`event-log-protocol.md`](../event-log-protocol.md) + DB CHECK + 前端 renderer，同 PR。

## 3. Status 枚举（4 种穷举）

`streaming` → 终态 (`completed` | `error` | `cancelled`)，单向不回退。

## 4. 完整事件 schema

```typescript
type Envelope = { seq: int64; event: Event }

type Event =
  | { type: "message_start"
      conversationId: string
      id: string                 // msg_<16hex>
      parentBlockId?: string     // 嵌套 message 才填（subagent 场景）
      role: "user" | "assistant" | "system"
      attrs?: object             // subagent: {kind:"subagent_run", type, runId, maxTurns}
    }
  | { type: "message_stop"
      conversationId: string
      id: string
      status: "completed" | "error" | "cancelled"
      stopReason?: string
      errorCode?: string
      errorMessage?: string
      inputTokens?: int
      outputTokens?: int
    }
  | { type: "block_start"
      conversationId: string
      id: string                 // blk_<16hex> (text/reasoning/result/progress/message)
                                 //  或 LLM 自带 tc_<id> (tool_call 复用)
      parentId: string           // 父 block ID 或 message ID（顶层 block 此处填 message ID）
      messageId: string          // 顶层归属 message ID（冗余但前端方便）
      blockType: BlockType
      attrs?: object
    }
  | { type: "block_delta"
      conversationId: string
      id: string
      delta: string              // append 字符串
    }
  | { type: "block_stop"
      conversationId: string
      id: string
      status: Status
      error?: string
    }
```

## 5. SSE wire format（§N7）

```
event: <type>
id: <seq>
data: <event JSON, 不重复 type/seq>

```

例：
```
event: block_delta
id: 42
data: {"conversationId":"cv_abc","id":"blk_xyz","delta":"hello"}

```

**重连**：`Last-Event-ID: <seq>` header → server replay buffer 内 seq > N 的事件，再接实时；超 buffer → 410 Gone + `code=SEQ_TOO_OLD` → 客户端 `GET /api/v1/conversations/{id}/eventlog?from=<seq>` refetch 全态。

## 6. 路由与嵌套

- 客户端按 `conversationId` 订阅一条 SSE
- 一个 conversation 内的所有事件（含主对话 + 嵌套 subagent / 嵌套 message）走**同一个 SSE 流**
- 路由靠 `parentId` 字段递归 — 不靠事件名分层
- 前端维护两个 Map：`state.messages: Map<id, Message>` + `state.blocks: Map<id, Block>`，每 block 用 `parent` 字段挂树

## 7. 嵌套示例

```
Conversation (cv_xx)
└─ Message (msg_main, role=assistant)
   ├─ Block (blk_text_1, type=text)
   ├─ Block (tc_abc, type=tool_call, attrs.tool="spawn_subagent")
   │   ├─ Block (blk_msg_placeholder, type=message, attrs.messageId=msg_sub)
   │   │   └─ Message (msg_sub, role=assistant, parentBlockId=blk_msg_placeholder)
   │   │      ├─ Block (blk_text_2, type=text)
   │   │      ├─ Block (tc_xyz, type=tool_call, attrs.tool="Read")
   │   │      │   └─ Block (blk_result, type=tool_result)
   │   │      └─ Block (blk_text_3, type=text)
   │   └─ Block (blk_summary, type=tool_result)  ← spawn_subagent 返主 LLM 的 summary
   └─ Block (blk_text_4, type=text)
```

## 8. Producer 责任分配

| Producer | 推什么 |
|---|---|
| `app/chat/Service.Send` | user message 5 类事件 burst（user message_start → 每 block 的 BlockStart/Delta/Stop → message_stop） |
| `app/chat/runner.processTask` | assistant message_start（顶层） |
| `app/chat/chatHost.WriteFinalize` | assistant message_stop |
| `app/loop/streamLLM` | 流式期间每 LLM 事件推 text/reasoning/tool_call block_start/delta/stop（共享给主对话 + subagent） |
| `app/loop/runOneTool` | tool_result block_start/delta/stop（每 tool 结束后） + WithParentBlockID(tc.ID) 给 tool 内部 emit 自动挂父 |
| `app/subagent/Service.Spawn` | message-block 占位（type=message） + sub message_start ；loop.Run 返后 message-block stop |
| `app/subagent/subagentHost.WriteFinalize` | sub message_stop |
| Tool.Execute 内部（progress / 嵌套 LLM） | 经 ctx 拿 emitter 自由 emit progress block / 嵌套 text block |

## 9. DB 写入表

`message_blocks`（事件日志协议主表）：

| 列 | 类型 | 说明 |
|---|---|---|
| id | text PK | `blk_<16hex>` 或 LLM tc_<id> |
| conversation_id | text NOT NULL UNIQUE(conv_id, seq) idx 1 | per-conv 路由 + UNIQUE |
| message_id | text NOT NULL idx | 顶层归属 |
| parent_block_id | text idx | 嵌套用；顶层 block 此列空 |
| seq | int NOT NULL UNIQUE(conv_id, seq) idx 2 | per-conv 单调（Bridge 分配） |
| type | text NOT NULL CHECK in 6 值 | block 类型 |
| attrs | text | JSON |
| content | text NOT NULL DEFAULT '' | append-only 累积 |
| status | text NOT NULL CHECK in 4 值 | streaming → 终态 |
| error | text | block_stop 时填 |
| created_at / updated_at | datetime | GORM 自动 |

**Message 不双写** — `messages` 表走 chat repo（`infra/store/chat/SaveMessage`，含 user_id / role / status / token 字段），块内容走 eventlog Emitter 写 `message_blocks`。两表 schema 统一后协作而非竞争（详 [`../service-design-documents/chat.md`](../service-design-documents/chat.md) §3）。

## 10. Invariants（§S21）

- `block_start.parentId` 必须先于本事件出现过（dangling = producer bug）
- `block.status` / `message.status` 单向流转 streaming → 终态
- 同 conv `seq` 严格全局单调（DB UNIQUE 强制）
- 同 block 的 deltas 按 seq append-only，前端不重写不重排
- `tool_call` block ID = LLM 自带 tc_id（不走 §S15 prefix）；其他 block ID 走 idgen `blk_`

## 11. Notifications 协议（global broadcast SSE）

与 §1-§10 的 eventlog 协议**完全独立**——共享 Bridge pattern（per-key seq + replay buffer + Last-Event-ID 重连），但 envelope shape / 演化规则 / 订阅模式不同。

### 11.1 envelope shape

```typescript
type Envelope = { seq: int64; event: Event }

type Event = {
  type: string                  // 实体种类判别字符串（开放词表）
  id: string                    // 实体 ID（type 内唯一）
  data: any                     // 实体快照 JSON（前端按 type 解释）
  conversationId?: string       // 仅 conversation-scoped 实体填（如 todo / sandbox_env）
}
```

### 11.2 现有 entity types（6 种 live）

| type | producer 位点 | 触发场景 |
|---|---|---|
| `conversation` | `app/conversation/Service.{Create,Rename,SetSystemPrompt}` 168/117/128 行；`app/chat/runner.afterStreamFinalize` 自动改名后 | 创建 / 改名 / systemPrompt 修改 / autoTitle 完成 |
| `todo` | `app/todo/Service.{Create,Update,Delete}` 经 publish helper（todo.go:249）| 任意 todo CRUD |
| `mcp_server` | `app/mcp/Service.{updateStatus,setTools}` 326/379 行 | server 连接状态 / tools 列表变化 |
| `skill` | `app/skill/Service.scan` 106 行 | fsnotify 触发 rescan 后 |
| `catalog` | `app/catalog/Service.applyRefresh` 253 行 | 1s polling 后 catalog 内容变化 |
| `sandbox_env` | `app/sandbox/Service.publishEnvUpdate` 661/682 行 | env 状态翻转（installing→ready / ready→failed / 删除）|

新增 type 字符串即可（**开放词表**——E2 演化规则）。前端不需协议升级。

### 11.3 HTTP 端点

`GET /api/v1/notifications` — 单 SSE 流，全订阅（无 query 参数）。客户端按 `event.type` / `event.conversationId` 客户端过滤分派渲染。

**Wire format（同 §N7）**：

```
event: <type>
id: <seq>
data: <event JSON, 不重复 type/seq>

```

**重连**：`Last-Event-ID: <seq>` header → server replay buffer 内 seq > N 的事件，再接实时；超 buffer → 410 Gone + `code=SEQ_TOO_OLD` → 客户端清缓存重订（无 fromSeq）+ 经 REST refetch 关心的实体。

### 11.4 Publisher API

`pkg/notifications.Publisher`（ctx-injected）：

```go
import notificationspkg "github.com/sunweilin/forgify/backend/internal/pkg/notifications"

// Service 内部消费：
notif := notificationspkg.From(ctx)  // 总返非 nil（缺失 → no-op fallback）
notif.Publish(ctx, "conversation", convID, snapshot, convID)  // 第 5 参可选 conversationID
```

ctx wiring 由 cmd/server 装配 + middleware 写 ctx；service 构造器经 `notificationspkg.From(context.Background())` 取默认 no-op fallback 用于测试。**failure log 不上抛**——通知是可观测性，不是业务。

### 11.5 与 eventlog 协议的对比

| 维度 | eventlog | notifications |
|---|---|---|
| 订阅域 | per-conversation（`?conversationId=`）| global broadcast |
| envelope | 5 封闭事件 × 6 封闭 block type | 1 通用 envelope（type 自由）|
| 路由 | `parentId` 递归（先于事件名）| 客户端按 type / conversationId 过滤 |
| 演化 | 加事件 / block type **必须**改 [`../event-log-protocol.md`](../event-log-protocol.md) | 加 type 字符串即可，无协议升级 |
| 用途 | 流式 chat 内容（含 subagent 嵌套）| entity 状态更新（CRUD / 异步进度）|
| Bridge | per-conv seq + 4096 replay buffer | global seq + replay buffer |
| Producer | 紧密耦合（5 类型固定 schema）| 松散耦合（Publisher 接受任意 type 字符串）|
| Block 类型变动 | DB CHECK + 前端 renderer 同 PR | 仅前端按 type 加 renderer |

## 12. 测试覆盖

事件协议层单测：

- `infra/eventlog/bridge_test.go` — 单调 seq / 慢订阅阻塞 / Last-Event-ID 重连 / ErrSeqTooOld
- `pkg/eventlog/eventlog_test.go` — Emitter 父链 / DB dual-write（顶层/嵌套/append/finalize/error/attrs JSON）
- `transport/httpapi/handlers/eventlog_test.go` — SSE 端到端 / Last-Event-ID / 410

> 注：`domain/eventlog/eventlog_test.go` / `infra/store/chat/block_v2_test.go` 早期文档曾计划过，未真写——`ValidateEvent` 行为由 `infra/eventlog/bridge_test.go` 在 Publish 路径覆盖；`message_blocks` CHECK / UNIQUE 约束由 `infra/db/schema_extras.go` 自动 migrate + DB 兜底。

集成端到端测试（多 producer + 真 stream）走 `backend/test/` pipeline test（§T5）。Notifications 协议层测试同样由 bridge_test 覆盖（结构一致）。
