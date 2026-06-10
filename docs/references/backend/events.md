---
id: DOC-013
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-02
review-due: 2026-09-01
audience: [human, ai]
---
# Events Design — SSE 物理发射全量契约 (100% Coverage)

> **as-built（2026-06-10 改名对账）**：SSE 三流 2026-06-03 改名 `eventlog→messages`、`forge→entities`、`notifications` 不变（CLAUDE.md E1）。**订阅端点统一在 `StreamHandler`**：`GET /api/v1/{messages,entities,notifications}/stream`——**workspace 级、后端不过滤**（始终发完整 delta，前端常驻全连 + 按对话/实体自滤）、`Last-Event-ID`/`?fromSeq` 续传、`410 SEQ_TOO_OLD`。§1 block 生命周期生产侧 ✅（`app/loop`，含 tool 中间 `progress` 块——SSE-B R0062）；§3 entities 实体活动流生产侧 ✅（forge/run/fire 三节点型——SSE-C R0063）。§2 notification 物理源路径列仍含旧 backend 残留，随覆盖阶段校准。

---

## 1. Messages 流 (`/api/v1/messages/stream`)

完整对话流，消息树实时渲染：assistant **文本** + **reasoning（thinking）** + **tool_call**（请求 / 中间过程 / result）逐 block 流式。由 `app/loop` 经 messages bus 实时推（`loop.WithBridge` 埋 ctx；tool 中间过程在 tool 内部经 ctx-bridge 自发——B 层逐 tool）。

| Event | 触发位置 | 载荷关键字段 (TS) |
|---|---|---|
| `message_start` | `chat/chat.go`, `subagent/spawn.go` | `{ id, conversationId, role, parentBlockId?, attrs }` |
| `block_start` | `chat/chat.go`, `loop/stream.go`, `loop/tools.go` | `{ id, conversationId, messageId, parentId, blockType, attrs }` |
| `block_delta` | `loop/stream.go` | `{ id, conversationId, delta }` |
| `block_stop` | `loop/stream.go`, `loop/tools.go` | `{ id, conversationId, status, error? }` |
| `message_stop` | `loop/stream.go` | `{ id, conversationId, status, inputTokens, outputTokens }` |

**BlockType 物理全集**：`text`, `reasoning`, `tool_call`, `tool_result`, `progress`, `message`, `compaction`。

**Todo 看板信号（M1.11）**：todo 写入时本流额外推一条 `signal` 帧承载任务看板快照——`scope={kind:"conversation", id:<convId>}` + `signal` + `node{type:"todo", content:{conversationId, subagentId?, todos:[{content,activeForm,status}]}}`。锚定对话（查看该对话的前端即收到）；subagent 清单的 `subagentId` 入 payload、前端据此嵌到对应子树。durable（重连 replay 最后看板态）。**写入是 LLM 专属**（`TodoWrite` 工具，波次 2/3），前端只读不写（REST 初值见 `api.md`）。

**人在环交互信号（R0064 · 内存阻塞）**：当一个工具需要人决定时——`ask_user`（agent 主动问），或一个自报 `dangerous` 的工具调用执行前的门控——该工具**就地阻塞**等用户决议（`app/humanloop` broker；非分布式 park）。阻塞瞬间本流推一条 **ephemeral** `signal`：`scope={kind:"conversation", id:<convId>}` + `signal` + `node{type:"interaction", content:{toolCallId, kind:"ask"|"danger", tool, conversationId, prompt}}`（danger 的 `prompt={summary,args}`、ask 的 `={message,options}`）。**回合不进 parked 态——message 阻塞期间一直 `streaming`**（整回合是一条连续 message，中间停一下）。前端据此渲提示（danger 批准/拒绝、ask 表单），经 `POST /conversations/{id}/interactions/{toolCallId}`（body `{action, answer?}`；action=`approve`/`approve_always`/`deny`/`accept`/`decline`）决议；被门工具醒来——approve 跑它、deny/decline 把反馈当 tool_result——续跑同一回合（**tool_result 块流入 = 决议完成**的标志）。**嵌套天然就对**：broker 经 ctx 流进 `invoke_agent` 的子 agent 运行，子运行的危险调用阻塞自然 hold 住整个调用栈，resolve 按子运行的 `toolCallId` 解阻。**signal 是 ephemeral**（不入 buffer、不 replay）；重连/刷新经 `GET /conversations/{id}/interactions` 重新同步（broker 内存 pending 表 = 真相，因这是内存阻塞、不跨重启）。`approve_always` 还会话白名单该工具（同对话后续跳过门）。

