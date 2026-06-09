---
id: WRK-001-21
type: working
status: draft
owner: @weilin
created: 2026-06-09
reviewed: 2026-06-09
review-due: 2026-09-09
audience: [human, ai]
supersedes-for-execution: [17-execution-contract]
builds-on: [20-unified-entity-workflow-model]
---
# 21 — flowrun + scheduler（持久化执行引擎 · 设计终稿）

> **本文是「workflow 怎么跑」这一块的唯一事实源**，给 M4.2 flowrun + M4.3 scheduler 立契约，供正式审核。
> 静态图模型以 `20` 为准（本文不复制 §1–§5 的实体/节点/边定义，只 import）；**执行模型层面本文取代 `17`**——`17` 是旧 backend 的事件溯源契约（event journal + generations + GORM + user_id + function-polling），用户已叫停；本文按 `20` 的 model B 干净重设计。
>
> **一句话**：一次执行 = 一个 durable 解释器照**钉死的图**走一遍，**每个节点的 result 记进一张行表（记忆化）**，崩溃后重走时 **completed 行抄结果、不重跑**。不存事件流、不重放用户代码——因为没有用户代码，只有「解释器走固定图」。

---

## 0. 决策摘要（先给结论）

> 研究闸（业界 durable engine 横扫）在 session 压缩时被杀、未出报告；架构已用户拍板锁定（2026-06-09）。下面结论给「业界定位推理」（非伪造引文），细节见对应章节。

**四个判定点**

| # | 判定 | 结论 | 一句话依据 |
|---|---|---|---|
| **①** | 核心模型：事件日志 + 完整 replay + generations（Temporal 式）vs **节点结果记忆化**（DBOS / Conductor 式） | **记忆化（B）**，删事件日志、删 generation 代数 | Forgify 是**图解释器、无用户代码可重放**；唯一状态 = 「哪些节点完成、result 是啥」——一张行表正好装下（§2） |
| **②** | join：「汇合只等被激活入边、从 branch 决策重推活跃子图」是标准还是重新发明 | **是标准**（BPMN 状态式 / Conductor decider）；且 control 严格 XOR + 并行严格 AND → 只有 AND-join 与 simple-merge、**无需 skip 信号传播**（§4.3） |
| **③** | 偶然 vs 本质复杂度 | 删分布式味（task queue / worker / sticky / sharding / lease / 14 dispatcher / generation / 事件日志）；留本质（记忆化 / record-once / 崩溃重走 / park / pin，§7） | 旧 9302 行引擎给**单进程 SQLite app** 背了一身分布式机制 |
| **④** | 漏解 / 踩坑 | 主坑 = **非幂等 activity 重跑**（at-least-once 本质，诚实标、给确定性幂等键、不假装 exactly-once）；control/approval 决策也记忆化消化重放确定性（§8） |

**两条 review 期细化（用户提）**

| 细化 | 结论 |
|---|---|
| **手动 trigger** | **v1 就做**（不延后）。建-run 原语 `StartRun` 反正 firing 路径也要，手动只是直接调它、省掉 claim；是 dogfood/测试刚需、旧 backend 本有不可倒退（§4.6） |
| **手动 payload 怎么填** | `:trigger` 的 payload **表单 schema = 入口 trigger 实体的 `Outputs`**（人渲染表单 / AI 当 tool params 同一张 schema，§4.6） |
| **agent 子步记忆化** | **v1 不做**。卡在 `loop.Run` 是流式黑盒、无 resume 入口；agent 降**粗粒度 activity**（同 action），flowrun 退成 **2 表**（删 `frs_`）。resume-mid-agent → v2 改 loop.go（§3.3 / §9） |

---

## 1. 定位与边界

### 1.1 两个模块、一个设计

| 模块 | 轮次 | 是什么 | 有实体吗 |
|---|---|---|---|
| **flowrun** | M4.2 | 一次执行的**持久化状态**：2 张表（header + 节点结果记忆化）。**真相在这里。** | 无（运行时记录，非锻造实体；无 catalog/relation/版本） |
| **scheduler** | M4.3 | **durable 解释器**：读 flowrun 行 + 钉死的图 → 推进。纯 app、无实体、~1500 行。🔴 旧引擎最大重灾区。 | 无 |

合一文：scheduler 的每个动作就是「读 frn 行 / 写 frn 行」，flowrun 的表结构就是为解释器的读写模式设计的。

### 1.2 上游已就绪（本文 import，全已落地）

- **workflow（R0047）**：`WorkflowReader`（GetActiveVersion / GetWorkflow / ListActive）、`BuildPinClosure(ctx,graph)→{entity_id:active_version_id}`、纯 helper `ValidateGraph` / `BackEdges(g)→[]Edge`。scheduler 走 **pin 的版本**（拓扑 + 引用实体版本全冻结），不碰 active 指针。
- **trigger（R0039）**：`trigger_firings`（`trf_`）durable 收件箱，persist-before-act；`triggerstore.ClaimFiring(ctx, firingID, create)` = 单事务 claim + 建 run（ADR-021，无 lease）；trigger 实体 `Outputs []schema.Field` = 它发的 payload 字段声明；`Firing.Payload map[string]any` = 实际数据。
- **control（R0045）**：`Resolve(ctx,id,versionID)→[]controldomain.Branch`（`Branch{Port,When,Emit}`）。
- **approval（R0046）**：`Resolve(ctx,id,versionID)→*approvaldomain.Version`（`{Inputs,Template,AllowReason,Timeout,TimeoutBehavior}`）+ `ParseTimeout`。
- **pkg/cel**：`ScopedEnv`（node-id 根，编译节点 Input）+ `Program.Eval(vars)→any` / `EvalBool(vars)→bool`；固定 `Compile`（`input` 根，control when/emit）；`CompileTemplate` / `Template.Render(vars)→string`（approval 模板）。
- **action 三子类**：function（R0037 `:run`）/ handler（R0038 `:call`）/ mcp（R0041 工具调用）；**agent（R0043）** `invoke` 接 `app/loop.Run`。这些经 `Dispatcher` 端口注入（§5）。

