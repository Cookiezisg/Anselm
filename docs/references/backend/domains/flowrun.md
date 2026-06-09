---
id: DOC-109
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-09
review-due: 2026-09-09
audience: [human, ai]
---
# FlowRun Domain — 一次执行的持久化状态（节点结果记忆化）

> **核心地位**：FlowRun 是一次 workflow 执行的**持久化状态**——崩溃从这里恢复。它**不是可锻造实体**（无 catalog / relation / 版本），是 scheduler（[`scheduler.md`](scheduler.md)）解释**钉死的图**时写的运行时日志。
>
> 模型是**节点结果记忆化**（DBOS / Conductor 式），**不是事件溯源日志**（Temporal 式）：没有用户代码可重放，只有图解释器，其全部状态 = 「哪些 (节点,轮次) 完成了、result 是啥」——这住在 `flowrun_nodes` 这张唯一真相表里。重跑解释器（崩溃恢复 / `:replay`）幂等，因为 completed 行被**抄**、绝不重跑。设计终稿见 [`21-flowrun-scheduler-design.md`](../../../working/workflow-revamp/21-flowrun-scheduler-design.md)。

---

## 0. 一句话 + 与旧引擎的硬切割

一次执行 = 一个 durable 解释器照钉死的图走一遍，每个节点的 result 记进一张行表（记忆化），崩溃后重走时 completed 行抄结果、不重跑。

| 旧引擎（已删，DOC-109 旧版描述的） | as-built（本文） |
|---|---|
| `flowrun_events` 事件日志（`fre_`，append-only journal） | **删**——无事件流；真相 = `flowrun_nodes` 行表 |
| `approvals` 投影表（`apv_`） | **删**——parked 的 frn 行*就是*审批收件箱 |
| `flowrun_agent_steps`（`frs_`，agent 子步记忆化） | **不引入**——agent 是粗粒度 activity（§4） |
| `Generation` 重放代号（影子覆盖） | **删**——`:replay` = 清 failed 行 + `replay_count++`，completed 行天然命中跳过 |
| GORM tag、`UserID`、`PausedState`/`Agenda` 快照 | **删**——`pkg/orm` + 手写 DDL + `workspace_id`（D2）；状态就是 frn 行，无单独 pause/walk-state |

> **ID 前缀**：本域只用 **`fr_`**（flowruns）+ **`frn_`**（flowrun_nodes）。`fre_` / `apv_` / `frs_` 都**不再使用**（旧 `database.md` §1 / S15 曾登记，落地时同删）。

---

## 1. 物理模型（2 张表）

全 `pkg/orm` + 手写 DDL + workspace 隔离（D2：`workspace_id` 物理列，orm `,ws` tag 自动）。**两张都是 Log 表**——无 `deleted_at`（D1：执行历史严禁逻辑删）。唯一允许的物理删是 `DeleteFailedNodes`（清 `:replay` 的非结果失败行，§3）。

### 1.1 `flowruns`（`fr_`）—— 执行头

钉死的拓扑（`version_id`）+ 钉死的引用实体版本（`pinned_refs`）+ 状态机 + replay 记账。

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

- **run 级状态只有 3 个**：`running | completed | failed`。**无 `parked`**——「等人审批」是某个 approval **节点**的状态（frn 行 `status=parked`），run 仍 `running`。「哪些 run 在等人」从 parked frn 行**派生查**（§3），不在头上冗余。
- **`VersionID` + `PinnedRefs` = 确定性的两把锁**：拓扑冻结 + 引用实体版本冻结，运行中任何编辑都改不动在途 run（§5 边界一）。pin 闭包由 workflow 的 `BuildPinClosure(graph) → {entity_id: active_version_id}`（depth ≤ 2：agent → 其 fn/hd callable）在 `StartRun` 瞬间构建。
- **trigger payload 不存头**——它是 trigger 节点的 result，进 frn 行，统一按 node-id 读。
- 索引：`idx_fr_ws_created`（历史分页）· `idx_fr_ws_workflow`（单 workflow 历史）· partial `idx_fr_running WHERE status='running'`（boot 恢复候选集）。

### 1.2 `flowrun_nodes`（`frn_`）—— ★真相表（记忆化）

每个 (节点, 轮次) 一行，存它的 result。**这是整个引擎的真相。**

```go
type FlowRunNode struct {
    ID          string         `db:"id,pk"`              // frn_
    WorkspaceID string         `db:"workspace_id,ws"`
    FlowRunID   string         `db:"flowrun_id"`
    NodeID      string         `db:"node_id"`            // 图内局部 id（= doc 20 的下游引用名）
    Iteration   int            `db:"iteration"`          // 循环轮次，0-based
    Kind        string         `db:"kind"`               // trigger|action|agent|control|approval
    Ref         string         `db:"ref"`                // pin 的实体 ref（审计）
    Status      string         `db:"status"`             // completed | failed | parked（无 running）
    Result      map[string]any `db:"result,json"`        // 节点 result（见 §2）
    Error       string         `db:"error"`
    CreatedAt   time.Time      `db:"created_at,created"` // 终态写 / park 时间
    CompletedAt *time.Time     `db:"completed_at"`       // parked 期间为 nil
    UpdatedAt   time.Time      `db:"updated_at,updated"`
}
```

