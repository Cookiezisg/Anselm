---
id: DOC-119
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-09
review-due: 2026-09-09
audience: [human, ai]
---
# Scheduler — Durable 图解释器（一个幂等的 advance）

> **核心职责**：scheduler 是把静态 workflow 图驱动到完成的 durable 解释器。它**无实体、纯 app**（`internal/app/scheduler`，~1500 行），全靠 [`flowrun`](flowrun.md) 的节点结果记忆化工作。整个引擎是**一个幂等的 `advance(flowrunID)` 函数**：读 run 的 frn 行 + 钉死的图 → 算哪些 (节点,轮次) ready → 跑 / 内联求值 → upsert frn → 直到无人 ready → finalize。崩溃 = `advance` 再跑一遍；completed 行被抄、绝不重跑。
>
> 本包**刻意取代旧事件溯源引擎**（旧 9302 行）：**无事件日志、无 generation、无 Agenda/topo-walk、无 14-dispatcher 扇出、无 skip 信号传播、无协程池/lease**。设计终稿见 [`21-flowrun-scheduler-design.md`](../../../working/workflow-revamp/21-flowrun-scheduler-design.md)。

---

## 0. 与旧引擎的硬切割（DOC-119 旧版描述的已删）

| 旧引擎（删） | as-built（本文） |
|---|---|
| Agenda-Driven 遍历（待办任务栈 + 动态下一跳） | `computeReady`：从已落库决策**纯函数重推**活跃子图 |
| Copy-Hit 重放（查 journal 抄结果） | completed frn 行天然命中跳过（无 journal，就是行表） |
| Active-Branch Join + **Skip Token** 传播 | **无 skip 传播**——从 control/`chosenPort` 重推哪些边活跃/被剪（§3） |
| `Interpreter` + `runWG`/`shutdown`/`Drain()` 协程池 + 优雅停机 | 无常驻协程——`advance` 是同步调用，崩溃恢复 = 再调一次 |
| 14 个 Dispatcher（tool/agent/case/llm/http/skill/wait…） | **2 个真 dispatch（action/agent）+ 2 个解释器内联（control/approval）**（§2） |
| agent **Sub-step Replay**（子步持久化） | agent = 粗粒度 activity（无子步，[`flowrun.md`](flowrun.md) §4） |

---

## 1. 一次「走一遍」（`Advance`）

`Advance(ctx, flowrunID)`（`advance.go`）是引擎的**幂等核心**：

```
Advance(flowrunID):
  run   := runs.GetRun(flowrunID)                 // 非 running 直接返回（已终态）
  ver   := workflows.GetVersion(run.VersionID)    // ★钉死的图（不是 active 版本）
  graph := decode(ver.Graph)
  senv  := ScopedEnv(graph.NodeIDs)               // model B：node-id 为 CEL 根
  loop:
    rows  := runs.GetNodes(flowrunID)             // 全部记忆化
    w     := newWalk(graph, rows)
    ready, overflow := w.computeReady()           // §3：从决策重推活跃子图 + readiness
    if overflow != "": failRun(loop exceeded MaxIterations); return
    if ready 空: break
    for (node,iter) in ready:                      // 同批 ready 无依赖
       status := runNode(...)                      // §2：action/agent dispatch、control/approval 内联
       if status == failed: return                 // fail-fast（failNode 已标 run failed）
    if 本批全 parked（无人 completed）: break        // 让出，等外部信号
  finalize(run)                                     // 有 parked → 仍 running；否则 completed
```

- **幂等**：`Advance` 可重复调用任意次，收敛到同一状态（completed 行不重写、不重跑）。崩溃恢复 = 再调一次。
- **跑一批 ready 后重读行、重算 walk**：刚完成的节点可解锁后继；`walk` 每轮重建（廉价、纯，`walk.go`）。
- **MaxIterations = 1000**：失控的 control（总选循环 port）会无界增长 frn 行；这是引擎安全帽（撞顶 → run failed）。真实循环由自身 CEL guard（如 `attempt < 3`）约束。

### 1.1 CEL 双轴

| 轴 | 用在哪 | env | scope |
|---|---|---|---|
| **node.Input 接线** | 每个节点的 `Input[field]` CEL（喂实体入参） | `ScopedEnv`（**node-id 为根**，model B） | `scopeFor`：祖先 completed result 按 node-id 寻址 + `ctx.runId`（§3.2） |
| **control / approval 逻辑** | control 的 `when`/`emit`、approval 的 `template` | 固定 `Compile` / `CompileTemplate`（**`input` 为根**） | `{input: 本节点 Input 求值出的 map}` |