### 1.3 本文不管 / 延后

- 静态图的定义/校验/pin 闭包构建（= workflow R0047，doc 20）——本文**消费**。
- trigger 的监听 / firing 产生（= trigger R0039）——本文**消费** firing 收件箱。
- 延后 v2：见 §9。

---

## 2. 核心模型：节点结果记忆化（判定 ①）

### 2.1 两条路线

| | A：事件日志 + 完整 replay（Temporal / Cadence / Azure DTF） | B：节点结果记忆化（DBOS / Conductor / Inngest） |
|---|---|---|
| 真相 | append-only 事件流（`node_started`/`completed`/`branch_taken`/`signal_*`…） | 一张 `(run, node, iteration) → status/result` 行表 |
| 恢复 | 从头重放 history、用户代码重跑到「下一个未决」点 | 重走图、completed 行抄、未完成的才跑 |
| 为何存在 | **重建任意用户代码的内存态**（局部变量、执行指针）——只能靠重放 | 状态就是「哪些节点完成 + result」，行表直接装 |
| generations | 需要（区分同一 history 的多次 replay attempt） | 不需要（重跑 = 清 failed 行 + `replay_count++`，completed 行天然跳过） |

### 2.2 为什么 Forgify 选 B

**因为没有用户代码。** Temporal 的 history-replay 全部复杂度，是为了把一段任意用户 workflow 函数从事件日志重跑到当前位置、恢复其局部变量。Forgify 的 workflow 不是代码、是一张**声明式静态图**（doc 20）；解释器的「位置」不是某行代码，而是「哪些 (节点,轮次) 完成了」——这本身就是一张行表的内容。

doc 20 的 **model B（承重墙）** 已规定节点 Input 按 **node-id** 读祖先 result（`reviewer.score`）。「祖先 result」存哪？——`flowrun_nodes` 行里。**记忆化不是另选的实现，它就是 model B 的物理落地。** 再叠一层事件日志是冗余机器。

业界定位：**Conductor** 的 decider 正是「每个 task 完成后从已完成 task 状态重推接下来调度谁」，状态存 DB 行；**DBOS** 把每步输出 checkpoint 进 SQL 表、恢复时读 memoized output 跳过。Forgify = 「Conductor 的图解释 + DBOS 的 SQL 记忆化」。

### 2.3 三条落地结论

- 真相表 = `flowrun_nodes`（记忆化），**不是** `flowrun_events`（事件日志）→ **删 `fre_`**。
- **删 generation 代数**：重跑 = `:replay` 清 failed 行 + `replay_count++`，completed 行天然命中跳过。
- record-once = `UNIQUE(flowrun_id,node_id,iteration)` 上的 `INSERT OR IGNORE`（取代旧 `idx_fre_record_once`）；approval first-wins 由它落出（§6）。

---

## 3. flowrun 数据模型（M4.2）

**2 张表**，全 `pkg/orm` + 手写 DDL + workspace 隔离（D2）；**Log 性质严禁删除**（D1：无 `deleted_at`）。

### 3.1 `flowruns`（`fr_`）—— header

钉死的拓扑 + pin 闭包 + 状态机。

```go
type FlowRun struct {
    ID          string            `db:"id,pk"`              // fr_
    WorkspaceID string            `db:"workspace_id,ws"`
    WorkflowID  string            `db:"workflow_id"`
    VersionID   string            `db:"version_id"`         // 钉死的 wfv_（图拓扑，不随 active 漂移）
    PinnedRefs  map[string]string `db:"pinned_refs,json"`   // BuildPinClosure {entity_id: active_version_id}
    TriggerID   string            `db:"trigger_id"`         // 起点 trg_（手动 :trigger 时空）
    FiringID    string            `db:"firing_id"`          // 来源 trf_（firing 路径单事务 claim 写；手动时空）
    Status      string            `db:"status"`             // running | completed | failed
    ReplayCount int               `db:"replay_count"`       // :replay 自增；非 generation
    Error       string            `db:"error"`              // 终态 failed 的原因摘要
    StartedAt   time.Time         `db:"started_at,created"`
    CompletedAt *time.Time        `db:"completed_at"`
    UpdatedAt   time.Time         `db:"updated_at,updated"`
}
```

- **run 级状态只有 3 个**：`running | completed | failed`。**无 `parked`**——「等人」是某个 approval **节点**的状态（frn 行 status=parked），run 仍 `running`。「哪些 run 在等人」从 frn 派生查（§3.2），不在 header 冗余。
- `VersionID` + `PinnedRefs` = **确定性的两把锁**：拓扑冻结 + 引用实体版本冻结，运行中任何编辑都改不动在途 run（§6 边界一）。
- trigger payload **不存 header**——它是 trigger 节点的 result，进 frn 行，统一按 node-id 读。

