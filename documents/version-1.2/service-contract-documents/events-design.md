# Events Design — V1.2 SSE 事件契约（递归事件日志协议）

**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../event-log-protocol.md`](../event-log-protocol.md) — 完整协议设计文档（事件流示例 / 后端架构 / migration SQL / 风险）
- **配套实现**：
  - `domain/eventlog/` — Event 接口 + 5 events + 6 block types + Bridge 接口 + ValidateEvent
  - `infra/eventlog/` — in-process Bridge（per-conv 单调 seq + 4096 replay buffer + 慢订阅者阻塞）
  - `pkg/eventlog/` — Emitter (auto-mint ID + ctx-injected) + ctx helpers
- **SSE 端点**：`GET /api/v1/eventlog?conversationId=xxx` (新)；`GET /api/v1/events?conversationId=xxx` (legacy 共存到 Phase 4 cutover)
- **历史 refetch**：`GET /api/v1/conversations/{id}/eventlog?from=<seq>` (Phase 3 — 410 Gone 时的全态刷新)

**模型**：**recursive event log**（替换 entity-snapshot 模型）。
- 5 种事件 + 6 种 block 类型 — 全部封闭枚举
- `parentId` 字段表达任意嵌套（subagent / 并行 / 嵌套 LLM 全用同一机制）
- 每事件带 per-conversation 单调 `seq`，支持 `Last-Event-ID` 重连

**遵守标准**：§E1（5 events + 6 block types 封闭枚举）/ §E2（parentId 路由，类型固定）/ §N7（SSE wire format）/ §S21（事件流 invariants）

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

**Message 不双写** — `messages` 表走 legacy chat repo 直至 Phase 4 unify。

## 10. Invariants（§S21）

- `block_start.parentId` 必须先于本事件出现过（dangling = producer bug）
- `block.status` / `message.status` 单向流转 streaming → 终态
- 同 conv `seq` 严格全局单调（DB UNIQUE 强制）
- 同 block 的 deltas 按 seq append-only，前端不重写不重排
- `tool_call` block ID = LLM 自带 tc_id（不走 §S15 prefix）；其他 block ID 走 idgen `blk_`

## 11. Legacy events 共存（Phase 1-3 dual-write）

老 `domain/events/` 6 类 entity-snapshot 事件（`chat.message` / `forge` / `conversation` / `todo` / `mcp` / `skill`）在 legacy bridge `/api/v1/events` 仍发，**不会立刻删**。Phase 4 frontend 切到新 bridge 后才能删。Producer 端：

- chat 主管线：legacy chat.message **+** 新 5 events 都推
- subagent：legacy chat.message (借 SubagentRun 壳) **+** 新 message-block + sub message_start/stop 都推
- forge / catalog / mcp / skill / todo / conversation：仍只推 legacy（**未接入新协议**——forge 用户重写后再说，其他 Phase 3+ 接）

## 12. Phase 路线（实施进度）

| Phase | 范围 | 状态 |
|---|---|---|
| 1 | Bridge / Emitter / DB schema / SSE handler / reqctx ParentBlockID | ✅ 2026-05-08 |
| 2A | chat 主管线 producer dual-write | ✅ 2026-05-08 |
| 2B | subagent 递归 emit + Emitter DB dual-write | ✅ 2026-05-08 |
| 3 | sandbox/mcp progress emit + 历史回放器 + 文档同步 | 🔄 进行中 |
| 4 | 前端 chat.js 切到新 bridge + 删 legacy events + drop subagent_runs/messages 表 | ⬜ 等 V1.2 后端期结束（CLAUDE.md §4 限制） |
| 5 | dogfood 验证 + 协议级集成测试 | ⬜ |

## 13. 测试覆盖

Phase 1-2 单测已覆盖：

- `domain/eventlog/eventlog_test.go` — ValidateEvent 各事件形状
- `infra/eventlog/bridge_test.go` (10 测) — 单调 seq / 慢订阅阻塞 / Last-Event-ID 重连 / ErrSeqTooOld
- `pkg/eventlog/eventlog_test.go` (15 测) — Emitter 父链 / DB dual-write 6 测 (顶层/嵌套/append/finalize/error/attrs JSON)
- `infra/store/chat/block_v2_test.go` (12 测) — BlockV2Store CRUD / CHECK / UNIQUE
- `transport/httpapi/handlers/eventlog_test.go` (3 测) — SSE 端到端 / Last-Event-ID / 410

集成端到端测试（多 producer + 真 stream）属 Phase 5 pipeline test 范围。
