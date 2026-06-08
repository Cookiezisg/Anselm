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
# 21 — flowrun + scheduler（持久化执行引擎 · 终稿设计）

> **本文是「workflow 怎么跑」这一块的唯一事实源**，给 M4.2 flowrun + M4.3 scheduler 立契约，供正式审核。
> 静态图模型以 `20` 为准（本文不复制 §1–§5 的实体/节点/边定义）；执行模型层面**本文取代 `17`**——`17` 是旧 backend 的事件溯源契约（event journal + generations + function-polling + GORM + user_id），用户明确叫停，本文按 `20` 的 model B 干净重设计。
>
> **一句话**：一次执行 = 一个 durable 解释器照**钉死的图**走一遍，**每个节点的 result 记进一张行表（记忆化）**，崩溃后重走时**已完成的行抄结果、不重跑**。不存事件流，不重放用户代码——因为根本没有用户代码，只有「解释器走固定图」。

---

## 0. 四个判定点（决策摘要 · 先给结论）

研究闸（业界 durable engine 横扫）在压缩时被杀，未出报告；架构已经用户拍板锁定（2026-06-09）。下面四条结论给出**业界定位推理**（非伪造引文），细节在 §2/§4.3/§7/§8 展开。

| # | 判定 | 结论 | 一句话依据 |
|---|---|---|---|
| **①** | 核心模型：事件日志 + 完整 replay + generations（Temporal 式）vs **节点结果记忆化**（DBOS/Conductor 式） | **记忆化（B）**。删事件日志、删 generation 代数。 | Forgify 是**图解释器、无用户代码可重放**；唯一状态 = 「哪些节点完成了、result 是啥」——一张行表正好装得下。事件日志是为「从 log 重建任意用户代码的内存态」设计的，Forgify 没那个东西。 |
| **②** | join：「汇合只等被激活入边、从 branch 决策重推活跃子图」是标准还是重新发明 | **是标准**（BPMN 状态式 OR-join / Conductor decider 模型）。且 Forgify 的 control 是**严格 XOR**、并行是**严格 AND**，比 BPMN 通用 OR-join 还简单——只有「AND-join（并行）」和「simple-merge（control 下游单分支）」两种，**无需 skip 信号传播**。 |
| **③** | 偶然 vs 本质复杂度 | 删（偶然·分布式味）：task queue / worker pool / sticky / sharding / 多 region / 心跳 lease / stale-claim 回收 / 14 dispatcher 分裂 / generation 代数 / 事件日志。留（本质）：记忆化、record-once 幂等、崩溃重走、durable park、pin 版本闭包。 | 旧 9302 行引擎给**单进程 SQLite app** 背了一身分布式机制。 |
| **④** | 漏解 / 踩坑 | 主坑 = **非幂等 activity 重跑**（at-least-once 本质）；诚实标 at-least-once + 给 fn/hd 传确定性幂等键，不假装 exactly-once。control/approval 决策也**记忆化**（不每走一遍重推），消化重放确定性。approval first-wins / trigger 去重已由 record-once / `idx_trf_dedup` 覆盖。 | 见 §8。 |

---

## 1. 定位与边界

### 1.1 两个东西，一个设计

| 模块 | 轮次 | 是什么 | 有实体吗 |
|---|---|---|---|
| **flowrun** | M4.2 | 一次执行的**持久化状态**：3 张表（header + 节点结果记忆化 + agent 子步）。**真相在这里。** | 无（运行时记录，非锻造实体；无 catalog/relation） |
| **scheduler** | M4.3 | **durable 解释器**：读 flowrun 行 + 钉死的图 → 推进。纯 app、无实体、~1500 行。🔴 旧引擎最大重灾区。 | 无 |

它们是一体设计：scheduler 的每个动作就是「读 frn 行 / 写 frn 行」，flowrun 的表结构就是为解释器的读写模式设计的。故合一文。

### 1.2 上游已就绪（本文 import 的东西，全已落地）

- **workflow（R0047）**：`WorkflowReader`（GetActiveVersion/GetWorkflow/ListActive）、`BuildPinClosure(ctx,graph)→{entity_id:active_version_id}`、纯 helper `ValidateGraph` / `BackEdges(g)→[]Edge`。scheduler 走的是 **pin 的版本**（图拓扑 + 引用实体版本全冻结），不碰 active 指针。
- **trigger（R0039）**：`trigger_firings`（`trf_`）durable 收件箱，persist-before-act，`Status: pending→claimed→started→{skipped,superseded,shed}`，`idx_trf_dedup = UNIQUE(workflow_id,trigger_id,dedup_key)`。scheduler 排空 pending、**单事务 claim**（ADR-021，无 lease）。
- **control（R0045）**：`Resolve(ctx,id,versionID)→[]controldomain.Branch`（`Branch{Port,When,Emit}`）。
- **approval（R0046）**：`Resolve(ctx,id,versionID)→*approvaldomain.Version`（`{Inputs,Template,AllowReason,Timeout,TimeoutBehavior}`）+ `ParseTimeout`。
- **pkg/cel**：`ScopedEnv`（node-id 根，编译节点 Input）；`Program.Eval(vars)→any` / `EvalBool(vars)→bool`；`CompileTemplate` / `Template.Render(vars)→string`（approval 模板）。
- **action 三子类**：function（R0037 `:run`）、handler（R0038 `:call`）、mcp（R0041 工具调用）。**agent（R0043）** `invoke` 接 `app/loop.Run`。这些是 scheduler 经 `Dispatcher` 端口注入的执行单元（§5）。