> 第一轴先跑（`evalInput`）产出 `input` map，第二轴的 control/approval 再读这个 `input`。两轴分别由 `pkg/cel` 的 `ScopedEnv.Compile` 与 `Compile`/`CompileTemplate` 服务。

---

## 2. 节点 dispatch：14 → 2 + 2 内联

`runNode`（`dispatch.go`）执行一个 ready (节点,轮次) 并写其 frn 行。任何失败（input CEL / dispatch / resolver）fail-fast：节点行写 `failed` + run 标 `failed`（`failNode`）。

| kind | 怎么跑 | 写什么 frn |
|---|---|---|
| **trigger** | 不 dispatch —— `StartRun`/seed 时入口 payload 即 result（§4） | `{payload}`（启动时 seed，status completed） |
| **action** | `Dispatcher.RunAction(ctx, ref, input)`（端口内分流 fn `:run` / hd `:call` / mcp tool） | callable 返回 |
| **agent** | `Dispatcher.RunAgent(ctx, ref, input)`（接 `app/loop.Run`，**粗粒度**：跑完整 loop 返最终 result，照常 stream 到 SSE） | outputSchema JSON |
| **control** | **解释器内联** `evalControl`：`Resolve(ref, pinned) → []Branch` → first-true-wins 求 `When`（`EvalBool`）→ 选 `Port` → 求该行 `Emit`（空 Emit = 透传 input）→ `ControlResult(port, emit)`。末条 `When="true"` 编排时强制故必匹配 | emit 字段扁平 + `__port` |
| **approval** | **解释器内联** `renderApproval`：`Resolve(ref, pinned) → Version` → `Template.Render({input})` → **park**（写 frn `status=parked`，result=`{rendered, allowReason}`） | parked → 决策后翻 completed |

- **action/agent 都是粗粒度 activity**：跑到最终 result 返回，中途崩溃整体重跑（at-least-once）。
- **control/approval 决策也记忆化**（写 frn 行），不是「每走一遍重算」——即便 pin 保证 CEL 不变，记账决策让重放绝对确定，且 approval 人工决策本就必须落库。
- pin 版本由 `run.PinnedRefs[entityIDOf(node.Ref)]` 取（`entityIDOf` 把 `hd_<id>.method` 削成 `hd_<id>`、`mcp:server/tool` 映到 server，与 workflow pin 键派生一致）。

---

## 3. join + 循环：从决策重推活跃子图（无 skip 传播）

**核心问题**：多入边的节点何时 ready？等所有入边（AND-join）还是只等被激活那条（control 下游 simple-merge）？

**答案（BPMN 状态式 / Conductor decider 标准）**：不传播 skip 信号，而是从已落库的 control/approval 决策（`chosenPort`）**纯函数重推**哪些边活跃/被剪。这是 model B 的红利——决策已在 frn 行里，重推是 O(图) 纯计算。

### 3.1 `computeReady`（`walk.go`）

```
computeReady():
  // 1. 活跃子图（reachability BFS）：从被 seed 的 trigger(iter 0) 沿未剪边正向遍历
  //    边 A --port--> B 被剪 ⟺ A 是 COMPLETED 的 control/approval 且 chosenPort(A) != e.FromPort
  //    （未决 control 让其所有前向边暂时在场，后续 advance 轮再定）
  //    前向边：iteration 不变；回边（BackEdges，仅 control/approval 源）：仅源 completed 且 port 命中时走，iteration+1
  // 2. readiness（reached 集上）：
  //    节点 B(iter k) ready ⟺ (B,k) 被 reached、还没行、且每条 LIVE 入边的源都 completed
  //    （这条规则统一了并行扇出的 AND-join 与 control 分支后的 simple-merge）
  // 3. 确定性序：按声明序再按 iteration（使重放逐字节一致、测试稳定）
```

- **`chosenPort`**：completed control 返 `result.__port`、approval 返 `result.decision`（yes|no）。这正是「从已落库决策重推活跃子图」的承重点。
- **`predecessorsSatisfied`**：(id, iter) 的每条 **live 入边**（源在对的 iteration 被 reached、未剪）都有 completed 源，且**至少有一条 live 入边**。**被剪入边忽略**——等它们会让 simple-merge 死锁（control 选了别的 port 后，被剪那条永不到达）。