- **行只写终态**（无瞬时 `running` 行）：action/control 在一次同步 `advance()` 内跑完即写终态；写行前崩溃 → 重走时无行 → 重跑（at-least-once，§5）。**`parked` 是唯一非终态**：approval 挂起前写它，决策再翻成 completed。
- **`idx_frn_once = UNIQUE(flowrun_id, node_id, iteration)`**（D3，取代旧 `idx_fre_record_once`）—— record-once 键。
- 索引：`idx_frn_once`（record-once）· `idx_frn_run (flowrun_id)`（重走拉全 run）· partial `idx_frn_parked (workspace_id, status) WHERE status='parked'`（审批收件箱）。

---

## 2. Result 按 kind 的形状

`FlowRunNode.Result` 的 per-kind 形状（= doc 20 §4 的「数据 out」）。control/approval 的 result 有结构（port/decision 驱动路由 + 携带数据）；action/agent 的 result 是 callable/agent 原始输出原样存。

| kind | Result | 谁写 |
|---|---|---|
| **trigger** | 入口 payload（`{orderId:…}`，= `firing.Payload` 或手动 payload） | `StartRun`/`SeedRunOnTx` 启动时 seed（节点 status 直接 completed） |
| **action** | callable 返回（fn `:run` returnSchema / hd `:call` method 返回 / mcp tool 返回），原样 | `RunAction` 完成 |
| **agent** | agent outputSchema 的 JSON（或自由文本 `{text:…}`） | `RunAgent` 完成（粗粒度，§4） |
| **control** | 选中分支 emit 字段**扁平** + 保留路由键 **`__port`** | 解释器内联求值 |
| **approval** | parked 时 `{rendered, allowReason}`（供收件箱 UI）→ 决策后 `{decision, reason}` | park 写 → 人决策 / timeout 翻 |

**control result 的关键形状**（`ControlResult(port, emit)`）：选中分支的 `emit` 字段**扁平铺开**，外加保留键 `__port` 存选中的路由 port。故**下游直接读 `gate.feedback`**（doc 20 §5.4「下游按名读 emit 字段」），而解释器读 `gate.__port` 做路由。双下划线避免撞 emit 字段名。

**approval result**（`ApprovalDecision(decision, reason)`）：`decision ∈ {yes, no}`（= 走 yes/no 出边），`reason` 可空。`rendered`（渲染好的 markdown）与 `allowReason`（是否允许填备注）只在 parked 期存在，决策后被 decision/reason 覆盖。

Result 键常量（`flowrun.go`）：`ResultKeyPort="__port"` · `ResultKeyDecision="decision"` · `ResultKeyReason="reason"` · `ResultKeyRendered="rendered"`。

---

## 3. 写入语义（Repository 三组方法）

`flowrundomain.Repository`（store 实现 = `*flowrunstore.Store`）。两张表的原子建-run 方法（`SeedRunOnTx` / `CreateRunWithTrigger`，跨两表单事务）不在 Repository 接口里——它们是 store-concrete（firing 路径要在 `triggerstore.ClaimFiring` 的事务上绑 Repo，故表名 `TableFlowRuns`/`TableFlowRunNodes` 导出）。

| 关注点 | 机制 | 方法 |
|---|---|---|
| **record-once（幂等）** | `INSERT OR IGNORE` —— `idx_frn_once` 上的重复被**静默忽略**（`inserted=false`），绝不报错。首写赢；重走时 completed 行命中即抄、绝不重跑 | `InsertNodeResult → (inserted bool)` |
| **approval first-wins** | 条件 `UPDATE … WHERE status='parked'` —— 人决策 vs timeout 竞争同一 parked 行，第一个翻成功（`won=true`），第二个 0 行（`won=false`，no-op 非错误） | `ResolveParkedNode → (won bool)` |
| **唯一允许的物理删** | `DeleteFailedNodes` 物理删一个 run 的 `status='failed'` 行——failed 行是**非结果**（activity 没 durable 完成），删它重试不是抹历史；completed 行全留作记忆化 | `DeleteFailedNodes → (n int)` |
| **replay（头那半）** | `failed → running` + `replay_count++` + 清 error；run 非 failed 返 `ErrNotReplayable`。**非 generation**——重跑不是新代覆盖旧代，是清坏行重走、好行命中 | `ReopenForReplay` |
| 读 | 取 run 头 / 全部节点行（解释器据以重推状态）/ 分页历史 | `GetRun` · `GetNodes` · `ListRuns` |
| boot 恢复候选集 | 所有仍 `running` 的 run，**刻意跨 workspace**（boot 在任何请求 ctx 前跑） | `ListRunningRuns` |
| overlap 输入 | 某 workflow 当前 running run 数（serial 推迟 / Skip 丢的判据） | `CountRunningByWorkflow` |
| 审批收件箱 | workspace 内所有 parked 节点行——**无独立投影表，parked 行即收件箱**；决策路径取某 (run,node) 当前 parked 行 | `ListParkedNodes` · `GetParkedNode` |
| run 终态 | 置 completed/failed + error + completed_at | `MarkRunTerminal` |