### 1.3 本文不管什么

- 静态图的定义、校验、pin 闭包构建（= workflow R0047，doc 20）。本文**消费**它们。
- trigger 的监听 / firing 产生（= trigger R0039）。本文**消费** firing 收件箱。
- workflow → trigger 的 Attach/Detach 引用计数（trigger 已建引用计数生命周期；workflow 侧的 `:activate` 触发 Attach 是 M4.3 接线的一小步，§5.4）。
- continue-as-new / durable timer 通用门 / overlap BufferOne·BufferAll（延后 v2，§9）。

---

## 2. 核心模型：节点结果记忆化（判定 ①）

### 2.1 两条路线

| | A：事件日志 + 完整 replay（Temporal / Cadence / Azure DTF） | B：节点结果记忆化（DBOS Transact / Netflix Conductor / Inngest） |
|---|---|---|
| 真相 | append-only 事件流（`node_started`/`node_completed`/`branch_taken`/`signal_*` …） | 一张 `(run, node, iteration) → status/result` 行表 |
| 恢复 | 从头重放整条 history、用户代码重新执行到「下一个未决」点 | 重走图、completed 行直接抄、未完成的才跑 |
| 为什么存在 | **重建任意用户代码的内存态**（局部变量、执行位置）——只能靠重放 | 状态就是「哪些节点完成 + result」，行表直接装 |
| generations | 需要（区分同一 history 的多次 replay attempt） | 不需要（重跑 = 清 failed 行 + `replay_count++`，completed 行天然跳过） |

### 2.2 为什么 Forgify 选 B

**因为 Forgify 没有用户代码。** Temporal 的 history-replay 全部复杂度，是为了「把一段任意 Go/Java/TS workflow 函数，从事件日志重新跑到当前位置、恢复它的局部变量和执行指针」。Forgify 的 workflow 不是代码，是**一张声明式静态图**（doc 20）；解释器走图的「位置」不是某行代码，而是「哪些 (节点,轮次) 完成了」——这本身就是一张行表的内容。

doc 20 的 **model B（承重墙）** 已经规定：节点 Input 按 **node-id** 读祖先 result（`reviewer.score`）。那么「祖先 result」存在哪？——存在 `flowrun_nodes` 行里。**记忆化不是另选的实现，它就是 model B 的物理落地。** 再叠一层事件日志是冗余机器。

业界定位：**Netflix Conductor** 的 "decider" 正是这个模型——每个 task 完成后，decider 从已完成 task 的状态**重新推导**workflow 接下来该调度谁，状态存 DB 行、非事件流。**DBOS Transact** 把每步输出 checkpoint 进 SQL 表（`(workflow_uuid, function_id)→output`），恢复时已完成步骤读 memoized output 跳过。Forgify = 「Conductor 的图解释 + DBOS 的 SQL 记忆化」，两者都不用事件日志。

### 2.3 结论

- **真相表 = `flowrun_nodes`（记忆化），不是 `flowrun_events`（事件日志）。删 `fre_`。**
- **删 generation 代数。** 重跑语义 = `:replay` 清掉 failed 行 + flowrun.`replay_count++`，重走时 completed 行天然命中跳过。
- **record-once = `UNIQUE(flowrun_id,node_id,iteration)` 上的 `INSERT OR IGNORE` / upsert-first-wins**（取代旧 `idx_fre_record_once` 的部分唯一）。approval first-wins 直接由它落出（§6）。

---

## 3. flowrun 数据模型（M4.2）

3 张表，全 `pkg/orm`、手写 DDL、workspace 隔离（D2）、**Log 性质严禁删除**（D1：无 `deleted_at`）。

### 3.1 `flowruns`（`fr_`）—— header

一次执行的头：钉死的拓扑 + pin 闭包 + 状态机。

