# 11 — 全链路改造盘点

脑爆结论笔记(2026-05-29)。

依赖:00-10 全部子设计。

> **核心提醒**:00-10 定的新设计要"全链路通"。按需加载 / prompt 系统 / catalog / 锻造工具 / lifecycle / SSE / DB schema 等链路都得跟着改一遍。本 doc 盘点每条链路的现状、改动、依赖顺序 — 改完才能 demo 闭环。

---

## 一图速览

| # | 链路 | 现状 | 改动 | 阻塞性 |
|---|---|---|---|---|
| 1 | Lazy/Resident Toolset | 6 lazy group | 加 `agent` 第 7 组 | 🔴 强 |
| 2 | Forge 教学 prompt | runner.go `categoryLabels` 6 项 | 加 agent 标签 + 改 quadrinity 措辞 | 🔴 强 |
| 3 | Catalog source 注册 | 6 readers | 加 agent reader + function kind 字段 | 🔴 强 |
| 4 | search 工具 kind 过滤 | 无 kind 概念 | search_functions 加 `kind?` 参数,按上下文默认 | 🟡 中 |
| 5 | Agent forge domain | 不存在 | 全新 domain(详 09)+ 11 锻造工具 | 🔴 强 |
| 6 | Function `kind` 字段 | 无 | version 级 enum (normal/polling) + capability check | 🔴 强 |
| 7 | Workflow.active 字段 | 仅 `active_version_id` | 加 `active bool` 列 + 6 字段 | 🔴 强 |
| 8 | trigger_workflow 工具签名 | hardcoded `"manual"` | 必填 `triggerNodeId` | 🔴 强 |
| 9 | activate/deactivate 工具 + HTTP action | 不存在 | 新增 2 工具 + 2 HTTP action | 🔴 强 |
| 10 | AcceptPending 联动 | 改 active_version_id 完事 | 加:active workflow 撤旧 listener + 重 register | 🔴 强 |
| 11 | RehydrateOnBoot 扩展 | 只扫 paused flowrun | 加:扫 `active=true` workflow 重 register listener | 🔴 强 |
| 12 | Trigger Service onFire | `isFromListener` 概念不存在 | 调 `StartRun(..., isFromListener=true)` | 🔴 强 |
| 13 | Handler instance Owner 双模 | 已有 `Owner{Kind, ID}` ✅ | 调用方按 `IsFromListener` 拍 Kind | 🟢 弱(infra 已就绪) |
| 14 | FlowRun 字段扩展 | 无 `trigger_node_id` / `is_from_listener` | 加 2 列 | 🔴 强 |
| 15 | Message queue infra | 不存在 | 全新 `infra/messagequeue/` ~300 行(详 00 段) | 🔴 强 |
| 16 | 节点执行模型 | `driveLoop` 拓扑驱动 | message queue 驱动 + 5 节点 actor | 🔴 强 |
| 17 | SSE forge 协议 | 3 kind(function/handler/workflow) | 加 agent kind = 4 kind | 🟡 中 |
| 18 | events / dead-letter API | 不存在 | 新 `GET /events?type=...` + dead_letter store | 🔴 强(配 5 错诊工具) |
| 19 | flowrun-trace SSE / API | 不存在 | 新增 get_flowrun_trace / nodes 数据源 | 🟡 中 |
| 20 | 前端 WorkflowEditor 节点面板 | 14 节点 | 5 节点 + 滴答可视化(详 08) | 🟡 中 |

---

## 详细盘点(按依赖顺序)

### A. 底盘:DB schema + 新 entity

**A1. Workflow / FlowRun 字段扩展**

```sql
ALTER TABLE workflows ADD COLUMN active BOOL DEFAULT 0;
ALTER TABLE flowruns ADD COLUMN trigger_node_id TEXT;
ALTER TABLE flowruns ADD COLUMN is_from_listener BOOL DEFAULT 0;
```

`internal/domain/workflow/workflow.go` + `internal/domain/flowrun/flowrun.go` 加字段。

**A2. Function `kind` 字段(version 级)**