### 3.2 `flowrun_nodes`（`frn_`）—— ★真相表（记忆化）

每个 (节点, 轮次) 一行，存它的 result。**这是整个引擎的真相。** 行**只写终态**（无瞬时 running 行）：action/control 在一次同步 `advance()` 内跑完即写终态；写行前崩溃 → 重走时无行 → 重跑（at-least-once，§8）。`parked` 是唯一非终态：approval 挂起前写它，决策再翻成 completed。

```go
type FlowRunNode struct {
    ID          string         `db:"id,pk"`              // frn_
    WorkspaceID string         `db:"workspace_id,ws"`
    FlowRunID   string         `db:"flowrun_id"`
    NodeID      string         `db:"node_id"`            // 图内局部 id（= doc 20 的引用名）
    Iteration   int            `db:"iteration"`          // 循环轮次，默认 0
    Kind        string         `db:"kind"`               // trigger|action|agent|control|approval
    Ref         string         `db:"ref"`                // pin 的实体 ref（审计）
    Status      string         `db:"status"`             // completed | failed | parked（无 running）
    Result      map[string]any `db:"result,json"`        // 节点 result（见下）
    Error       string         `db:"error"`
    CreatedAt   time.Time      `db:"created_at,created"` // 终态写 / park 时间
    CompletedAt *time.Time     `db:"completed_at"`       // parked 期间为 nil
    UpdatedAt   time.Time      `db:"updated_at,updated"`
}
```

**`Result` 按 kind 的形状**（= doc 20 §4 的「数据 out」）：

| kind | Result | 谁写 |
|---|---|---|
| trigger | 入口 payload（`{orderId:…}`，= firing.Payload 或手动 payload） | StartRun 启动时 seed |
| action | callable 返回（fn returnSchema / hd method 返回 / mcp tool 返回） | RunAction 完成 |
| agent | agent outputSchema 的 JSON（或自由文本 `{text:…}`） | RunAgent 完成 |
| **control** | `{port: "pass", emit: {…}}`——选中分支 + emit 求值数据 | 解释器内联求值 |
| **approval** | parked 时 `{rendered, allowReason}`（供 inbox 展示）→ 决策后 `{decision, reason}` | park 写 / 人决策或 timeout 翻 |

- **`idx_frn_once = UNIQUE(flowrun_id, node_id, iteration)`** —— record-once 键。写终态一律 `INSERT OR IGNORE`：**首写赢、后续静默忽略**。重走时 completed 行命中即跳。
- **approval first-wins**：人决策 vs timeout 竞争 → 条件 `UPDATE … WHERE status='parked'`，第一个翻成功、第二个 0 行（§6）。
- **inbox 查询**：`WHERE status='parked'`（+ workspace）= 当前所有待人审批点，直接驱动审批收件箱。**故旧 `approvals`（`apv_`）投影表删除**——parked frn 行*就是*收件箱。
- 索引：`idx_frn_once`（record-once）+ `(flowrun_id)`（重走拉全 run）+ partial `(status) WHERE status='parked'`（inbox）。

### 3.3 agent 节点 = 粗粒度 activity（v1 无子步记忆化）

agent 跑多轮 ReAct、内嵌副作用工具调用——理论上「崩溃从最后完成轮续」要给每轮记忆化（`frs_`）。**v1 不做**：卡点在 agent 自己的实现，且没有便宜的中间地带。

- **`app/loop.Run` 是流式黑盒**：只往 SSE 吐 turn（ephemeral），无 durable 逐轮 journal，更**无 resume 入口**（不能「前 N 轮已完成、从第 N+1 轮续且不重调那些工具」）。
- **要 resume = 把 ReAct loop 变成确定性重放引擎**（跳过已执行轮 + 回放工具结果）——这正是图层面刻意避开的「重放用户代码」复杂度，只不过 agent loop 真是有副作用的代码。
- **LLM 轨迹非确定**：重跑时 agent 可能调不同工具/顺序，「按位置记忆化 agent 内部工具调用」不可靠，除非逐字 pin LLM 输出回放（即上面的昂贵全量重放）。二选一，无 cheap middle。
- **建模硬伤**：子步要挂 `flowrun_node_id`，但 agent 的 frn 行 terminal-only（完成才写）——子步会逼出预分配的 running 行，破坏干净的「只写终态」模型。

**故 v1：agent = 粗粒度 activity、和 action 完全一样**——只记忆化最终 result 进 `frn`，崩溃整体重跑（at-least-once 在 agent 粒度）。代价：崩溃正好卡在 agent 中途时整体重跑（罕见；烧 token + 工具副作用重执行——靠 fn/hd 幂等键 `frn_id:node:iter` 缓解）。观测性由 agent 模块的 `agent_executions`（`agx_`，R0043）+ eventlog 覆盖。**真正的 resume-mid-agent = loop.Run 的 durable 重放改造，v2（§9）。**

### 3.4 ID 前缀变动（contract-change vs 旧 database.md §1）

| 前缀 | 旧 database.md | 新（本文） |
|---|---|---|
| `fr_` flowruns | 保留 | **保留**（重定义为记忆化 header） |
| `frn_` flowrun_nodes | 有（旧义不同） | **保留**（重定义为真相记忆化表） |
| `fre_` flowrun_events | 有（事件日志） | **删除**（无事件日志，§2） |
| `apv_` approvals | 有（parked 投影） | **删除**（parked frn 行即收件箱，§3.2） |