```go
type FlowRun struct {
    ID          string         `db:"id,pk"`              // fr_
    WorkspaceID string         `db:"workspace_id,ws"`
    WorkflowID  string         `db:"workflow_id"`
    VersionID   string         `db:"version_id"`         // 钉死的 wfv_（图拓扑，不随 active 漂移）
    PinnedRefs  map[string]string `db:"pinned_refs,json"` // BuildPinClosure 结果 {entity_id: active_version_id}
    TriggerID   string         `db:"trigger_id"`         // 起点 trg_（可空：手动 :trigger 留 v2）
    FiringID    string         `db:"firing_id"`          // 来源 trf_（单事务 claim 写入）
    Status      string         `db:"status"`             // running | completed | failed
    ReplayCount int            `db:"replay_count"`       // :replay 自增；非 generation
    Error       string         `db:"error"`              // 终态 failed 的原因摘要
    StartedAt   time.Time      `db:"started_at"`
    CompletedAt *time.Time     `db:"completed_at"`
    CreatedAt   time.Time      `db:"created_at,created"`
    UpdatedAt   time.Time      `db:"updated_at,updated"`
}
```

- **run 级状态只有 3 个**：`running | completed | failed`。**没有 `parked`**——「等人」是某个 approval **节点**的状态（frn 行 status=parked），run 本身仍 `running`。「哪些 run 在等人」从 frn 派生查（§3.2），不在 header 冗余一份。
- `VersionID` + `PinnedRefs` = **确定性的两把锁**：拓扑冻结 + 所有引用实体版本冻结。运行中任何实体被编辑都改不动在途 run（§6 血泪边界一）。
- trigger payload **不存 header**——它是 trigger 节点的 result，进 frn 行（trigger 节点也是节点，§3.2），统一按 node-id 读。

### 3.2 `flowrun_nodes`（`frn_`）—— ★真相表（记忆化）

每个 (节点, 轮次) 一行，存它的 result。**这是整个引擎的真相。**

```go
type FlowRunNode struct {
    ID          string         `db:"id,pk"`              // frn_
    WorkspaceID string         `db:"workspace_id,ws"`
    FlowRunID   string         `db:"flowrun_id"`
    NodeID      string         `db:"node_id"`            // 图内局部 id（= doc 20 的引用名）
    Iteration   int            `db:"iteration"`          // 循环轮次，默认 0
    Kind        string         `db:"kind"`               // trigger|action|agent|control|approval
    Ref         string         `db:"ref"`                // pin 的实体 ref（审计）
    Status      string         `db:"status"`             // running | completed | failed | parked
    Result      map[string]any `db:"result,json"`        // 节点 result（见下）
    Error       string         `db:"error"`
    StartedAt   time.Time      `db:"started_at,created"`
    CompletedAt *time.Time     `db:"completed_at"`
    UpdatedAt   time.Time      `db:"updated_at,updated"`
}
```

**`Result` 按 kind 的形状**（= doc 20 §4 的「数据 out」）：

| kind | Result | 谁写 |
|---|---|---|
| trigger | firing payload（`{orderId:…}`） | scheduler 启动时 seed |
| action | callable 返回（fn returnSchema / hd method 返回 / mcp tool 返回） | RunAction 完成 |
| agent | agent outputSchema 的 JSON（或自由文本 `{text:…}`） | RunAgent 完成 |
| **control** | `{port: "pass", emit: {…}}`——选中分支 + emit 求值数据 | 解释器内联求值 |
| **approval** | `{decision: "yes"\|"no", reason: "…"}` | 人决策 / timeout 落定 |

- **`idx_frn_once = UNIQUE(flowrun_id, node_id, iteration)`** —— record-once 键。写结果一律 `INSERT OR IGNORE`（或 `ON CONFLICT DO NOTHING`）：**首个写入赢、后续静默忽略**。重走时 completed 行命中即跳；approval 双端同时落 → 先到的赢（§6）。
- **inbox 查询**：`WHERE status='parked'`（+ workspace）= 当前所有待人审批点，直接驱动通知中心/审批收件箱。**故旧 `approvals`（`apv_`）投影表删除**——parked 的 frn 行 *就是* 收件箱，再开一张投影表是冗余。
- 索引：`idx_frn_once`（record-once）+ `(flowrun_id)`（重走时拉全 run 的行）+ partial `(status) WHERE status='parked'`（inbox）。

### 3.3 `flowrun_agent_steps`（`frs_`）—— agent 子步记忆化

agent 节点是会跑多轮 ReAct 的 activity；一轮里可能调工具（fn/hd/mcp，**有外部副作用**）。崩溃后若整个 agent 从头重跑，既烧 token 又**重复执行副作用工具**（双端点火）。故 agent 的每轮记忆化，恢复时已完成轮抄结果。

```go
type FlowRunAgentStep struct {
    ID            string         `db:"id,pk"`            // frs_
    WorkspaceID   string         `db:"workspace_id,ws"`
    FlowRunNodeID string         `db:"flowrun_node_id"` // 所属 agent 的 frn 行
    StepIndex     int            `db:"step_index"`      // ReAct 轮序
    Status        string         `db:"status"`          // running | completed | failed
    Step          map[string]any `db:"step,json"`       // 这一轮：LLM 输出 + 本轮工具调用 + 工具结果
    CreatedAt     time.Time      `db:"created_at,created"`
    UpdatedAt     time.Time      `db:"updated_at,updated"`
}
```