| 拓扑 | 行为 |
|---|---|
| **并行 AND-join** | trigger→A、trigger→B、A→C、B→C。A、B 都 live → 都跑；C 等**两者** completed。 |
| **control XOR** | ctl 选 `pass` → ctl→`pass` 在场、ctl→`retry` 剪 → 只 pass 分支跑。 |
| **control 后 simple-merge** | ctl→P、ctl→E、P→M、E→M。ctl 选 pass → E 被剪、E∉live → E→M 排除 → M **只等 P**（绝不等被剪的 E）。 |

### 3.2 循环（back edge）+ scope

- **回边**：`BackEdges(graph)`（workflow 纯函数，**仅 control/approval 源**，ValidateGraph 保证可归约单入口）认出 `C --port--> H`。**回边只在源 completed + port 命中时走**（不暂在场），走则循环体在 `iteration+1` 重新 ready——否则未决控制会无限展开循环。迭代受运行时控制（`attempt<3` 那种 guard）约束 + `MaxIterations` 安全帽。
- **`scopeFor(runID, iter)`**（model B 命名空间）：每个节点的 completed result 按 node-id 寻址，取「iteration ≤ iter 中最大且存在」那行——故**循环内祖先解析到当前轮、循环外到其固定 result**（循环内节点在 k 有行、循环外只在 0 有行，自然各取对）。`ctx.runId` 是唯一真·环境值。

---

## 4. Run 生命周期（Service 入口）

`Service`（`scheduler.go`）依赖全走 DIP 端口（§5）。`NewService` 必填 `runs/workflows/control/approval/dispatch`，`inbox` 可空（纯手动部署）。

### 4.1 `StartRun` —— 建-run 原语 + 两个入口

建 run 的核心是 `buildRun`（全是读，在任何 claim 事务之外）：解析 workflow 的 **active 版本** → `decodeGraph` → `resolveEntry`（选入口 trigger 节点）→ `BuildPinClosure`（冻结引用版本）→ 组装 (run 头, seed trigger 节点)。两个入口共用它，唯一区别是 firing 多一层去重 claim：

- **手动 `StartRun(ctx, StartInput)`**（UI/API「Run now」，v1）：`CreateRunWithTrigger`（自有事务建 run + seed trigger 节点）→ `Advance`。**无 claim**（人明确点一次、没 firing 可去重）。dogfood/集成测试跑 workflow 的入口。
  - `StartInput{WorkflowID, EntryNode?, TriggerID?, Payload, FiringID?}`。`EntryNode` 在多 trigger 图里选入口；`resolveEntry` 歧义/选错 → `ErrInvalidEntry`。
  - **payload 表单 schema = 入口 trigger 实体的 `Outputs`**（手动 fire = 你扮演本该产生 payload 的外部事件源）。**不强制校验**（同 firing payload 自由 map）。
- **`DrainFirings(ctx)`**（自动，接 trigger 收件箱）：排空 `ListPendingFirings` → 逐条 `consumeFiring`。一条坏 firing 记日志跳过、不卡队列。`consumeFiring`：
  1. `overlapDecision`（§4.2）→ defer（留 pending 后再排）/ Skip（`MarkFiringOutcome` skipped）/ run。
  2. `buildRun`（读，tx 外）。
  3. **`inbox.ClaimFiring(firingID, create)`**：一个事务内 `pending→claimed` + `SeedRunOnTx`（建 run + seed trigger 节点）+ started 回填（ADR-021）——**claim + 建 run + seed 同事务**，无 claimed-但-无-run 残留。claim 竞争失败（`ErrFiringNotPending`）= 静默退。
  4. `Advance`（claim 事务外，在 firing 自己 workspace 的 ctx 里）。

### 4.2 overlap 策略（`overlapDecision`）

判据 = `workflow.Concurrency` 列。**手动 `StartRun` 不过 overlap 闸**（人明确要跑就跑）。

