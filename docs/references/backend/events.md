---
id: DOC-010
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# 事件 —— SSE 流挂载 / 通知类型登记

> 流式产出的单一事实源。
> 通则（E 系列）：全系统**仅三条 SSE 流**（messages / entities / notifications，E1 永不再加）；workspace 级、后端不过滤；delta/tick 标 `seq=0` ephemeral（E2）；messages 流 `parentBlockId` 嵌套（E3）。任何实体**不开新流**——只把内容挂上三条流。

## Frame 协议与 node.type 词表（非穷举）

三流共用统一帧 envelope `{seq, scope:{kind,id}, id, frame}`，`frame` 是四动词封闭联合。`durable` 报告该帧是否进 replay 环（重连可重建）；`seq=0` = ephemeral、不入 buffer、不产生背压。**durable 帧入订阅者 buffer（`bufSize+256`）；buffer 满 = 客户端卡死（durable 低频、满即真卡）→ 发布方断开该订阅者（关 `done`、幂等）、它重连并从环重放（缺口超环走 REST 重取）——绝不让一个卡死客户端永久卡住整工作区扇出 + 堆积所有 producer（R5）。**

| 动词 | durable | 说明 |
|---|---|---|
| `Open` | 恒 durable | 建节点（`parentId` 空=顶层，非空=嵌套挂载点，E3） |
| `Delta` | 恒 ephemeral | 给开着的节点追加流式 chunk（token 文本 / 终端输出） |
| `Close` | 恒 durable | 结束节点；`result` 携最终快照——流式节点的重连真相（delta 可丢） |
| `Signal` | **由 `Ephemeral` 字段定** | 不建树的点状广播；`Ephemeral` 不上线缆，仅定投递语义 |

**Signal 的 durable/ephemeral 硬规则**："DB 行才是真相、流只为实时呈现"的点状广播 MUST 置 `Ephemeral:true`：**flowrun 节点 tick**（`run`，flowrun_nodes 行是真相）、**trigger fire**（`fire`，Activation/Firing 行是真相）、**chat interaction**（broker pending 表是真相、重连走 REST 重同步）。**notifications 流上的全部信号**置 `Ephemeral:false`（durable——必达、reconnect 经 replay 环补回）。

`Node.Type` 词表由 **producer 定**（domain 不枚举类型），下表登记**当前全集**、非穷举：

| 流 | node.type 当前全集 |
|---|---|
| entities | `build`（create/edit 内容镜像）· `run`（执行中间产出 / flowrun tick，路由节点带 `port`）· `run_started`（**durable**：flowrun 出生，`{flowrunId, origin}`）· `run_terminal`（**durable**：flowrun 终态 completed/failed/cancelled）· `fire`（trigger 扇出）· `status`（ephemeral：mcp 连接态转移） |
| messages | `message`（start/stop，durable 带快照）· `text` · `reasoning` · `tool_call` · `tool_result` · `progress`（块级 open/delta/close）· `interaction`（ephemeral 信号：create + resolve 两态，resolve 帧带 `resolved:true`）· `todo`（信号）· `touchpoint`（信号） |
| notifications | node.type = 事件类型字符串 `<domain>.<action>`（见下方各域登记） |

## notifications 流（生命周期事件，`<domain>.<action>`）

**两档 durable 信号**（`notificationapp.Emitter` 分径，全部 `Ephemeral:false`）：

- **Emit = 落收件箱行 + 推帧**——值得用户事后在通知中心找到的事件（失败、AI 可能干的实体生命周期 created/edited/deleted）。行是真相、REST `GET /notifications` 兜回。
- **Broadcast = 只推帧、不落行**——高频对账回声：驱动实时 UI（rail 重排、documents 树刷新）但进收件箱即噪音（改名、pin 翻转、树保存、env 装配开始）。其真相是**实体自身状态**（消费者收帧后重取实体的 REST 行/整树，见下方各流挂载），非通知行；临时 `noti_` id 锚定线缆帧，通知中心不留痕、`GET /notifications` 里查不到。**两档帧形唯一差异 = `inbox` 标**（WRK-062 S-8）：Emit 帧的 payload 带 `inbox:true`（落行、用户相关——客户端「全部」通知档的诚实分母），Broadcast 帧**永不带**——对账回声绝不能成为 toast 候选。标只在线缆上（push 时复制 payload 加入），落库的通知行 payload 不带。N0 裁决不变：未读徽标仍绝不据帧 +1、靠权威 `unread-count` refetch。

下表 **⊞** = Emit（落行）· **⤳** = Broadcast（仅帧）。`Node.Type` 词表由 producer 定，登记当前全集、非穷举。