- **`idx_frs_once = UNIQUE(flowrun_node_id, step_index)`** —— agent 子步的 record-once。
- 这是 §8 判定 ④「非幂等 activity 重跑」对 **agent 这一类**的本质性答案（agent 内嵌的工具副作用必须记忆化，不能粗粒度整体重跑）。action（fn/hd/mcp）是单步 activity，粗粒度记 frn 即可——它要么没完成（重跑，at-least-once，§8）、要么完成（抄）。
- 与 agent 模块自己的 `agent_executions`（`agx_`，R0043）**正交**：`agx_` 是 agent 实体视角的调用审计（不论谁调）；`frs_` 是 flowrun 视角的崩溃重放账本。一次 workflow agent 调用同时写两者（前者经 invoke 落、后者由 scheduler 落）。

### 3.4 ID 前缀变动（contract-change vs 旧 database.md §1）

| 前缀 | 旧 database.md | 新（本文） |
|---|---|---|
| `fr_` flowruns | 保留 | **保留**（重定义为记忆化 header） |
| `frn_` flowrun_nodes | 有（旧义不同） | **保留**（重定义为真相记忆化表） |
| `frs_` flowrun_agent_steps | 无 | **新增** |
| `fre_` flowrun_events | 有（事件日志） | **删除**（无事件日志） |
| `apv_` approvals | 有（parked 投影） | **删除**（parked frn 行即收件箱） |

> 落地时同步改 `database.md` S15 前缀表 + §1 Execution 段（删旧 GORM-tag 前瞻 struct，写 as-built 3 表）+ §3.2/D3。见 §10。

---

## 4. scheduler 解释器（M4.3）

无实体、纯 app、~1500 行 durable 解释器。核心是一个**幂等的「走一遍」函数**：给定 flowrun，读它所有 frn 行 + 钉死的图 → 算出哪些 (节点,轮次) ready → 跑它们 / 内联求值 → upsert frn → 直到无人 ready。崩溃后再调一次「走一遍」，completed 行天然跳过，从断点续。

### 4.1 一次「走一遍」（`advance(flowrun)`）

```
advance(fr):
  graph   := WorkflowReader.GetVersion(fr.VersionID).Graph     // 钉死拓扑
  rows    := frn rows of fr                                     // 全部记忆化
  live    := computeLiveSubgraph(graph, rows)                   // §4.3：从 trigger 顺激活边推活跃集
  loop:
    ready := { (node,iter) ∈ live | 所有活跃入边的源已 completed，且本行未存在 }
    if ready 空: break
    for (node,iter) in ready:        // 同批 ready 之间无依赖，可并发
       dispatch(node, iter, fr, rows)   // §4.2：action/agent 跑、control/approval 内联求值
       upsert frn row (INSERT OR IGNORE)
       rows := reload                  // 新 result 进入命名空间，可能解锁下游
    recompute live
  finalize(fr, rows)                  // §4.4：completed / failed / 仍 running(有 parked)
```

- **幂等**：`advance` 可被重复调用任意次，结果一致（completed 行不重写、不重跑）。崩溃恢复 = 再调一次 `advance`。
- **节点求值 scope**（model B）：跑 (节点 N, 轮次 k) 前，从 rows 按 node-id 取祖先 result 拼 `scope = { <祖先id>: result, ctx: {runId} }`，用 `ScopedEnv`（根=图的 node-id 列表）`Eval` 每个 `node.Input[field]` → 实体 input。**循环内祖先取当前轮 k 的 result、循环外祖先取其固定 result**（doc 20 §3 / §4.5）。

### 4.2 节点 dispatch：14 → 2 + 2 内联

旧引擎 14 个 dispatcher（function/handler/mcp/agent/llm/http/skill/tool/variable/wait/condition/approval/trigger/loop_parallel）→ **收成 2 个真 dispatch + 2 个解释器内联**：

| kind | 怎么跑 | 写什么 |
|---|---|---|
| **trigger** | 不 dispatch——启动时 seed firing payload 为 result | frn(trigger)=payload |
| **action** | `Dispatcher.RunAction(ctx, ref, input)`（端口内分流 fn `:run` / hd `:call` / mcp tool） | frn(action)=返回；可选 retry（§4.2.1） |
| **agent** | `Dispatcher.RunAgent(ctx, ref, input)`（接 `app/loop.Run`，逐轮写 frs_） | frn(agent)=outputSchema JSON；frs_ 逐轮 |
| **control** | **解释器内联**：`control.Resolve(ref, pinned)→[]Branch` → first-true-wins 求值 `When`（`pkg/cel`，scope=input）→ 选 Port → 求值该行 `Emit` | frn(control)=`{port, emit}` |
| **approval** | **解释器内联**：`approval.Resolve(ref, pinned)→Version` → `Template.Render(input)` → **park**（写 frn status=parked）；信号到 → 落 `{decision,reason}` | frn(approval)=parked → completed |