> `frs_` 不引入（agent 粗粒度，§3.3）。落地时同步改 `database.md` S15 + §1 Execution 段（删旧 GORM-tag 前瞻 struct，写 as-built 2 表）+ D3。见 §10。

---

## 4. scheduler 解释器（M4.3）

无实体、纯 app、~1500 行。核心是一个**幂等的「走一遍」函数**：给定 flowrun，读它所有 frn 行 + 钉死的图 → 算出哪些 (节点,轮次) ready → 跑它们 / 内联求值 → upsert frn → 直到无人 ready。崩溃后再调一次「走一遍」，completed 行天然跳过、从断点续。

### 4.1 一次「走一遍」（`advance(flowrun)`）

```
advance(fr):
  graph := WorkflowReader.GetVersion(fr.VersionID).Graph    // 钉死拓扑
  rows  := frn rows of fr                                    // 全部记忆化
  loop:
    live  := computeLiveSubgraph(graph, rows)                // §4.3：从 trigger 顺非剪边推可达 (节点,轮次)
    ready := { (node,iter) ∈ live | 所有 live 入边的源已 completed，且本行未存在 }
    if ready 空: break
    for (node,iter) in ready:        // 同批 ready 无依赖，可并发
       result/park := dispatch(node, iter, fr, rows)         // §4.2：action/agent 跑、control/approval 内联
       InsertNodeResult(...)         // INSERT OR IGNORE（first-wins）
    rows := reload                    // 新 result 进命名空间，解锁下游
  finalize(fr, rows)                  // §4.4：completed / failed / 仍 running(有 parked)
```

- **幂等**：`advance` 可重复调用任意次，结果一致（completed 行不重写、不重跑）。崩溃恢复 = 再调一次。
- **节点求值 scope**（model B）：跑 (节点 N, 轮次 k) 前，从 rows 按 node-id 取祖先 result 拼 `scope = { <祖先id>: result, ctx:{runId} }`，用 `ScopedEnv`（根=图 node-id 列表）`Eval` 每个 `node.Input[field]` → 实体 input。**循环内祖先取当前轮 result、循环外取固定 result**：实现 = 取 M 的「iteration ≤ k 中最大且存在」那行（循环内节点在 k 有行、循环外只在 0 有行，自然各取对）。

### 4.2 节点 dispatch：14 → 2 + 2 内联

旧引擎 14 个 dispatcher（function/handler/mcp/agent/llm/http/skill/tool/variable/wait/condition/approval/trigger/loop_parallel）→ **收成 2 个真 dispatch + 2 个解释器内联**：

| kind | 怎么跑 | 写什么 |
|---|---|---|
| **trigger** | 不 dispatch——StartRun 时 seed 入口 payload 为 result（§4.6） | frn(trigger)=payload |
| **action** | `Dispatcher.RunAction(ctx, ref, input)`（端口内分流 fn `:run` / hd `:call` / mcp tool） | frn(action)=返回；可选 retry（§4.2.1） |
| **agent** | `Dispatcher.RunAgent(ctx, ref, input)`（接 `app/loop.Run`，**粗粒度**：跑完整 loop 返最终 result，照常 stream 到 SSE） | frn(agent)=outputSchema JSON |
| **control** | **解释器内联**：`control.Resolve(ref, pinned)→[]Branch` → first-true-wins 求 `When`（`cel.Compile`，scope=`{input}`）→ 选 Port → 求该行 `Emit` | frn(control)=`{port, emit}` |
| **approval** | **解释器内联**：`approval.Resolve(ref, pinned)→Version` → `Template.Render({input})` → **park**（写 frn status=parked）；信号到 → 翻 `{decision,reason}` | frn(approval)=parked → completed |

- **删** `state.go`/`pause.go`（topo-walk + paused_state 旧半）、generation 代数、`LoopDispatcher`（结构化 loop 取代，§4.3）、llm/http/skill/tool/variable/wait/condition 这些**不是 doc 20 五节点**的旧 dispatcher（能力并进 action/agent，或本就不该是节点）。
- **control/approval 决策也记忆化**（写 frn 行），不是「每走一遍重算」。即便 pin 保证 CEL 不变，记账决策让重放绝对确定（§8），且 approval 人工决策本就必须落库。
- **CEL 双轨**：节点 `Input` 接线用 `ScopedEnv`（node-id 根，§4.1）；control 的 `when`/`emit` 与 approval 的 `template` 读 `input.*` → 用固定 `Compile`/`CompileTemplate`，scope = `{input: 本节点 Input 求值出的 map}`。

#### 4.2.1 action retry（平台级，非业务循环）

`node.Retry`（`RetryConfig{MaxAttempts,Backoff,DelayMs}`）= activity 级瞬时故障重试，在 `RunAction` 内消化，**不产生 frn 多行**（一个 action 节点一行，retry 是行内的事）。耗尽 retry 仍失败 → frn(action)=failed → run failed（§4.4）。业务循环（带反馈的 retry）是 control 回边，另一回事（§4.3）。

### 4.3 join + 循环：从 control 决策重推活跃子图（判定 ②）