> **`:replay` = 两半**：`DeleteFailedNodes`（节点半，清非结果）+ `ReopenForReplay`（头半，翻 running + 计数）。两者都不动 completed 行。scheduler 的 `Replay()` 串起这两半再 `Advance`。

---

## 4. agent 节点 = 粗粒度 activity（v1 无子步记忆化）

agent 跑多轮 ReAct、内嵌副作用工具调用——理论上「崩溃从最后完成轮续」要给每轮记忆化（`frs_`）。**v1 不做**，故 flowrun 退成 **2 表**：

- `app/loop.Run` 是流式黑盒：只往 SSE 吐 turn（ephemeral），**无 durable 逐轮 journal、无 resume 入口**。
- agent = 粗粒度 activity、和 action 完全一样：只记忆化**最终** result 进 `frn`，崩溃整体重跑（at-least-once 在 agent 粒度）。代价：崩溃正好卡在 agent 中途时整体重跑（罕见；烧 token + 工具副作用重执行——靠 fn/hd 幂等键 `flowrun_id:node_id:iteration` 缓解）。
- 观测性由 agent 模块的 `agent_executions`（`agx_`）+ eventlog 覆盖。**真正的 resume-mid-agent = `loop.Run` 的 durable 重放改造，v2**。

---

## 5. 三条血泪边界（执行域必须保证的行为）

旧测试/血泪换来的边界，作为本域与 scheduler 的新测试规格：

1. **replay 确定性**：同一 flowrun 重复 `advance`（含崩溃 boot 恢复），最终 frn 行集**逐字节一致**。机制 = ① pin 冻结拓扑 + 引用版本 ② control/approval 决策**记忆化**（重走读账不重推）③ pin 的 CEL 纯（无 `now()`/随机）。
2. **record-once（幂等）**：`UNIQUE(flowrun_id, node_id, iteration)` + `INSERT OR IGNORE`。同 (节点,轮次) 永不两行；并发/重入下首写赢。
3. **approval first-wins**：人决策与 timeout 落定竞争同一 parked 行 → 条件 `UPDATE … WHERE status='parked'` first-wins，第一个定终身、第二个 0 行（不翻盘、不报错）。

> **at-least-once 诚实**：action/agent 执行成功但进程在写 frn 行**之前**崩溃，重走时无终态行 → **重跑**；非幂等副作用 = 双执行。**不假装 exactly-once**（Temporal/DBOS 同样）。缓解 = 给 callable 传确定性幂等键 `flowrun_id:node_id:iteration` 供其向外去重。

---

## 6. 跨域集成

- **workflow**：读 `version_id` 对应的**钉死图**（`GetVersion(pinnedID)`，不是 active 指针）；`BuildPinClosure` 冻结引用实体版本。
- **trigger**：firing 路径经 `triggerstore.ClaimFiring` 单事务 claim + 建 run（ADR-021，无 lease）；`firing.Payload` 成 trigger 节点 result。
- **scheduler**：本域是 scheduler 唯一的真相读写面——见 [`scheduler.md`](scheduler.md)。
- **eventlog / notifications**：run 状态变化经 SSE 实时推流（`flowrun.started/completed/failed/tick`；tick 为 E2 Ephemeral `seq=0` 不入 buffer）。
- **生命周期**：run 自洽——workflow 被删 / 版本漂移不影响在途 run（pin 冻结 + frn 是 Log 不删），run 永远能从自己的 `VersionID` + `PinnedRefs` 重走。

---

## 7. 错误字典（Sentinels）

| Sentinel | Wire Code | HTTP | 物理起因 |
|---|---|---|---|
| `ErrNotFound` | `FLOWRUN_NOT_FOUND` | 404 | `fr_` id 未命中（按 workspace 隔离）。 |
| `ErrNotReplayable` | `FLOWRUN_NOT_REPLAYABLE` | 422 | 对非 `failed` 状态的 run 调 `:replay`（没坏东西可修）。 |
| `ErrNodeNotParked` | `FLOWRUN_APPROVAL_NOT_PARKED` | 422 | 审批决策指向一个不在等信号的节点（已决/已超时/从未 park）——first-wins 的输家。 |
| `ErrInvalidEntry` | `FLOWRUN_INVALID_ENTRY` | 422 | 手动 `:trigger` 指定的 entry 节点缺失/非 trigger，或多 trigger 图未指定 `entryNode`（歧义）。`details` 带原因。 |
| `ErrInvalidDecision` | `FLOWRUN_INVALID_DECISION` | 422 | 审批决策既非 `yes` 也非 `no`。 |

> 全部 `errorsdomain.New(kind, code, msg)`（S20，带 Kind→HTTP status + 稳定 wire code）。