- **删** `state.go`/`pause.go`（topo-walk + paused_state 旧半）、generation 代数、`LoopDispatcher`（结构化 loop 取代，§4.3）、llm/http/skill/tool/variable/wait/condition 这些**不是 doc 20 五节点**的旧 dispatcher（它们的能力要么并进 action/agent，要么本就不该是节点）。
- **control/approval 决策也记忆化**（写 frn 行），不是「每走一遍重算」。即便 pin 已保证 CEL 不变，记账决策让重放绝对确定（§8），且 approval 的人工决策本就必须落库。

#### 4.2.1 action retry（平台级，非业务循环）

`node.Retry`（`RetryConfig{MaxAttempts,Backoff,DelayMs}`）= **activity 级瞬时故障重试**，在 `RunAction` 内消化，**不产生 frn 多行**（一个 action 节点一行，retry 是行内的事）。耗尽 retry 仍失败 → frn(action)=failed → run failed（§4.4）。业务循环（带反馈的 retry）是 control 回边，是另一回事（§4.3）。

### 4.3 join + 循环：从 control 结果重推活跃子图（判定 ②）

**核心问题**：一个有多条入边的节点，何时 ready？是等所有入边（AND-join），还是只等被激活的那条（control 下游 simple-merge）？

**答案（业界标准 = BPMN 状态式求值 / Conductor decider）**：不传播 skip 信号，而是**从已落库的 control/approval 决策重推哪些边活跃**。

```
computeLiveSubgraph(graph, rows):
  // 边 e: A --port--> B 是「活跃」的 ⟺ A 已 completed 且：
  //   A 非 control/approval        → A 的所有出边活跃（并行扇出 / 单出口）
  //   A 是 control                 → 仅 e.FromPort == rows[A].result.port 的出边活跃
  //   A 是 approval                → 仅 e.FromPort == rows[A].result.decision 的出边活跃
  // live = 从 trigger 起、只沿活跃边可达的 (节点,轮次) 集
```

**readiness 规则**（统一 AND-join 与 simple-merge）：

> 节点 B（轮次 k）**ready** ⟺ B ∈ live（有活跃入边）且 **B 的每条活跃入边的源都已 completed**，且 B 在轮次 k 还没有行。

- **并行**：trigger→A、trigger→B、A→C、B→C。trigger 完 → A、B 两边都活跃 → 都跑。A、B 完 → A→C、B→C 都活跃 → C 等**两者**（AND-join）。✓
- **control XOR**：ctl 选 `pass` → ctl→P 活跃、ctl→R 不活跃 → P 跑、R 永不跑（本轮）。✓
- **control 后汇合（simple-merge）**：ctl --pass--> P、ctl --else--> E、P→M、E→M。ctl 选 pass → 只 P 活跃、E 不在 live → E→M 不是活跃入边 → M 只等 P（**绝不等被剪掉的 E**，否则死锁）。✓

**为什么不用 skip 信号传播**：旧 BPEL「dead-path elimination」往未走分支灌 false token 让 join 知道别等——那是**有状态传播**，复杂且易错。Forgify 的 control 是**严格 XOR**、并行是**严格 AND**（无 BPMN 的 inclusive/OR-split），所以「活跃集」可以**纯函数地从决策结果重推**，无需任何传播。这是 model B 的红利：决策已经在 frn 行里，重推是 O(图) 的纯计算。

**循环（back edge）**：`BackEdges(graph)`（workflow 已建纯函数）认出回边 `C --retry--> H`（C=control/approval，H=循环头，ValidateGraph 保证可归约单入口）。C 完成且选中 retry 时，回边活跃 → **循环体**（从 H 可达且能回到 C 的节点集）在 **iteration k+1** 重新 ready、跑新行；循环外节点保持其固定轮次 result。iteration 进位由回边触发，承载在 frn 的 `iteration` 列。

### 4.4 finalize：run 终态

- **completed**：无人 ready、无 running、无 parked，且所有 live 叶子（live 中无活跃出边的节点）completed。
- **failed**：某 action 耗尽 retry failed（fail-fast：run 立即 failed，已完成的兄弟行保留记忆化；`:replay` 清 failed 行 + `replay_count++` 重走，completed 行复用）。
- **仍 running**：无人 ready 但有 parked（approval 等人）→ `advance` 让出，等信号重驱。

### 4.5 park / resume：approval 挂起（判定 ⑤ 人在环）