```sql
ALTER TABLE function_versions ADD COLUMN kind TEXT DEFAULT 'normal';
ALTER TABLE function_versions ADD COLUMN polling_interval TEXT;   -- duration string
```

DB CHECK `kind IN ('normal', 'polling')`(D3:稳定白名单)。

**A3. Agent forge domain 全新**(详 [09-agent-domain.md](./09-agent-domain.md))

- `internal/domain/agent/` 新建(entity + version + execution)
- `internal/app/agent/` 新建(service: CRUD + accept + revert + run)
- `internal/infra/store/agent/` 新建
- 路由 `/api/v1/agents`(对齐 functions / handlers)
- ID 前缀:`ag_` / `agv_` / `agx_`

**A4. Message Queue infra 全新**(详 [00-overview.md](./00-overview.md) 段)

- `internal/infra/messagequeue/` 新建 ~300 行
- `messages` 表 schema 已草拟
- App 层 API:`Enqueue` / `Dequeue` / `History` / `Trace`

**A5. Dead letter store 全新**

- `internal/infra/deadletter/` 或并入 `messagequeue`(consumed_at NOT NULL + processed_at NULL = 死信半完成)
- 复用 `messages` 表即可,不开新表;查询 view 过滤即可

---

### B. 锻造工具 + 教学 prompt

**B1. Agent 11 锻造工具**(详 [09](./09-agent-domain.md) + [10](./10-ai-tool-inventory.md))

`internal/app/tool/agent/` 新建 11 个 tool 文件:`search.go` / `get.go` / `get_versions.go` / `create.go` / `edit.go` / `accept.go` / `revert.go` / `delete.go` / `run.go` / `search_executions.go` / `get_execution.go`。

**B2. Function 工具加 `kind` 参数**

- `create_function`:必填 `kind: "normal" | "polling"`,polling 时必填 `pollingInterval`
- `edit_function`:ops 数组支持 `update_kind` / `update_polling_interval`
- `run_function`:kind=polling 时平台模拟 `lastCursor` 试跑
- `search_functions`:加 `kind?` 过滤,**按上下文默认**(配 tool 节点 → kind=normal;配 polling trigger → kind=polling)

**B3. Workflow lifecycle 3 工具**

- `activate_workflow(id)`:`internal/app/tool/workflow/activate.go` 新建
- `deactivate_workflow(id)`:同上
- `trigger_workflow(id, triggerNodeId, payload)`:**改造现有** `internal/app/tool/workflow/trigger.go`(签名加 `triggerNodeId` 必填)

**B4. 运行时观察 5 工具**

`internal/app/tool/workflow/` 加 `search_flowruns.go`(已有重构)/ `get_flowrun.go`(已有)/ `get_flowrun_trace.go` 新建 / `get_flowrun_nodes.go` 新建 / `cancel_flowrun.go` 新建。

**B5. 错误诊断 5 工具(全新)**

`internal/app/tool/diagnosis/`(新子包 — §S12 允许 `app/tool/` 下按家族嵌套):`query_events.go` / `list_dead_letters.go` / `get_dead_letter.go` / `replay_message.go` / `clear_dead_letters.go`。

**B6. Forge 教学 prompt 改 4 处**

`internal/app/chat/runner.go`:

- `categoryLabels` map:加 `"agent": "agent (LLM ReAct loop configuration)"`
- `toolsSection` const:把"6 lazy groups"改"7 lazy groups",列举里加 agent
- `identitySection` / `howToWorkSection`:trinity → quadrinity,加员工思维 / 永远 prod / 能力源自 forge 三条总纲(详 00)
- 新加 "polling cursor 模板" 段(高风险工具 LLM 兜底,详 [10](./10-ai-tool-inventory.md))

---

### C. Toolset 装配 + Resident/Lazy 划分

**C1. `toolapp.Toolset` Lazy 加第 7 组**

`backend/cmd/server/main.go` `lazyGroups` 加 `agent` category。

**Resident vs Lazy 划分提案**(全 89 工具):