**核心问题**：多入边的节点何时 ready？等所有入边（AND-join）还是只等被激活那条（control 下游 simple-merge）？

**答案（业界标准 = BPMN 状态式求值 / Conductor decider）**：不传播 skip 信号，而是**从已落库的 control/approval 决策重推哪些边活跃/被剪**。

```
computeLiveSubgraph(graph, rows):
  // 边 e: A --port--> B 的状态：
  //   A 是已 completed 的 control/approval 且 result.port/decision != e.FromPort  → 剪掉（dead）
  //   否则                                                                        → 在场（A 未决时暂在场）
  // 从 trigger(iter 0) 沿「未剪」边正向遍历，得 reachable 的 (节点,轮次) 集（= live）。
  //   前向边：iteration 不变；回边（BackEdges，仅 control/approval 源）：仅源 completed 且 port 命中时才走，iteration+1。
```

**readiness 规则**（统一 AND-join 与 simple-merge）：

> 节点 B（轮次 k）**ready** ⟺ (B,k) ∈ live、本行未存在，且 **B 在 k 的每条「未剪且源 live」入边的源都已 completed**。被剪入边（control 选了别的 port）排除，绝不等。

- **并行**：trigger→A、trigger→B、A→C、B→C。A、B 都 live → 都跑；C 等**两者**（AND-join）。✓
- **control XOR**：ctl 选 `pass` → ctl→`pass` 在场、ctl→`retry` 剪 → 只 pass 分支跑。✓
- **control 后汇合（simple-merge）**：ctl→P、ctl→E、P→M、E→M。ctl 选 pass → E 被剪、E∉live → E→M 排除 → M 只等 P（**绝不等被剪的 E**，否则死锁）。✓

**为什么不用 skip 传播**：旧 BPEL「dead-path elimination」往未走分支灌 false token 让 join 知道别等——有状态、易错。Forgify control 严格 XOR、并行严格 AND（无 inclusive/OR-split），「活跃集」可**纯函数地从已落库决策重推**，无需任何传播。这是 model B 的红利：决策已在 frn 行里，重推是 O(图) 纯计算。

**循环（back edge）**：`BackEdges(graph)`（workflow 已建纯函数）认出回边 `C --port--> H`（C=control/approval、H=循环头，ValidateGraph 保证可归约单入口）。C 完成且选中该 port → 回边走 → 循环体（从 H 可达且能回到 C 的节点）在 **iteration+1** 重新 ready。**回边只在源 completed + port 命中时走**（不暂在场）——否则未决控制会无限展开循环；这也使迭代数受运行时控制（`attempt<3` 那种 guard）约束。防御性加 `MaxIterations` 安全帽（撞顶 → run failed）。

### 4.4 finalize：run 终态

- **completed**：无人 ready、无 parked，且所有 live 叶子（live 中无在场出边的节点）completed。
- **failed**：某 action 耗尽 retry failed → fail-fast：run 立即 failed（已完成兄弟行保留记忆化）；`:replay` 清 failed 行重走、completed 复用（§4.8）。
- **仍 running**：无人 ready 但有 parked（approval 等人）→ `advance` 让出，等信号重驱。

### 4.5 park / resume：approval 挂起（人在环）

- **park**：解释器到 approval 节点 → `Template.Render` → 写 frn(approval) status=**parked**（`INSERT OR IGNORE`，result=`{rendered, allowReason}` 供 UI）→ `advance` 自然停在该路径（无后继在场边）。run 仍 running。
- **resume**：人决策 `POST /flowruns/{id}/approvals/{nodeId}:decide {decision,reason}` → **条件 `UPDATE … WHERE status='parked'` 翻 completed `{decision,reason}`（first-wins）** → 调 `advance(fr)` 重驱 → 激活 yes/no 出边。
- **timeout**（`apf_` 的 `Timeout`/`TimeoutBehavior`）：durable timer 的**唯一保留用途**。v1 = boot 扫描 + 轻量 ticker：parked 且超 `created_at + ParseTimeout(Timeout)` 的行，按 behavior（reject/approve/fail）走同一条件 UPDATE + `advance`。**通用 durable timer 门（任意节点 at?/after?）延后 v2**（§9）。

### 4.6 StartRun：建 run 原语 + 两个入口（手动 / firing）

建 run 的核心是一个原语 **`StartRun`**——两个入口共用，唯一区别是 firing 多一层去重 claim：

```
StartRun(ctx, workflowID, entryNode?, payload, source) → flowrunID:
  w     := WorkflowReader.GetWorkflow(workflowID)        // active? lifecycle 允许起新?
  v     := WorkflowReader.GetActiveVersion(workflowID)   // 钉死的图拓扑
  pins  := workflow.BuildPinClosure(v.Graph)             // 冻结引用实体版本（tx 外读 catalog）
  entry := entryNode ?? 图里唯一的 trigger 节点           // 多 trigger 时调用方指定
  -- 单事务 --
  建 flowruns(fr_, version_id=v.ID, pinned_refs=pins, trigger_id, firing_id, status=running)
  seed frn(entry, iteration=0, kind=trigger, result=payload)   // trigger result = 注入 payload
  -- 提交 --
  advance(fr)
```

**两个入口**：