- **park**：解释器跑到 approval 节点 → 渲染模板 → 写 frn(approval) status=**parked**（`INSERT OR IGNORE`，承载渲染内容供前端展示）→ `advance` 自然停在这条路径（无后继活跃边）。run 仍 running。
- **resume**：人在 UI 决策（`POST /flowruns/{id}/approvals/{nodeId}:decide {decision,reason}`，端点 M4.3 建）→ **upsert frn(approval) 为 completed `{decision,reason}`（first-wins）** → 调 `advance(fr)` 重驱 → 激活 yes/no 出边。
- **timeout**（`apf_` 的 `Timeout`/`TimeoutBehavior`）：durable timer 的**唯一保留用途**。v1 实现 = boot 扫描 + 一个轻量 ticker：parked 且超 `created_at+Timeout` 的行，按 `TimeoutBehavior`（reject/approve/fail）落定 + `advance`。**通用 durable timer 门（任意节点 at?/after?）延后 v2**（§9）。

### 4.6 崩溃恢复 + firing 消费

- **boot 恢复**：扫 `flowruns WHERE status='running'` → 逐个 `advance`。completed 行跳过、running 行（崩溃时正在跑的 action/agent）**重跑**（at-least-once，§8）、parked 行保持。无 generation、无特殊 replay 模式——恢复就是再走一遍。
- **firing 消费**（接 trigger R0039 收件箱）：boot + ticker 排空 `trigger_firings WHERE status='pending'`（oldest-first），逐条**单事务 claim**：`UPDATE firing SET status=claimed WHERE id=? AND status=pending` → 同事务建 `flowruns`（钉 version + BuildPinClosure）+ seed trigger frn 行 → `firing.status=started, flowrun_id=fr_…`。**一个事务内 claim+建 run+seed**，无 claimed-但-无-run 残留态（ADR-021）。claim 后 `advance(fr)`。
  - **overlap**：v1 实现 `serial`（同 workflow 有 running run 时新 firing 等）+ `Skip`（丢，firing.status=skipped）+ `AllowAll`（并发）。`BufferOne`/`BufferAll` 延后 v2（§9）。判定用 workflow.`Concurrency` 列（R0047 已存）。

### 4.7 `:replay`（失败修复）

`POST /flowruns/{id}:replay`：清掉该 run 所有 `status='failed'` 的 frn 行 + `flowruns.replay_count++` + status 回 running → `advance(fr)`。completed 行全部复用（不重跑成功的活儿）、从失败点续。**这取代旧 generation 自增代**——重跑不是「新一代覆盖旧代」，是「清坏行重走、好行记忆化命中」。

---

## 5. DIP 端口（scheduler 依赖倒置）

scheduler 不 import 任何实体的具体 Service，全走端口（M7 装配注真、测试注 fake）：

```go
// Dispatcher —— 执行单元（action 三子类 + agent）。M7 接 function/handler/mcp/agent Service。
type Dispatcher interface {
    RunAction(ctx context.Context, ref string, input map[string]any) (map[string]any, error)
    RunAgent(ctx context.Context, ref string, input map[string]any, sink AgentStepSink) (map[string]any, error)
}
// AgentStepSink —— agent 逐轮回调，scheduler 落 frs_。
type AgentStepSink interface{ Step(ctx context.Context, index int, step map[string]any) error }

// 已就绪（直接 import）：
//   workflowapp.WorkflowReader            // 读钉死的图 + active 候选集
//   workflowapp.Service.BuildPinClosure   // 启动时冻结引用版本
//   controlapp.Service.Resolve            // 内联求 branches
//   approvalapp.Service.Resolve           // 内联求 form
//   workflowdomain.{ValidateGraph,BackEdges}  // 纯函数，运行前设闸 + 认回边
//   celpkg.{ScopedEnv,Program,Template}   // 节点 Input / control when·emit / approval template 求值
//   triggerstore（firings claim）          // 单事务 claim 的 SQL（M4.3 在 scheduler 侧写 claim 事务）
```

- `Dispatcher` 是唯一**新增**端口（其余全已落地）。M7 把 fn/hd/mcp/agent 的 Service 适配进 `RunAction`/`RunAgent`。
- scheduler 经 `WorkflowReader.ListActive` + Concurrency 列做 overlap 判定；经 trigger 收件箱表做 claim。

---

## 6. 三条血泪边界（lab 点名 · 作为新测试规格）

PLAYBOOK 步骤1：旧测试/血泪换来的边界写进契约「必须保证的行为」，作为新测试的规格。

1. **replay 确定性**：同一 flowrun 重复 `advance`（含崩溃后 boot 恢复），最终 frn 行集**逐字节一致**。机制 = ① pin 冻结拓扑+引用版本（无中途漂移）② control/approval 决策记忆化（不重推）③ CEL 纯函数（pin 的 when/emit/template 无 now()/随机）。
   - **测试**：跑到中途快照 frn → 注入「重复 advance ×N」→ 断言行集不变 + 无重复副作用 dispatch。
2. **record-once（幂等）**：`UNIQUE(flowrun_id,node_id,iteration)` + `INSERT OR IGNORE`。同一 (节点,轮次) 永不产生两行结果；并发/重入下首写赢。
   - **测试**：并发两次写同一 (节点,轮次) → 断言一行、第二次静默无效。