| 分类 | 工具数 | Resident? | Lazy 组 |
|---|---|---|---|
| 主对话基础(file/shell/web/task/ask) | ~14 | ✅ | — |
| activate_tools(meta) | 1 | ✅ | — |
| Forge function | 11 | ❌ | `function` |
| Forge handler | 12 | ❌ | `handler` |
| Forge agent(新) | 11 | ❌ | `agent`(新) |
| Forge workflow | 9 | ❌ | `workflow` |
| Workflow lifecycle(activate/deactivate/trigger) | 3 | ❌ | `workflow`(并入) |
| 运行时观察 | 5 | ❌ | `workflow`(并入) |
| 错误诊断 | 5 | ❌ | `workflow`(并入,**workflow 组膨胀到 ~22 工具**) |
| MCP | 5 | ❌ | `mcp` |
| Document | 7 | ❌ | `document` |
| Skill | 3 | ❌ | `skill` |
| Memory | 3 | ✅(跨对话基础) | — |

**结论 7 个 lazy group**:function / handler / agent / workflow(膨胀) / mcp / document / skill。

`activate_tools` enum 加 `agent` 候选。

**C2. `host.Tools(ctx)` 无改**(逻辑通用)

---

### D. Lifecycle hooks 联动

**D1. AcceptPending 联动**(详 [06-workflow-lifecycle.md](./06-workflow-lifecycle.md))

`internal/app/workflow/crud.go` 末尾加:

```go
if workflow.Active {
    triggerService.UnregisterByWorkflow(id)
    handlerRegistry.DestroyOwner(Owner{Kind: "workflow", ID: id})
    // 重做 activate 流程
    scanGraphAndRegister(...)
}
```

**D2. RehydrateOnBoot 扩展**

`internal/app/scheduler/rehydrate.go`:

```go
// 新加:
for _, wf := range listActiveWorkflows() {
    redoActivate(wf)
}
```

**D3. Trigger Service `onFire` 改**

`internal/app/trigger/trigger.go`:

```go
// 改:onFire 调度时
scheduler.StartRun(workflowID, nodeID, payload, isFromListener=true)
```

**D4. Handler instance Owner 调用方**

`internal/infra/handler/dispatch_handler.go`:根据 `flowrun.IsFromListener` 拍 Owner:

```go
var owner handler.Owner
if flowrun.IsFromListener {
    owner = handler.Owner{Kind: "workflow", ID: flowrun.WorkflowID}
} else {
    owner = handler.Owner{Kind: "flowrun", ID: flowrun.ID}
}
inst := handlerRegistry.Acquire(ctx, owner, name, spawnFn)
```

(底层 registry 已支持双模 ✅,只是调用方现状全用 flowrun 模式。)

---

### E. Trigger 节点 + Polling

**E1. Polling kind=polling function 系统**(详 [01-triggers.md](./01-triggers.md))

- Trigger Service 加 polling listener(新 `internal/infra/trigger/polling/`)
- polling listener tick interval = function.pollingInterval
- 平台持久化 cursor:`polling_states (workflow_id, node_id, cursor TEXT, last_fire DATETIME)`
- 失败 retry 用尽 → workflow.active=false + SSE 通知(详 [07](./07-error-handling.md))

**E2. Trigger 节点 payloadSchema**(详 [01](./01-triggers.md))

- 节点 config 加 `payloadSchema` JSON schema 字段
- listener 类型节点的 payloadSchema 由 kind 固定(cron `{firedAt}` / webhook `{method, headers, body}` 等)
- manual 节点的 payloadSchema 编排者拍

**E3. Capability check on accept**

`internal/app/workflow/crud.go` `:accept` 前:

- 扫 trigger 节点的 callable ref(polling 引用的 fn_xxx)
- 拉 ref 的 active version
- 若 trigger 节点要求 kind=polling 但 active=normal → accept 失败 / 标 needs_attention

---

### F. Catalog + 能力披露

**F1. Catalog source 注册**

`backend/cmd/server/main.go` `catalog.RegisterSource` 加 agent reader(对齐 function/handler reader 接口)。

**F2. Function reader kind 字段透出**

`internal/app/function/catalog_source.go`:在 catalog 项里加 `kind` 字段(让 LLM `search_functions` 看到 normal 还是 polling)。

**F3. Workflow trigger 节点暴露**