- **手动 `:trigger`（UI/API「Run now」，v1）**：`POST /workflows/{id}:trigger {entryNode?, payload}` → 直接调 `StartRun(source=manual)`，**无 claim**（人明确点一次、没 firing 可去重）。dogfood/集成测试跑 workflow 的入口（也是 §11 测试入口），旧 backend 本有、不可倒退。
  - **payload 表单 schema = 入口 trigger 实体的 `Outputs`**：手动 fire = 你扮演本该产生 payload 的外部事件源，故按该 trigger 声明的输出字段填。**不对称**：fn `:run`←fn.Inputs、ag `:invoke`←ag.Inputs、**wf `:trigger`←入口 trigger.Outputs**（workflow 不声明 Inputs，其「输入」就是入口 trigger 的输出）。人：前端「workflow 图找 trigger 节点 → `GET /triggers/{id}` 取 Outputs」渲染表单（**现有端点够、无需新端点**）；AI：`trigger_workflow` 工具把 Outputs 当参数 schema（M7）。多 trigger 节点先选 `entryNode` 再出对应表单。**不强制校验**（同 firing payload 自由 map；Outputs 是声明/UX 便利，运行时 CEL 塑形）。
- **firing（自动，接 trigger R0039 收件箱）**：boot + ticker 排空 `trigger_firings WHERE status='pending'`（oldest-first），逐条经 `triggerstore.ClaimFiring(ctx, firingID, create)` ——一个事务内 `pending→claimed` + `create` 回调（= StartRun 的建-run 段：钉 version + pin + seed trigger 节点）+ `firing.status=started, flowrun_id=fr_…`。**claim+建 run+seed 同事务**，无 claimed-但-无-run 残留态（ADR-021）。claim 后 `advance(fr)`。
  - **overlap**：v1 实现 `serial`（同 workflow 有 running run 时新 firing 等）+ `Skip`（丢，firing.status=skipped）+ `AllowAll`（并发）。`BufferOne`/`BufferAll` 延后 v2。判定用 workflow.`Concurrency` 列（R0047 已存）。**手动 :trigger 不过 overlap 闸**（人明确要跑就跑）。

### 4.7 崩溃恢复（boot）

扫 `flowruns WHERE status='running'` → 逐个 `advance`。completed 行跳过、崩溃时正在跑的 action/agent 无终态行 → **重跑**（at-least-once，§8）、parked 行保持。无 generation、无特殊 replay 模式——恢复就是再走一遍。

### 4.8 `:replay`（失败修复）

`POST /flowruns/{id}:replay`：清掉该 run 所有 `status='failed'` 的 frn 行（`DeleteFailedNodes`，Log 表上唯一允许的物理删——failed 行是非结果）+ `replay_count++` + status 回 running → `advance(fr)`。completed 行全部复用（不重跑成功的活）、从失败点续。**取代旧 generation 自增代**——重跑不是「新代覆盖旧代」，是「清坏行重走、好行记忆化命中」。

---

## 5. DIP 端口（scheduler 依赖倒置）

scheduler 不 import 任何实体的具体 Service，全走端口（M7 装配注真、测试注 fake）：

```go
// Dispatcher —— 执行单元（action 三子类 + agent）。两者都是粗粒度 activity：跑完返最终 result，
// 崩溃整体重跑（at-least-once，§3.3 / §8）。M7 接 function/handler/mcp/agent Service。
type Dispatcher interface {
    RunAction(ctx context.Context, ref string, input map[string]any) (map[string]any, error)
    RunAgent(ctx context.Context, ref string, input map[string]any) (map[string]any, error)
}
```

已就绪、直接 import：

- `workflowapp.WorkflowReader`（读钉死的图 + active 候选集）、`workflowapp.Service.BuildPinClosure`（冻结引用版本）。
- `workflowdomain.{ValidateGraph, BackEdges, Graph, Node, Edge}`（纯函数 + 类型，运行前设闸 + 认回边）。
- `controlapp.Service.Resolve`（内联求 branches）、`approvalapp.Service.Resolve`（内联求 form）——scheduler 可定义窄端口 `ControlResolver`/`ApprovalResolver`（返 `controldomain.Branch`/`approvaldomain.Version`，DIP + 可 fake），具体 Service 结构性满足。
- `celpkg.{ScopedEnv, Program, Compile, CompileTemplate, Template}`（节点 Input / control when·emit / approval template 求值）。
- `triggerstore.ClaimFiring`（单事务 claim；scheduler 在 `create` 回调里用 `ormpkg.For[…](tx,…)` 建 flowrun + seed trigger 节点——这是 orm 唯一漏进 app 的一处，trigger Repository.go 已预期，localized 在 firing 路径）。

scheduler **暴露 `StartRun`**（建-run 原语，§4.6）：手动 `:trigger` 端点直接调、firing 路径塞进 claim 事务调——两入口一个原语。

---

## 6. 三条血泪边界（lab 点名 · 作为新测试规格）

PLAYBOOK 步骤1：旧测试/血泪换来的边界写进契约「必须保证的行为」，作新测试规格。

1. **replay 确定性**：同一 flowrun 重复 `advance`（含崩溃 boot 恢复），最终 frn 行集**逐字节一致**。机制 = ① pin 冻结拓扑+引用版本 ② control/approval 决策记忆化（不重推）③ CEL 纯（pin 的 when/emit/template 无 now()/随机）。
   - **测试**：跑到中途快照 frn → 重复 advance ×N → 断言行集不变 + 无重复副作用 dispatch。
