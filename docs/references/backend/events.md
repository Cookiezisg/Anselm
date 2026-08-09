---
id: DOC-010
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 事件 —— SSE 与通知登记

> 流式输出和通知事件的当前 wire contract。系统只使用 `messages`、
> `entities`、`notifications` 三条 workspace 级 SSE；任何新能力都挂到
> 其中之一。

## 1. Frame 协议

三条流共用：

```text
Envelope {
  seq,
  scope: {kind, id},
  id,
  frame
}
```

`frame` 是四动词封闭联合：

| 动词 | 耐久性 | 语义 |
|---|---|---|
| `Open` | durable | 创建节点；`parentId` 表示嵌套挂载点 |
| `Delta` | ephemeral | 向已打开节点追加文本或终端输出 |
| `Close` | durable | 关闭节点；`result` 是重连后的最终快照 |
| `Signal` | 由 `Ephemeral` 决定 | 不创建树节点的点状广播 |

ephemeral 帧使用 `seq=0`，不进入 replay ring。durable 帧使用正 seq；订阅者
buffer 满时断开该订阅者，由客户端重连重放，游标越过 ring 时以 REST 快照
恢复。

“数据库行是真相、流用于实时呈现”的点状事件必须 ephemeral，包括 flowrun
节点 tick、trigger fire、trigger/MCP 状态和 chat interaction。notifications
流上的信号均为 durable。

## 2. `node.type`

`Node.Type` 由 producer 定义，协议保持开放；下表登记当前生产者：

| 流 | 当前类型 |
|---|---|
| entities | `build` · `run` · `run_started` · `run_terminal` · `fire` · `status` |
| messages | `message` · `text` · `reasoning` · `tool_call` · `tool_result` · `progress` · `interaction` · `todo` · `touchpoint` |
| notifications | `<domain>.<action>`，见 §3 |

`message_blocks` 中的 `compaction` 与 `marker` 不产生流式节点：它们由其他
子系统在回合之间落库，随消息 REST 快照读回。`marker` 的 attrs 为
`{kind:"workdir", from, to}`。

## 3. Notifications

`notificationapp.Emitter` 提供两种 durable 投递：

- **Emit（⊞）**：写通知收件箱并推帧；payload 额外带 `inbox:true`。
- **Broadcast（⤳）**：只推帧，不写收件箱；消费者收到后重取实体真相，
  payload 不带 `inbox`。

未读数不根据帧本地累加，客户端重取 `GET /notifications/unread-count`。
实体生命周期 payload 带显示 `name`；document 使用 `path`；删除事件在删除
前捕获显示信息，取不到时允许空回退。

### 事件登记

| 域 | 事件 |
|---|---|
| function | ⊞ `function.{created, edited, reverted, updated, deleted, env_rebuilt}` |
| handler | ⊞ `handler.{created, edited, reverted, updated, deleted, env_rebuilt, config_updated, config_cleared, crashed}`；`handler.restarted` 失败 ⊞、成功 ⤳；重复清 config 的 no-op 不发 `config_cleared` |
| agent | ⊞ `agent.{created, edited, reverted, updated, deleted}` |
| workflow | ⊞ `workflow.{created, edited, reverted, updated, deleted, lifecycle_changed, attention_changed, run_failed, approval_pending}` |
| control | ⊞ `control.{created, edited, reverted, updated, deleted}` |
| approval | ⊞ `approval.{created, edited, reverted, updated, deleted}` |
| skill | ⊞ `skill.{created, updated, deleted}`；文件写删的 `updated` 另带 `path` |
| mcp | ⊞ `mcp.{installed, updated, removed, reconnected}` |
| document | ⤳ `document.{created, updated, moved}`（等值 PATCH/当前落点 move 均为 no-op，不发对应帧）；⊞ `document.deleted` |
| conversation | ⤳ `conversation.{created, updated, deleted, archived, unarchived, pinned, unpinned, auto_titled, model_override, work_dir, compacted}` |
| memory | ⊞ `memory.{created, deleted}`；内容写的 `memory.updated` 为 ⊞，pin 状态回声为 ⤳ |
| sandbox | ⤳ `sandbox.env_status_changed` 的 `installing`，⊞ `ready`/`failed`；⤳ `sandbox.env_deleted` |
| relation | ⊞ `relation.dependency_broken` |