---

## 2. Notifications 流 (`/api/v1/notifications/stream` + 通知中心 REST)

**持久化通知中心**：每条通知是一个 `Notification` 实体（存 DB，见 `domains/notification.md`），由 notification 模块统一产生，关机重开仍在。任何 producer 经 `Emitter.Emit(type, payload)` 发；notification 模块存 DB + 在本流推一条 **durable signal**。

线缆形态：`scope={kind:"notification", id:"noti_x"}` + `signal` 帧 + `node{type, content}`。
- **事件类型 = `node.type` = `<域>.<动作>`**（下表 `Entity Type`.`Action`，如 `memory.updated`）；payload = `node.content`。
- **workspace 不在 scope**——它是 Bus 从 ctx 取的分流轴（前端按当前 workspace 订阅、防多窗口串台）。
- 通知中心 REST：`GET /notifications`（列表）、`/unread-count`（badge）、`PUT /{id}/read`、`POST /read-all`。
- `(Ephemeral)` 标记的（如 `flowrun.tick`）是实时进度，**不入通知中心 DB**、可丢。

| Entity Type | Action | 物理源文件（规划） | 载荷 Data (JSON) |
|---|---|---|---|
| `conversation` | `created` | `conversation.go` | `{ id }` |
| `conversation` | `deleted` | `conversation.go` | `{ id }` |
| `conversation` | `auto_title` | `conversation.go` | `{ id, title }` |
| `handler` | `config_updated` | `handler/config.go` | `{ id, status: "ok" }` |
| `function` | `version_accepted` | `function/crud.go` | `{ id, versionId }` |
| `workflow` | `version_accepted` | `workflow/crud.go` | `{ id, versionId }` |
| `flowrun` | `started` | `app/scheduler` | `{ flowrunId, workflowId, triggerId? }` |
| `flowrun` | `completed` | `app/scheduler` | `{ flowrunId, workflowId, status: "completed" }` |
| `flowrun` | `failed` | `app/scheduler` | `{ flowrunId, workflowId, status: "failed", error }` |
| `flowrun` | `tick` (Ephemeral) | `app/scheduler` | `{ flowrunId, nodeId, iteration, status }` |
| `sandbox` | `env_status_changed` | `app/sandbox` | `{ envId, status, ownerKind, ownerId, errorMsg? }` |
| `sandbox` | `env_deleted` | `app/sandbox` | `{ envId, ownerKind, ownerId }` |
| `mcp_server` | `connected` | `mcp/mcp.go` | `{ name, status: "ok" }` |
| `mcp_server` | `error` | `mcp/mcp.go` | `{ name, status: "error", lastError }` |
| `ask` | `pending` | `ask/ask.go` | `{ toolCallId, conversationId }` |
| `ask` | `resolved` | `ask/ask.go` | `{ toolCallId, status: "resolved" }` |
| `ask` | `timeout` | `ask/ask.go` | `{ toolCallId, status: "timeout" }` |
| `memory` | `created`/`updated`/`deleted` | `app/memory` | `{ name }` |
| `document` | `created`/`updated`/`moved`/`deleted` | `app/document` | `{ documentId, path, parentId? }` |
| `compaction` | `completed` | `contextmgr/compact.go` | `{ convID, coversToSeq }` |
| `skill` | `scanned` | `skill/scan.go` | `{ count }` |