2. **record-once（幂等）**：`UNIQUE(flowrun_id,node_id,iteration)` + `INSERT OR IGNORE`。同 (节点,轮次) 永不两行；并发/重入下首写赢。
   - **测试**：并发两次写同一 (节点,轮次) → 断言一行、第二次静默无效。
3. **approval first-wins**：人决策与 timeout 落定竞争同一 parked 行 → 条件 `UPDATE … WHERE status='parked'` first-wins，第一个定终身、第二个 0 行（不翻盘、不报错）。
   - **测试**：并发「人 approve」+「timeout reject」→ 断言只落一个 decision、run 按那个走。

---

## 7. 删什么（判定 ③：偶然复杂度）

| 删 | 为什么是偶然复杂度 |
|---|---|
| 14 dispatcher 文件分裂 | doc 20 只 5 节点 → 2 dispatch + 2 内联；llm/http/skill/tool/variable/wait/condition 不是节点 |
| `LoopDispatcher` | 结构化 loop（control 回边 + iteration）取代 |
| `state.go` / `pause.go`（topo-walk + paused_state） | 记忆化模型里「状态」就是 frn 行，无需单独 walk-state / pause-state |
| generation 代数 | Temporal-ism；记忆化重跑 = 清坏行 + replay_count |
| `flowrun_events` 事件日志（`fre_`） | 无用户代码可重放 → 事件流冗余（§2） |
| `approvals` 投影表（`apv_`） | parked frn 行即收件箱 |
| `flowrun_agent_steps`（`frs_`） | agent 降粗粒度（§3.3）；resume-mid-agent 是 v2 的 loop.go 改造 |
| 分布式机制：task queue / worker pool / sticky / sharding / 多 region / 心跳 lease / stale-claim 回收 | 单进程，无 worker fleet；claim 是单事务（ADR-021），无 lease |

留（本质复杂度）：**记忆化行表、record-once 幂等、崩溃重走、durable park（+ approval timer）、pin 版本闭包、单事务 claim。**

---

## 8. 踩坑与漏解（判定 ④）

- **非幂等 activity 重跑（主坑）**：at-least-once 是本质——action/agent 执行成功但进程在写 frn 行**之前**崩溃，重走时无终态行 → **重跑**；非幂等副作用（扣款）= 双执行。**诚实结论**：at-least-once，**不假装 exactly-once**（Temporal/DBOS 同样）。缓解：① 文档明示 action/agent 语义 = at-least-once；② `RunAction`/`RunAgent` 给 callable 传**确定性幂等键** `flowrun_id:node_id:iteration` 供其向外部去重；③ agent 同 action 粗粒度（§3.3）——收窄到「未完成轮」的 resume 要 loop.Run 改造，v2。
- **重放确定性**：control 分支选择重走时必须稳定。机制 = 决策记忆化（frn 存 `{port,emit}`，重走读账不重算）+ pin（CEL 版本冻结）+ CEL 纯。即便实体被中途编辑（pin 已挡），记账决策仍权威。
- **丢信号 / 双端点火**：approval first-wins（record-once，§6）；trigger 去重 `idx_trf_dedup`（R0039 已建）。
- **pin 闭包深度**：`BuildPinClosure` depth≤2（agent→其 fn/hd callables，agent 不能挂 agent）——R0047 已建，直接用。
- **死锁防护**：simple-merge 绝不等被剪分支（§4.3 排除 E→M）；ValidateGraph 保证可达 + 可归约回边，无非法环；`MaxIterations` 帽防失控循环。
- **孤儿 parked**：workflow 被删/版本漂移不影响在途 run（pin 冻结 + frn 是 Log 不删）；run 永远能从自己的 `VersionID`+`PinnedRefs` 自洽重走。

---

## 9. 延后 v2（明确不在 M4.2/M4.3）

- **resume-mid-agent**（agent 子步记忆化 `frs_` + `loop.Run` durable 重放改造）：v1 agent 是粗粒度 activity（§3.3）；要崩溃从 agent 中途续，需把 ReAct loop 改成确定性重放引擎（跳过已执行轮 + 回放工具结果），动 loop.go，独立一轮。卡点 = loop.Run 现是流式黑盒、无 resume 入口。
- **通用 durable timer 门**：任意节点 `at?`/`after?` 定时门（approval timeout 是其特例、v1 做）。
- **continue-as-new**：超长循环的 frn 行无限增长截断——v1 不碰。
- **overlap `BufferOne`/`BufferAll`**：v1 只 serial/Skip/AllowAll；缓冲队列语义延后。
- **catch-up / 补偿**（错过的 cron 追几次）：firing 重材化已幂等（`idx_trf_dedup`），「补几次」策略 v2。
- **`trigger_workflow` LLM 工具**（agent/chat 点火 workflow）：手动 `:trigger` 端点 v1 就做，但 LLM 工具要把 scheduler 注进 toolset，随 M7 装配。

---

## 10. 契约回写（doc-fix · 落地时同步）

落 M4.2/M4.3 代码时 1:1 同步（CLAUDE.md #9）：