| Concurrency | 有 running run 时 | v1 实现 |
|---|---|---|
| `serial` | **defer**（留 pending，后再排空） | ✅ |
| `Skip` | **drop**（`firing.status=skipped`） | ✅ |
| `AllowAll` | 总跑（并发） | ✅ |
| `BufferOne` / `BufferAll` | —— | **v2**（暂按 AllowAll，使 firing 绝不静默丢失） |

### 4.3 其余入口

| 方法 | 干什么 |
|---|---|
| **`Recover(ctx)`** | boot 崩溃恢复：`ListRunningRuns`（**跨 workspace**）→ 逐个在各自 workspace ctx 里 `Advance`。completed 行跳过、崩溃时正跑的 action/agent 无终态行 → 重跑（at-least-once）、parked 行保持。 |
| **`DecideApproval(ctx, flowrunID, nodeID, decision, reason)`** | 人决策落定 parked approval + 重驱。`decision ∉ {yes,no}` → `ErrInvalidDecision`；条件 `UPDATE` first-wins 输家 → `ErrNodeNotParked`（干净 422）；赢 → `Advance` 激活 yes/no 出边。 |
| **`CheckTimeouts(ctx, now)`** | **唯一保留的 durable timer**：扫 parked 行，解析 pin 表单的 `Timeout`/`TimeoutBehavior`（`ParseTimeout` 支持 d/w）；到期按 behavior 落定（`reject→no` / `approve→yes` / `fail→run failed`）。first-wins 防与人工决策竞争。**通用 durable timer 门（任意节点 at?/after?）是 v2**。 |
| **`Replay(ctx, flowrunID)`** | 修复失败 run：`DeleteFailedNodes`（清非结果失败行）+ `ReopenForReplay`（翻 running + `replay_count++`）+ `Advance`。completed 行全复用、从失败点续。run 非 failed → `ErrNotReplayable`。**取代旧 generation 自增代**。 |
| **`ListRuns` / `GetRunWithNodes` / `ListInbox`**（`query.go`） | 运行历史分页 / run 详情（头 + 全部节点行，含 parked）/ 审批收件箱（parked 行即收件箱，无投影表）。 |
| **`KillWorkflow(ctx, workflowID) → killed`**（`kill.go`，R0066） | 硬停一个 workflow 的所有在途 run（`workflow.Service.Kill` 在 Detach 后调）。见 §4.5。 |
| **`CountRunning(ctx, workflowID)`**（R0066） | 在途 run 数；workflow `:deactivate` 据此选 draining vs inactive。 |

#### 4.5 kill：取消在途 run（R0066/D1）

`Advance` 是**同步**走图——撞 agent 节点会阻塞在 `loop.Run` 里。要打断它，必须取消其 ctx：

- **inflight 注册表**（`map[flowrunID]context.CancelFunc` + mutex）：`Advance` 入口 `trackInflight` 派生可取消子 ctx 注册、defer 注销。per-run 单 goroutine，故每 run 至多一个 cancel。`Advance` 循环顶 `if ctx.Err()!=nil { return nil }`（中断非错误：durable 状态为准）。
- **`KillWorkflow`**：`ListRunningByWorkflow` → 逐 run **先标 `cancelled`**（`MarkRunTerminal` 守卫 `WHERE running`）**再 `cancelInflight`** 取消 ctx。顺序关键——被打断的节点 RunAgent/RunAction 返 `ctx.Err()` 会经 `failNode` 想标 failed，但此时 run 已 cancelled、`WHERE running` 匹配 0 行 no-op → **cancelled 确定性赢**。park 中的 run 无 inflight 项（已从 Advance 返回）→ cancelInflight no-op、纯靠 store 标 cancelled。
- 对忽略 ctx 的纯 CPU 工作只能 best-effort（标 cancelled + 循环顶 bail），但真实 agent 的 LLM/工具调用都吃 ctx。

### 4.4 finalize（`advance.go`）

- **completed**：无人 ready、无 parked → `markRunTerminal(completed)`。
- **failed**：某节点 fail-fast（action 耗尽 retry / CEL 错 / resolver 错）→ `failNode` 写 failed 行 + run failed（已完成兄弟行保留记忆化，`:replay` 复用）。引擎级失败（loop overflow）走 `failRun`。
- **仍 running**：无人 ready 但有 parked（approval 等人）→ `Advance` 让出，等信号重驱。
- **drain reconcile（R0066）**：completed/failed 都经 `markRunTerminal` 收口——run 结算后若该 workflow `CountRunning==0` 且接了 `LifecycleReconciler`，调 `MarkInactiveIfDrained`（把 `:deactivate` 落下的 `draining` 翻 `inactive`，优雅排空完成）。