**payload 带实体名**：所有实体生命周期通知（function/handler/agent/workflow/control/approval 的 created/edited/reverted/updated/deleted/env_rebuilt/config_* + skill/mcp/memory 的 name + workflow 的 run_failed/attention_changed/approval_pending/lifecycle_changed）payload 都携 **`name`**（实体显示名，删除类在删前捕获、best-effort 空回退），使通知中心能渲「Agent『triager』已创建」而非仅「Agent 已创建」；sandbox env 无实体名不带；document 用 `path`。前端不产文案、按 `type → 模板` + `payload.name` 渲染。

| 域 | 事件 |
|---|---|
| function | ⊞ `function.{created, edited, reverted, updated, deleted, env_rebuilt}` |
| handler | ⊞ `handler.{created, edited, reverted, updated, deleted, env_rebuilt, config_updated, config_cleared, crashed}` · `restarted` 分径：⊞ 失败（`{ok:false}`，值得进收件箱）/ ⤳ 成功（`{ok:true}`，纯按钮回执） |

> `crashed` = 常驻进程在某次 `:call` 时被发现已死（manager 下次调用回收+重启）——让 handler 行此刻亮红点，而非等下个 :call 才暴露。payload `{handlerId, name}`。
| agent | ⊞ `agent.{created, edited, reverted, updated, deleted}` |

> `updated` = meta 变更（不升版本）；`edited` = 新版本生效。`env_rebuilt`（空 ops 的 edit 重建了 active env）只在 **function / handler** 发，agent 不发。

## entities 流挂载（实体面板实时呈现，SSE-C）

| 域 | 挂载 |
|---|---|
| function | **run 终端**：每次执行的实时 stderr（= 函数自己的 `print()`，driver 引流）→ function scope；**build 镜像**：create/edit_function 的流式 code args → 面板实时填充；**env 物化终端**：每次 ensureEnv 的尝试/修复行（不分入口——HTTP 编辑器/chat 构建/run 重建）→ build 节点 |
| handler | **run 终端**：流式 method 的每个 yield → handler scope（不论谁触发）；**build 镜像**：create/edit_handler 的类代码；**env 物化终端**：同 function |
| agent | **run 轨迹**：invoke 的完整 ReAct block 流（text/reasoning/tool_call/tool_result）→ agent scope（不论 chat/REST/workflow 触发）；**build 镜像**：create/edit_agent 的 config |

## messages 流挂载（对话内呈现）

| 域 | 挂载 |
|---|---|
| function | `run_function` tool_call 下的 progress 块 = 执行的实时 stderr；create/edit 的 env-fix 尝试逐步流出 |
| handler | `call_handler` tool_call 下的 progress 块 = 流式 method 的 yield |
| agent | `invoke_agent` tool_call 下**嵌套** agent 的全部流式 block（E3 `parentBlockId`）——仅流式呈现，耐久记录是 Execution.transcript |

## P3 五域挂载

**notifications**（全 ⊞ 落行）：workflow/control/approval 的 `<域>.{created, edited, reverted, updated, deleted}` 生命周期族；workflow 另有 `workflow.lifecycle_changed`（activate/deactivate/kill 的状态流转，payload {lifecycleState, active}）、`workflow.attention_changed`（payload {needsAttention, attentionReason}——调度器自愈语义：run 失败点亮、completed 熄灭，无 acknowledge 端点）、`workflow.run_failed`（payload {workflowId, name, flowrunId, error}）与 `workflow.approval_pending`（payload {workflowId, name, flowrunId, nodeId}，at-least-once——唤人决策）。trigger **无**生命周期通知（其活动经 activations 行 + entities 流 fire 信号呈现）。

**entities 流**：
| 域 | 挂载 |
|---|---|
| workflow | **flowrun 节点进度**：advance 每节点终态发一条 **ephemeral** Signal（`{flowrunId, nodeId, iteration, status, port?}`——`port` 仅路由节点携：control 取 result 保留键 `__port`、approval 取 `decision`[yes/no 即其 port]，客户端实时渲选中分支免逐 tick 惰性 GET）→ workflow scope；approval 越过 parked 的「已决」tick 由 DecideApproval/timeout 落定径**专发**（Advance 重入时已决行既存、computeReady 跳过、不再 tick）；flowrun_nodes 行是真相、tick 不占 replay 环（E2）。**flowrun 出生**：新 run 创建即发一条 **durable** Signal（`node.type="run_started"`，`{flowrunId, origin}`——origin=溯源章 manual/chat/cron/webhook/fsnotify/sensor）→ workflow scope——追踪「现在有什么在跑」的调度面不能漏掉断连期间出生的 run（无人看面板时的 cron 触发是常态），发点 = 两个创建咽喉（StartRun 手动径 + claimFiring 提交后）；`:replay` 重开既有 run、非出生、不发。**flowrun 终态**：run 到 completed/failed/cancelled 发一条 **durable** Signal（`node.type="run_terminal"`，`{flowrunId, status, error?}`，error 仅 failed）→ workflow scope——「run 结束了」必须活过重连（入 seq+replay 环），发点 = markRunTerminal（completed/failed/approval 超时 fail）+ kill/replace/`:cancel` 的 cancelled 写（工单②单 run 取消；**只有头守卫赢家发**——与自然终态同瞬竞态的输家不发第二帧）。build 镜像（create/edit_workflow 的图 ops） |
| trigger | **fire 信号**：每次扇出（全 4 源 + manual）发 **ephemeral** Signal `{activationId, kind, fired, firingCount, error}` → trigger scope；durable 记录 = Activation/Firing 行（信号丢弃无妨） |
| control / approval | build 镜像（create/edit 的 branches/template） |