3. **approval first-wins**：人决策与 timeout 落定竞争同一 parked 行 → upsert first-wins，**第一个到的决策定终身**，第二个静默忽略（不翻盘、不报错）。
   - **测试**：并发「人 approve」+「timeout reject」→ 断言只落一个 decision、run 按那个走。

---

## 7. 删什么（判定 ③：偶然复杂度）

旧引擎 9302 行给单进程 SQLite app 背了分布式机制。删：

| 删 | 为什么是偶然复杂度 |
|---|---|
| 14 dispatcher 文件分裂 | doc 20 只有 5 节点 → 2 dispatch + 2 内联；llm/http/skill/tool/variable/wait/condition 不是节点 |
| `LoopDispatcher` | 结构化 loop（control 回边 + iteration）取代专门的并行循环 dispatcher |
| `state.go` / `pause.go`（topo-walk + paused_state） | 记忆化模型里「状态」就是 frn 行，无需单独的 walk-state / pause-state |
| generation 代数（replay 自增代、按最高代取态） | Temporal-ism；记忆化重跑 = 清坏行 + replay_count，无需代 |
| `flowrun_events` 事件日志（`fre_`） | 无用户代码可重放 → 事件流冗余（§2） |
| `approvals` 投影表（`apv_`） | parked frn 行即收件箱 |
| 分布式机制：task queue / worker pool / sticky / sharding / 多 region / 心跳 lease / stale-claim 回收 | 单进程，无 worker fleet；claim 是单事务（ADR-021），无 lease |

留（本质复杂度，不可删）：**记忆化行表、record-once 幂等、崩溃重走、durable park（+ approval timer）、pin 版本闭包、单事务 claim。**

---

## 8. 踩坑与漏解（判定 ④）

- **非幂等 activity 重跑（主坑）**：at-least-once 是本质——action 执行成功但进程在写 frn 行**之前**崩溃，重走时该 (节点,轮次) 无 completed 行 → **重跑**。对非幂等副作用（扣款）= 双执行。**诚实结论**：这是 at-least-once，**不假装 exactly-once**（Temporal/DBOS 的 activity/step 同样是 at-least-once）。缓解：① 文档明示 action 语义 = at-least-once；② `RunAction` 给 callable 传**确定性幂等键** `flowrun_id:node_id:iteration`，callable *可*用它向外部系统去重；③ agent 这类多步副作用用 **frs_ 子步记忆化**收窄重跑窗口到「未完成的那一轮」。
- **重放确定性**：control 分支选择必须在重走时稳定。机制 = 决策记忆化（frn 存 `{port,emit}`，重走读账不重算）+ pin（when/emit 的 CEL 版本冻结）+ CEL 纯（无 now()/随机）。即便实体被中途编辑（pin 已挡），记账的决策仍是权威。
- **丢信号 / 双端点火**：approval first-wins（record-once，§6）；trigger 去重 `idx_trf_dedup`（R0039 已建）。
- **pin 闭包深度**：`BuildPinClosure` depth≤2（agent→其 fn/hd callables，agent 不能挂 agent）——R0047 已建，scheduler 直接用。
- **死锁防护**：simple-merge 绝不等被剪分支（§4.3 活跃集排除 E→M）；ValidateGraph 保证可达 + 可归约回边，无非法环。
- **孤儿 parked**：workflow 被删/版本漂移不影响在途 run（pin 冻结 + frn 是 Log 不删）；run 永远能从自己的 `VersionID`+`PinnedRefs` 自洽重走。

---

## 9. 延后 v2（明确不在 M4.2/M4.3）

- **通用 durable timer 门**：任意节点的 `at?`/`after?` 定时门（approval timeout 是其特例、v1 做）。
- **continue-as-new**：超长循环的历史截断——记忆化模型下 frn 行无限增长才需要，v1 不碰。
- **overlap `BufferOne`/`BufferAll`**：v1 只 serial/Skip/AllowAll；缓冲队列语义延后。
- **手动 `:trigger`**（无 firing 直接起 run）、**catch-up / 补偿**（错过的 cron 追跑）。
- **agent 子步的工具调用提升为独立可观测节点**（v1 frs_ 内联记每轮工具 I/O，不拆成 frn 行）。

---

## 10. 契约回写（doc-fix · 落地时同步）

落 M4.2/M4.3 代码时，1:1 同步（CLAUDE.md #9）：