---

## 5. DIP 端口（依赖倒置）

scheduler 不 import 任何实体的具体 Service，全走端口（M7 装配注真、测试注 fake）：

| 端口 | 做什么 | M7 实现 |
|---|---|---|
| **`Dispatcher`** | `RunAction(ref, input)` / `RunAgent(ref, input)`——两类执行单元，都粗粒度 activity | ✅ `bootstrap.NewDispatcher`（fn_→RunFunction · hd_<id>.method→Call · mcp:<id>/<tool>→CallTool · ag_→InvokeAgent；`toResultMap`：对象直通扁平 / nil→空 / 标量→`{text}`；fn·ag `OK=false`→fail-fast） |
| **`WorkflowReader`** | `GetWorkflow` · `GetActiveVersion`（StartRun pin 步） · **`GetVersion(pinnedID)`**（解释器读冻结拓扑） · `BuildPinClosure` | `*workflowapp.Service` |
| **`ControlResolver`** | `Resolve(id, versionID) → []controldomain.Branch`（内联求 branches） | `*controlapp.Service` |
| **`ApprovalResolver`** | `Resolve(id, versionID) → *approvaldomain.Version`（内联求 form + timeout） | `*approvalapp.Service` |
| **`FiringInbox`** | `ListPendingFirings` · **`ClaimFiring(id, create)`**（单事务 claim + 建 run，ADR-021） · `MarkFiringOutcome`。**nil 容忍**：纯手动部署不接 | `*triggerstore.Store` |
| **`RunStore`** | `flowrundomain.Repository` + 两个 store-concrete 原子建-run 方法（`CreateRunWithTrigger` / `SeedRunOnTx`，跨两表单事务） | `*flowrunstore.Store` |
| **`LifecycleReconciler`**（R0066，setter 注入，**nil 容忍**） | `MarkInactiveIfDrained(workflowID)`——run 结算后翻 draining→inactive（§4.4 drain reconcile） | `*workflowapp.Service` |

`pkg/cel`（`ScopedEnv` / `Compile` / `CompileTemplate`）直接 import（纯求值，无状态、无 DIP 需要）。

---

## 6. 延后 v2（明确不在范围）

- **resume-mid-agent**：agent 子步记忆化（`frs_`）+ `loop.Run` durable 重放改造（跳过已执行轮 + 回放工具结果）。卡点 = `loop.Run` 现是流式黑盒、无 resume 入口。
- **通用 durable timer 门**：任意节点 `at?`/`after?`（approval timeout 是其 v1 特例）。
- **continue-as-new**：超长循环的 frn 行无限增长截断。
- **overlap `BufferOne` / `BufferAll`**：v1 只 serial/Skip/AllowAll。
- **`trigger_workflow` LLM 工具**：手动入口 v1 就做，但把 scheduler 注进 toolset 随 M7。

---

## 7. 错误字典（Sentinels）

scheduler 自身不新增 sentinel——它冒泡 [`flowrun`](flowrun.md) 域的错误：

| Sentinel | Wire Code | HTTP | 触发 |
|---|---|---|---|
| `flowrundomain.ErrNotFound` | `FLOWRUN_NOT_FOUND` | 404 | `Advance`/`Replay`/`DecideApproval` 的 `fr_` 未命中。 |
| `flowrundomain.ErrNotReplayable` | `FLOWRUN_NOT_REPLAYABLE` | 422 | `Replay` 一个非 failed run。 |
| `flowrundomain.ErrNodeNotParked` | `FLOWRUN_APPROVAL_NOT_PARKED` | 422 | `DecideApproval` first-wins 输家（已决/超时）。 |
| `flowrundomain.ErrInvalidEntry` | `FLOWRUN_INVALID_ENTRY` | 422 | `resolveEntry` 入口节点缺失/非 trigger/多 trigger 歧义。 |
| `flowrundomain.ErrInvalidDecision` | `FLOWRUN_INVALID_DECISION` | 422 | `DecideApproval` 的 decision 非 yes/no。 |

> loop overflow（撞 `MaxIterations`）不是 sentinel——它把 run 标 failed（`error` 摘要带 node + 上限），非 HTTP 错误。