`get_workflow(id)` 返回时,把 trigger 节点 list(`{nodeId, kind, payloadSchema}`)显式拎出来,**方便 LLM 调 `trigger_workflow` 时填 triggerNodeId**。

---

### G. SSE + 协议

**G1. forge SSE 第 4 kind = agent**

`internal/infra/forge/bridge.go` + `infra/forge/protocol.go`:加 `agent` 到 kind 枚举。

**G2. eventlog SSE 不动**(消息流 = 主对话 block,与新 domain agent 锻造对齐 chat 既有 5 events × 7 block types)。

**G3. notifications SSE 加新 type**

- `workflow_activated` / `workflow_deactivated` / `flowrun_started` / `flowrun_completed` / `flowrun_failed` / `trigger_exhausted` / `handler_crash` / `dead_letter_created`
- 协议是开放词表(E2),加字符串即可

**G4. flowrun-progress SSE 流(新)**

用于 UI 实时画布滴答:每节点状态变化推一条 lightweight notification。

- 可考虑并入 notifications SSE(不开第 4 条 — E1 铁律:上限 3 条)
- 或作为 notifications 的子 type

**结论:不开第 4 条 SSE,flowrun-progress 并入 notifications**。

---

### H. 节点执行引擎

**H1. driveLoop → message-queue-driven**(详 [00-overview.md](./00-overview.md) 段)

`internal/app/scheduler/`:从拓扑驱动重构为 message queue 驱动。

- 节点 = actor
- 每节点:从入口 queue dequeue → 跑 → emit 下游 queues
- case 回边 = 复制消息进上游 queue
- 终止条件:无新消息 / workflow timeout / 用户 cancel

**这是最大单点改造,~1500-2500 行**。

**H2. 5 节点 actor 实现**

- `trigger`:emit 首条消息
- `agent`:调 agent domain `Run(prompt, tools, knowledge, model)`(详 [02](./02-agent-node.md) + [09](./09-agent-domain.md))
- `tool`:解 ref → 调 callable → emit 结果
- `case`:eval CEL → emit 选 branch
- `approval`:emit pause + 注册 cancel handle

---

## 改造顺序(因果链)

按依赖严格顺序,7 大块:

```
块 1: DB schema 改完(A1 + A2 + A7 + Agent domain A3)— 1.5 天
   ↓ (entity + 数据底盘)
块 2: Agent domain + 11 锻造工具(B1)— 2 天
   ↓ (forge entity 就位,跟 function/handler 同 lift)
块 3: Message queue infra(A4 + A5)— 1.5 天
   ↓ (新执行模型底盘)
块 4: 节点执行引擎重构 driveLoop(H1 + H2)— 3-4 天
   ↓ (最大单点,核心)
块 5: Lifecycle(activate/deactivate/trigger 工具 + AcceptPending + RehydrateOnBoot)— 2 天
   ↓ (上线 / 触发抽象)
块 6: Polling 系统 + capability check(E1 + E3)— 1.5 天
   ↓ (trigger 体系闭环)
块 7: 运行时观察 + 错诊工具(B4 + B5)+ 教学 prompt 全改(B6)+ catalog(F1-F3)+ toolset(C1)+ SSE(G1-G4)— 2 天
   ↓ (AI 工程师能用)

总:13-14 天纯写,加测试 ~18-20 天
```

**前端 WorkflowEditor 改造**(详 [08-orchestration-ui.md](./08-orchestration-ui.md))平行块 4 后开工 — 2-3 天。

---

## 闭环验收(全链路通的判据)