## P4 三域挂载

**notifications**：⊞ `skill.{created,updated,deleted}` · ⊞ `mcp.{installed,updated,removed,reconnected}` 族（`reconnected` payload `{name, status, lastError?}`——成败都发，status 载 reconnect 后真实态 ready/degraded/failed，使通知中心分清恢复与仍坏）· `document`：⤳ `{created, updated, moved}`（树刷新回声，documents 消费者整树重取）/ ⊞ `deleted`（破坏性、AI 可删用户文档，值得进收件箱）。

**entities 流**：mcp = CallTool 的进度通知 tee 到 server scope 的 run 终端（per-call token 关联）+ **`status` 信号**（**ephemeral**：连接态转移 connecting→ready / ready↔degraded / →failed，发 `{status, prevStatus, lastError}` → server scope，使 MCP 行状态点实时变色；mcp_servers 行是重连真相、信号丢弃无妨，只在真变化时发，不入 buffer E2）；skill/document = build 镜像（create/edit 的 body/content）。

**messages 流**：mcp 动态工具（`mcp__*__*`）的进度作为 tool_call 下 progress 块。

## P5 对话运行时族挂载

**messages 流（主战场）**：message_start/stop（durable，close 带快照）· 块级 open/delta/close（text/reasoning/tool_call/tool_result/progress 实时流，E2 delta=ephemeral）· **interaction 信号**（ephemeral，**create + resolve 两态**——pending 时发 `humanloop.Request`，resolve 时发对称帧带 `resolved:true`[使前端清提示 + 会话 `awaitingInput`「等你」点而不靠 tool_result 反推]；broker pending 表是真相、重连走 REST 重同步）· todo 信号 · **touchpoint 信号**（durable，`node.type="touchpoint"`，scope=conversation，事件 ID=行 id `tp_`，payload=**单条聚合行视图**[幂等 upsert，重放安全]——对话触点台账的实时推送，写侧=chat Send[mentioned/attached] + loop 工具咽喉[created/edited/viewed/executed/deleted]，best-effort、漏推由 REST 兜回）· subagent 子树经 `Open.ParentID` 嵌套（E3）。

**notifications**：⤳ `conversation.{created, updated, deleted, archived, unarchived, pinned, unpinned, auto_titled, model_override, compacted}`（**全族仅帧**——对话生命周期都是 rail 对账回声，rail 收信号后重读对话自身的行；`updated` = 仅改 title/systemPrompt/attachedDocuments 的默认动作；archived/unarchived·pinned/unpinned 为 toggle 动作；`compacted` payload {coversUpToSeq, summaryBytes}——压缩器写）· `memory`：⊞ `{created, updated[内容写], deleted}` / ⤳ `updated[pin 回声]`（与内容写共用 "memory.updated" 词，档位在 setPinned 调用点选）· `sandbox.env_status_changed`：⤳ `installing`（构建开始瞬时回声）/ ⊞ `ready`·`failed`（终态）· ⤳ `sandbox.env_deleted`（env 回收内务回声）。

## P6 支撑域挂载

**notifications 流本体**：`notificationapp.Emitter` 分两档 durable 信号——**Emit** = DB 行 + 帧（scope=notification:<行 id>，node.type=事件类型；行是真相、`GET /notifications` 兜回）；**Broadcast** = 只推帧、不落行（临时 `noti_` id 锚定帧，供 rail/树对账回声，其真相是实体自身状态）。见本文「notifications 流」节两档表（⊞/⤳）。
**relation**：`relation.dependency_broken`（payload `{deletedKind, deletedId, dependents:[{kind,id,name,edge}]}`）——删一个被依赖的实体时，`PurgeEntity` 在 purge 抹边**前**快照其入向 equip/link 依赖、purge 后发 **ONE 聚合**通知点名（hydrate + 去重）这些被留下悬空挂载的实体。是 F160 瞬时 delete-tool 提示的**持久**对应物：经通知中心在任意删除路径（HTTP 或 LLM 工具）触达、跨重启留存（F161）。刻意用通知、非实体 attention 标志（agent 无 attention 列、workflow run-attention 仅在 run 完成时清会永久点亮）。无依赖 / nil emitter → 不发；hydrate/emit 失败只记录、绝不让删除失败。
**entities 流本体**：entitystream 是全部实体面板活动的唯一生产原语（open→delta*→close / Signal）。
**messages 流**：humanloop 的 interaction ephemeral 信号（chat 注入 Surface）。