- **`database.md`**：S15 前缀表删 `fre_`/`apv_`、加 `frs_`、重定义 `frn_`；§1 Execution 段删旧 GORM-tag 前瞻 struct（`flowrun_events`/`approvals` 含 `gorm:` tag 是旧 backend 残留），写 as-built 3 表 DDL；D3 改 `idx_frn_once`（取代 `idx_fre_record_once`）。
- **`events.md`**：§1 eventlog 的 `flowrun.started/completed/failed/tick` 保留（前端实时视图），但**校准 source 路径**（旧 `scheduler/scheduler.go`/`state.go` → 新 scheduler 文件）+ tick payload（`{wfId,nodeId,status,iterKey}` → `{flowrunId,nodeId,iteration,status}`）；tick 仍 **E2 Ephemeral seq=0 不入 buffer**。三流不变（E1）。
- **`domains/flowrun.md` + `domains/scheduler.md`**：旧引擎契约，**整篇重写**为 as-built（记忆化模型、3 表、解释器算法）。
- **`api.md`**：新增 flowrun 端点（`GET /flowruns`、`GET /flowruns/{id}`、`POST /flowruns/{id}:replay`、`POST /flowruns/{id}/approvals/{nodeId}:decide`）。**无 `:trigger`**（firing 驱动）。
- **`error-codes.md`**：新增 `FLOWRUN_*` 码（NOT_FOUND / NOT_REPLAYABLE〔非 failed 不能 replay〕/ APPROVAL_NODE_NOT_PARKED / …）。
- **doc 20 §5.3 / §6.6**：确认 agent 子步记忆化 = frs_；§6.6 执行概览的「全照 17」改为「见 doc 21」。
- **lab**：`contracts/scheduler.md`（本文的 lab 摘要版）+ `contract-changes.md` #30 flowrun / #31 scheduler（落地时）+ STATE/ROUNDS/order R0048/R0049。

---

## 11. 测试计划（PLAYBOOK 步骤3）

- **flowrun（M4.2）unit/store**：3 表 orm 往返；record-once（重复 upsert 一行）；Log 不可删；workspace 隔离。
- **scheduler（M4.3）—— 核心模块必须集成测试**（不能只 unit）：
  - **走图**：线性 / 并行 AND-join / control XOR / control 后 simple-merge / 回边循环带状态（doc 20 端到端例子那张图，fake Dispatcher）。
  - **三血泪边界**（§6）：replay 确定性（重复 advance 行集不变）、record-once、approval first-wins。
  - **崩溃恢复**：跑到中途丢状态（只留 frn）→ boot advance → 断言从断点续、completed 不重跑。
  - **park/resume**：approval park → decide → 续；timeout 落定。
  - **firing→run**：单事务 claim（pending→started + run 建 + trigger frn seed 原子）；overlap serial/Skip。
  - **at-least-once 诚实**：崩溃在「action 完成、写行前」→ 重跑（断言副作用计数=2，证明语义而非假装 exactly-once）。
- **fake Dispatcher / fake LLM**（T6，0 token）：action 返回固定 map、agent 返回固定 outputSchema + 逐轮 sink。

---

## 12. 业界定位附录（横向，决策导向）

| 引擎 | 核心模型 | join | 对 Forgify 的取舍 |
|---|---|---|---|
| **Temporal / Cadence** | 事件 history + 用户代码确定性 replay | child workflow / future | **不取核心**（无用户代码可放）；取「workflow/activity 分离 + at-least-once activity + 幂等」心智 |
| **Azure Durable Functions / DTF** | 同上（orchestrator replay） | fan-out/fan-in（Task.WhenAll） | 同 Temporal；其 external events + durable timer 印证 §4.5 park 模型 |
| **AWS Step Functions** | 解释一张 ASL 状态机（托管服务存 per-exec 态） | Parallel / Map state | **最接近**：解释声明式图、非 replay 代码 |
| **Netflix Conductor** | 声明式 JSON + **decider 从 task 状态重推调度** | FORK / JOIN / DECISION / DO_WHILE | **核心范本**：decider = 本文 §4.3 从结果重推活跃集 |
| **DBOS Transact** | 步骤输出 checkpoint 进 SQL 表 + 幂等（workflow uuid） | — | **核心范本**：§3.2 记忆化行表 = DBOS 的 `(uuid,function_id)→output` |
| **Restate** | durable execution journal（轻量 replay） | — | 比 Temporal 轻，但仍 journal-replay；Forgify 更轻一档（无代码） |
| **Inngest / Trigger.dev / Windmill** | 步骤记忆化 + DB checkpoint | step.* | 现代主流 = 记忆化（非事件日志），印证判定 ① |
| **BPMN / van der Aalst 工作流模式** | — | XOR/AND/OR gateway；OR-join = synchronizing merge | §4.3：Forgify control=XOR(WCP-4)+simple-merge(WCP-5)、并行=AND(WCP-2/3)、**无 OR-split** → 比通用 OR-join 简单 |

> **一句话定位**：Forgify flowrun+scheduler = **「Step Functions / Conductor 的图解释」+「DBOS 的 SQL 步骤记忆化」**，砍掉所有为分布式/用户代码 replay 而生的机制。单进程 SQLite 图解释器的「最小正确」就是这张记忆化行表 + 一个幂等的 advance 函数。