| 场景 | 必须通 |
|---|---|
| **AI 锻造 agent**:`create_agent` → `accept_pending_agent` → `run_agent` 试跑 | ✅ Agent forge 通 |
| **AI 造 polling**:`create_function(kind=polling)` → workflow 引用 → `activate` → cursor 持久化 + 真触发 | ✅ Polling 闭环通 |
| **AI 编排 + 试跑**:`create_workflow` + 几个节点 → `trigger_workflow(wf, manualNode, payload)` 跑通 | ✅ 编排核心通 |
| **AI 上线**:`activate_workflow` → cron 自动触发 → listener 复用 handler instance | ✅ Lifecycle 通 |
| **跨触发 state**:active workflow 内 cron 跑 N 次,handler counter 累积(同 instance) | ✅ Owner 模型通 |
| **改 entity 自动跟新**:edit_function → accept → 所有 workflow 引用自动用新版 | ✅ 永远 prod 通 |
| **trigger 用尽 inactive**:polling 跑挂 → retry 用尽 → workflow.active=false + 通知 | ✅ 错诊 + lifecycle 联动通 |
| **死信 replay**:handler crash → 死信入库 → AI 调 `replay_message` 重跑 | ✅ 错诊 + msg queue 通 |
| **boot 恢复**:Forgify 重启 → active workflow 自动重 register listener | ✅ Rehydrate 通 |
| **AI 反馈循环**:用户"跑一下" → AI 发现缺 manual 节点 → edit_workflow 加 → trigger 成功 | ✅ chat/workflow 互通,产品 narrative 落地 |

每个场景都过 = 全链路通 = demo 可以摆。

---

## 风险点(改造期间踩坑预警)

| 风险 | 触发场景 | 缓解 |
|---|---|---|
| **driveLoop 重写阻塞太久** | 块 4 ~3-4 天纯改写,影响并发其他块 | 块 1-3 + 块 5-7 都可平行;块 4 单独排长档期 |
| **AcceptPending 联动漏点** | active workflow 改 version 时旧 listener 没撤干净,出"幽灵触发" | 联动写完单独 E2E:edit + accept + 校验旧 listener 不再 fire |
| **Polling cursor race** | LLM 写的 polling function 漏存 cursor / 重复触发(详 [10](./10-ai-tool-inventory.md) 🔴 风险) | 教学 prompt 强约束 + 提供 cursor 模板库 |
| **Handler Owner 切换边界** | flowrun 转 listener-触发时,Owner 拍错 → state 隔离不对 | 单测 `IsFromListener` 决策路径每条 |
| **Message queue retention** | 平台不设默认 → 用户/AI 忘配 → 表无限膨胀 | 编排器 / chat agent 主动提醒 + UI 默认提示 |
| **agent 节点空 tool 退化 single-shot** | 节点配错或 LLM 忘挂 tool → 默认变 LLM 一发(详 02) | run_agent 试跑时返回 tokens / tool calls count,LLM 能自检 |

---

## 砍掉 / 已确认无需动的

| 项目 | 理由 |
|---|---|
| Variable 节点 / 全局状态 | 砍(00 列表) |
| Loop 节点 | 砍(case 回边代替) |
| Parallel 节点 | 砍(图里平行边自然并发) |
| Wait 节点 | 砍(scheduledAt metadata 代替) |
| HTTP 节点 | 砍(forge function 包装) |
| LLM 节点 | 砍(agent 节点空 tool 退化) |
| Skill 节点 | 砍(agent 挂载) |
| `domain/events` 包 | 已删(CLAUDE.md 已注明) |
| Handler instance registry 双模 | infra 已支持 `Owner{Kind, ID}`,调用方拍 Kind 即可 |
| Subagent 数据表 | 已统一进 messages 行(attrs.kind=subagent_run),不动 |
| Sandbox v2 | 已就绪(CLAUDE.md),agent 跑也走它 |
| eventlog SSE 协议 | 5 events × 7 block types 不动(agent 跑也走它,作为 message 流的特殊形态) |

---

## 待用户确认

1. **agent 节点试跑能力**:`run_agent` 试跑直接调真 LLM 烧 token,还是支持 mock LLM 试跑?
2. **错诊工具 Resident 还是 Lazy**:本 doc 提议并入 `workflow` lazy 组,LLM 处理 workflow 问题时 activate workflow 组就全有。是否合理?
3. **flowrun-progress 流**:并入 notifications SSE(不开第 4 条),还是定独立 subprotocol(notifications 内部的"progress"子 type)?
4. **polling listener tick 实现**:Forgify 主进程内启 N 个 goroutine 各管一个 polling trigger,还是统一 ticker 调度器?(N 多时影响)