- **`database.md`**：S15 删 `fre_`/`apv_`、重定义 `frn_`（**不加 frs_**）；§1 Execution 段删旧 GORM-tag 前瞻 struct（`flowrun_events`/`approvals` 含 `gorm:` tag 是旧 backend 残留），写 as-built **2 表** DDL；D3 改 `idx_frn_once`（取代 `idx_fre_record_once`）。
- **`events.md`**：`flowrun.started/completed/failed/tick` 保留（前端实时视图），校准 source 路径（旧 `scheduler/scheduler.go`·`state.go` → 新 scheduler 文件）+ tick payload（`{wfId,nodeId,status,iterKey}` → `{flowrunId,nodeId,iteration,status}`）；tick 仍 **E2 Ephemeral seq=0 不入 buffer**；三流不变（E1）。
- **`api.md`**：+ flowrun 端点（`GET /flowruns`、`GET /flowruns/{id}`、`POST /flowruns/{id}:replay`、`POST /flowruns/{id}/approvals/{nodeId}:decide`）+ **`POST /workflows/{id}:trigger`**（手动起 run，scheduler handler 挂，body `{entryNode?, payload}`；payload 形如**入口 trigger.Outputs**、表单客户端用现有端点自组装**无需新端点**；`trigger_workflow` LLM 工具随 M7）。
- **`error-codes.md`**：+ `FLOWRUN_*`（`FLOWRUN_NOT_FOUND` / `FLOWRUN_NOT_REPLAYABLE`〔非 failed 不能 replay〕/ `FLOWRUN_APPROVAL_NOT_PARKED`〔decide 输家/已决〕）。
- **`domains/flowrun.md` + `domains/scheduler.md`**：旧引擎契约，**整篇重写**为 as-built（记忆化模型、2 表、解释器算法）。
- **doc 20**：§5.3 确认 agent = 粗粒度 activity（无子步记忆化）；§6.6 执行概览的「全照 17」改为「见 doc 21」。
- **lab**：`contracts/scheduler.md`（本文的 lab 摘要版，已建）+ `contract-changes.md` #30 flowrun / #31 scheduler（落地时）+ STATE/ROUNDS/order R0048/R0049。

---

## 11. 测试计划（PLAYBOOK 步骤3）

- **flowrun（M4.2）unit/store**：**2 表** orm 往返；record-once（重复 InsertNodeResult 一行、第二次 inserted=false）；ResolveParkedNode first-wins；DeleteFailedNodes 只删 failed；Log 不可删；workspace 隔离。
- **scheduler（M4.3）—— 核心模块必须集成测试**（不能只 unit，fake Dispatcher）：
  - **走图**（run 经 `StartRun` 直接起）：线性 / 并行 AND-join / control XOR / control 后 simple-merge / 回边循环带状态（doc 20 端到端例子那张图）。
  - **三血泪边界**（§6）：replay 确定性（重复 advance 行集不变）、record-once、approval first-wins。
  - **崩溃恢复**：跑到中途丢状态（只留 frn）→ boot advance → 断言从断点续、completed 不重跑。
  - **park/resume**：approval park → decide → 续；timeout 落定。
  - **两入口**：手动 `StartRun`（无 claim 直接建 run + seed trigger）；firing→run 单事务 claim（pending→started + run 建 + trigger frn seed 原子）；overlap serial/Skip；手动不过 overlap 闸。
  - **at-least-once 诚实**：崩溃在「action 完成、写行前」→ 重跑（断言副作用计数=2，证明语义而非假装 exactly-once）。
- **fake Dispatcher / fake LLM**（T6，0 token）：action 返回固定 map、agent 返回固定 outputSchema（粗粒度，无逐轮）。

---

## 12. 业界定位附录（横向，决策导向）

| 引擎 | 核心模型 | 对 Forgify 的取舍 |
|---|---|---|
| **Temporal / Cadence** | 事件 history + 用户代码确定性 replay | **不取核心**（无用户代码可放）；取「workflow/activity 分离 + at-least-once activity + 幂等」心智 |
| **Azure Durable Functions / DTF** | 同上（orchestrator replay） | external events + durable timer 印证 §4.5 park 模型 |
| **AWS Step Functions** | 解释一张 ASL 状态机（托管服务存 per-exec 态） | **最接近**：解释声明式图、非 replay 代码 |
| **Netflix Conductor** | 声明式 JSON + **decider 从 task 状态重推调度**（FORK/JOIN/DECISION/DO_WHILE） | **核心范本**：decider = §4.3 从结果重推活跃集 |
| **DBOS Transact** | 步骤输出 checkpoint 进 SQL 表 + 幂等（workflow uuid） | **核心范本**：§3.2 记忆化行表 = DBOS 的 `(uuid,function_id)→output` |
| **Restate** | durable execution journal（轻量 replay） | 比 Temporal 轻，但仍 journal-replay；Forgify 更轻一档（无代码） |
| **Inngest / Trigger.dev / Windmill** | 步骤记忆化 + DB checkpoint | 现代主流 = 记忆化（非事件日志），印证判定 ① |
| **BPMN / van der Aalst 工作流模式** | XOR/AND/OR gateway；OR-join = synchronizing merge | §4.3：Forgify control=XOR(WCP-4)+simple-merge(WCP-5)、并行=AND(WCP-2/3)、**无 OR-split** → 比通用 OR-join 简单 |

> **一句话定位**：Forgify flowrun+scheduler = **「Step Functions / Conductor 的图解释」+「DBOS 的 SQL 步骤记忆化」**，砍掉所有为分布式 / 用户代码 replay 而生的机制。单进程 SQLite 图解释器的「最小正确」就是这张 2 表记忆化 + 一个幂等的 `advance`。