补充 payload：

- `handler.crashed`：`{handlerId,name}`。
- `handler.restarted`：`{name,ok}`，失败可带错误信息。
- `workflow.lifecycle_changed`：`{name,lifecycleState,active}`。
- `workflow.attention_changed`：`{name,needsAttention,attentionReason}`。
- `workflow.run_failed`：`{workflowId,name,flowrunId,error}`。
- `workflow.approval_pending`：`{workflowId,name,flowrunId,nodeId}`。
- `mcp.reconnected`：`{name,status,lastError?}`。
- `conversation.compacted`：`{coversUpToSeq,summaryBytes}`。
- `relation.dependency_broken`：
  `{deletedKind,deletedId,dependents:[{kind,id,name,edge}]}`；删除前快照入向
  `equip`/`link` 依赖，删除后发送一条聚合通知。

Trigger 的 CRUD 生命周期通过 notifications durable `trigger.created`、`trigger.edited`、
`trigger.deleted` 发送，使实体 rail/detail 能回读数据库真相；其 source 活动仍由
activation/firing 记录与 entities 流呈现，Pause/Resume 只发 trigger scope 的 ephemeral `status`。

## 4. Entities 流挂载

| Scope | 类型与 payload |
|---|---|
| function | `build`：create/edit 参数与 env 物化输出；`run`：执行 stderr |
| handler | `build`：create/edit 参数与 env 物化输出；`run`：method yield |
| agent | `build`：create/edit config；`run`：invoke 的 ReAct block |
| workflow | `build`：图 ops；`run`：节点终态 `{flowrunId,nodeId,iteration,status,port?}` |
| workflow | durable `run_started`：`{flowrunId,origin?}` |
| workflow | durable `run_terminal`：`{flowrunId,status,error?}` |
| trigger | ephemeral `fire`：`{activationId,kind,fired,firingCount,error}` |
| trigger | ephemeral `status`：`{paused}`，只在 pause/resume 真转移时发 |
| trigger | notifications durable `trigger.created` / `trigger.edited` / `trigger.deleted`：`{triggerId,name?,kind?}` |
| control / approval | `build`：branches 或 template |
| mcp | `run`：CallTool progress；ephemeral `status`：`{status,prevStatus,lastError}` |
| skill / document | `build`：create/edit 内容镜像 |

Workflow `run` 的 `port` 只在 control 与 approval 节点携带。flowrun
节点 tick 以 `flowrun_nodes` 为真相；`run_started` 与 `run_terminal` 必须
durable，使调度面可跨重连观察 run 生命周期。终态竞态只由数据库头状态守卫
的赢家发 terminal。

MCP status 只在连接态真实变化时发；`mcp_servers` 行是重连真相。

## 5. Messages 流挂载

| 生产者 | 挂载 |
|---|---|
| Chat | durable message start/stop；stop 的 close result 是完整回合快照 |
| LLM loop | `text`、`reasoning`、`tool_call`、`tool_result`、`progress` |
| Function | `run_function` 下的 stderr progress；构建时 env-fix progress |
| Handler | `call_handler` 下的 method yield progress |
| Agent / Subagent | `invoke_agent` 或父工具下的嵌套 ReAct blocks，使用 `parentBlockId` |
| MCP | 动态 MCP tool call 下的 progress |
| Human loop | ephemeral `interaction`，创建与解决对称；解决帧带 `resolved:true` |
| Todo | `todo` signal |
| Touchpoint | durable `touchpoint` signal，id 为 `tp_` 行 id，payload 是聚合行快照 |

message close 快照必须自足；例如 retry 回合的 `retryOf` 同时存在于 start 和
stop，重连客户端只凭 durable close 也能恢复版本组。Interaction 的 pending
状态由 broker 持有，重连通过 REST 重同步。

Touchpoint 写入是幂等聚合；实时帧丢失时，`GET
/conversations/{conversationId}/touchpoints` 仍可恢复完整台账。