---

## 3. Entities 流 (`/api/v1/entities/stream`)

**实体活动流**（SSE-C as-built R0063）：每个实体自己的活动，scope = 实体（`{kind:"function", id:"fn_x"}` 等，11 类 kind 含 control/approval/trigger），喂前端**实体面板**。三种活动 = 三种节点型（`app/entitystream` 原语统一发射；与 messages 同一信封/四动词）：

### 3.1 `forge` 节点（open → delta* → close）——锻造内容哗啦填

LLM create/edit 实体时，**loop 把该 forge tool_call 的 args delta 原样镜像到本流**（`ForgeTool` 接口自报 Kind+Op；loop 不解析 args，前端复用对话里那套 tool_call args 解析器渲染）。同一份 delta 双写：messages（对话里看代码被打出来，§1）+ 本流（实体面板那张卡实时填充）。

- scope = `{kind, <tool_call id>}`（**forge 会话**——create 时实体还没 ID；前端经流式 args 里的 `functionId` 等 + messages 的 tool_result 关联到真实体/草稿卡替换）
- `open` content = `{op: "create"|"edit"}`；`delta` = 裸 args chunk；`close.Result` = 最终完整 args（重连快照）
- **覆盖 8 实体 × create/edit = 16 工具**：fn/hd/ag/wf/ctl/apf/document/skill（mcp 不锻造，trigger 是信号源）

### 3.2 `run` 节点——运行小终端（**全 caller**：chat/REST/workflow 节点/sensor-poll）

| 实体 | 中间信息 | 产出方（与谁触发无关） |
|---|---|---|
| `function` | 函数 `print()` 输出（driver 引到 stderr）逐行 | `functionapp.SandboxAdapter.Run`（MultiWriter：messages ToolProgress + 本流） |
| `handler` | 流式 method 的 `yield` 逐条 | `handlerapp.Service.Call`（包 OnProgress 双发） |
| `agent` | **完整 ReAct 轨迹**（loop 每帧镜像，`WithRunScope`） | `agentapp.runLoop`（emitter mirror，off-chat 也流） |
| `workflow` | flowrun **节点逐个推进**（Signal：`{flowrunId, nodeId, iteration, status}`） | `scheduler.Advance` 每节点 |
| `mcp` | server 的 progress notifications 逐条 | `mcpapp.CallTool`（叠在 chat sink 上 tee） |

scope = `{kind, <实体真 id>}`；fn/hd/mcp 是 open→delta*→close（懒开，无输出不开帧），wf 是逐节点 Signal。**耐久记录在执行表**（function_executions / handler_calls / agent_executions.transcript / flowrun_nodes / **mcp_calls**〔C4 新增〕），本流是 live 视图、刷新后从 REST 重建。

### 3.3 `fire` 节点（点 Signal）——trigger 触发活动

所有 fire 路径（cron/webhook/fsnotify/sensor/manual）经 `triggerapp.fanOut` 唯一咽喉，每次扇出发一条：scope = `{trigger, trg_id}`，content = `{activationId, kind, fired, firingCount, error}`。耐久记录 = Activation/Firing 行。

> **本流 live-only 不持久化**：锻造的 durable 真相 = 实体行；运行的 = 执行表；触发的 = activation/firing 表。前端刷新走 REST，本流只管「此刻哗啦哗啦」。

---

## 4. 传输规范重申
1. **线缆分隔**：每条消息后紧跟 `\n\n`。
2. **Buffer 限制**：每 **workspace** 缓存最近 `durable` 事件（`seq > 0`，`stream.New(bufSize)`，当前 256）；续传游标越出环 → `410 SEQ_TOO_OLD`，客户端重取历史后重连。
3. **Tick 吞吐**：`ephemeral` (seq=0) 消息不进入 Buffer，高频发射（最高 100Hz），前端应使用 `requestAnimationFrame` 节流。
