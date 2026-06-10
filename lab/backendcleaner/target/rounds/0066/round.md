# Round 0066 — D1：工作流执行生命周期 5 工具（trigger/stage/activate/deactivate/kill）

类型 / 目标：把散落 D1 从「1 个 Run now」纠正成**一整条工作流执行生命周期**。用户拆出 5 个动作（命名经 AskUserQuestion 拍板）：

| 动作 | 工具 / `:action` | 语义 | 底层 |
|---|---|---|---|
| 触发 | `trigger_workflow` / `:trigger` | LLM 造 payload，**现在**跑一次 | `scheduler.StartRun`（**现成**） |
| 试运行 | `stage_workflow` / `:stage` | 挂上去等**下一次真实** trigger、跑一次自动摘 | trigger.AttachOnce（**新**：一次性监听） |
| 激活 | `activate_workflow` / `:activate` | 上线，开始监听真实 trigger | SetLifecycle(active) + trigger.Attach |
| 关掉激活 | `deactivate_workflow` / `:deactivate` | **优雅**下线（停监听、在跑的放完=draining） | Detach + SetLifecycle(draining\|inactive) |
| 杀掉 | `kill_workflow` / `:kill` | **强制**硬停（停监听 + 立即砍掉所有在跑的） | Detach + scheduler.KillWorkflow（**新**：ctx 取消） |

## 摸底结论（动手前精确核对）

- `scheduler.StartRun(ctx, StartInput{WorkflowID, Payload, ...})` 现成——**触发**只是包壳。`Advance` 是**同步走图循环**：撞 agent 节点阻塞在 `loop.Run` 里直到 完成/失败/park 才返回。
- `workflow` 实体已有 `Active bool` + 三态 `LifecycleActive/Draining/Inactive` + `SetLifecycle`；`:activate`/`:deactivate` 端点**已存在但只翻 DB 标志**——`workflow.Service` 无 trigger 端口，`trigger.Attach/Detach` 至今**无人调用**（R0048 deferred 的接线）。
- `trigger` 引用计数：`listeners map[triggerID]*listenEntry{workspaceID,kind,workflows}` + `Attach`/`Detach`/`fanOut`/`FireManual`，listener 仅 refcount≥1 时跑。
- `flowrun` run 状态只有 `running/completed/failed`——**无 cancelled**。`MarkRunTerminal` **无条件 UPDATE**（kill/finalize 竞争会互刷）。`CountRunningByWorkflow`/`ListRunningRuns` 现成。

## 设计（关键决策）

### 归属：workflow.Service 拥有全部 5 个动作
新增 2 个 DIP 端口（workflow 侧定义、用原生类型、bootstrap 注具体——**无 import 环**：scheduler app 只 import workflow **domain**，故 workflow app→scheduler app 安全）：
- `Binder`（→trigger.Service）：`Attach(ctx,trg,wf)` · `AttachOnce(ctx,trg,wf)` · `Detach(trg,wf)`
- `Runner`（→scheduler.Service，bootstrap 用 adapter 转 StartInput）：`StartRun(ctx,wfID,payload)→runID` · `KillWorkflow(ctx,wfID)→killed`

5 方法 + `entryTriggerRefs(ctx,id)`（解 active 图、收 `NodeKindTrigger` 的 ref；无 active 版本/无 trigger 节点→错）。

### kill：scheduler ctx 取消注册表
`Advance` 同步阻塞 → 打断在跑的唯一办法是取消其 ctx。
- Service 加 `inflight map[flowrunID]context.CancelFunc` + mu。`Advance` 入口 `trackInflight`：派生可取消子 ctx、注册、defer 注销。**per-run 单 goroutine**（DecideApproval/CheckTimeouts 只在 park 时重驱、无并发）→ 每 run 至多一个 cancel。
- `KillWorkflow(ctx,wfID)`：`ListRunningByWorkflow`（**新仓库法**）→ 逐 run：`cancelInflight(id)`（打断阻塞的 Advance，park 中的 run 无 inflight 项=no-op）+ `MarkRunTerminal(cancelled)`。
- 新增 `StatusCancelled="cancelled"` 终态。`MarkRunTerminal` 加 `WHERE status='running'` 守卫（first-wins，防 kill/finalize 互刷）。

### stage：一次性监听
- `listenEntry` 加 `once map[string]bool`。`AttachOnce` = `attach(...,once=true)`（抽私有 `attach`）。
- `fanOut` 在 `act.Fired` 扇出后 `detachOneShots(triggerID, workflows)`：取 once 集交集、逐个 `Detach`（扇出一次即摘）。
- stage **不改 lifecycle**（保持 inactive 但 armed）；对已 active 的 workflow → `ErrAlreadyActive`（活的不必试运行）。

### 激活/关掉激活：补接线 + 跨重启
- `Activate`：entryTriggerRefs → SetLifecycle(active) + 逐 ref `binder.Attach`。
- `Deactivate`：逐 ref `binder.Detach` + SetLifecycle(`runner` 有在跑→draining 否则 inactive)。
- **boot 重挂**：listener 是内存的，重启后 active workflow 的监听丢失 → `ReattachActive(ctx)`（ListActive→逐个 Attach refs），App.Boot 在 trigger.Start 后调。
- **draining→inactive reconcile**：deactivate 设 draining 后须自愈，否则永卡。scheduler 终结 run 时（finalize/fail/timeout）`afterRunSettled`：若 `CountRunningByWorkflow==0` 且 `reconciler!=nil` → `reconciler.MarkInactiveIfDrained(wfID)`（workflow 侧条件 UPDATE `WHERE lifecycle_state='draining'`）。nil-tolerant 端口 `SetLifecycleReconciler`。

## 分期

| 期 | 内容 | 状态 |
|---|---|---|
| G1 | domain（flowrun StatusCancelled + ListRunningByWorkflow；workflow ErrAlreadyActive/ErrNoTriggerEntry + MarkInactiveIfDraining）+ store（MarkRunTerminal 守卫 + 两个新查/改 + schema CHECK +cancelled） | ✅ `204065d0` |
| G2 | scheduler（inflight 注册表 + KillWorkflow + CountRunning + Advance ctx-track + markRunTerminal reconcile 收口）；trigger（once + AttachOnce + fanOut 自动摘） | ✅ `204065d0` |
| G3 | workflow.Service（Binder/Runner 端口 + Reconciler 实现 + 5 方法 + entryTriggerRefs + ReattachActive） | ✅ `204065d0` |
| G4 | 5 tools(7→12) + HTTP（:trigger/:stage/:kill 新增、:activate/:deactivate 改调 Activate/Deactivate）+ bootstrap（端口注入 + runnerAdapter + boot reattach）+ 测试（执行编排 fake / kill 打断阻塞 agent -race / stage 一次性撤防） | ✅ `204065d0` |
| 文档 | api.md（5 端点）+ database（cancelled）+ error-codes（3 错误）+ domains（workflow/trigger/scheduler/flowrun）+ contract #50 + STATE/ROUNDS/order(D1✅,D2✅,波次6✅) | ✅ 本提交 |

**R0066 全完成**：散落 D1 从「1 个 Run now」纠正成 5 工具/端点的完整执行生命周期。build/vet/gofmt/全模块 0 FAIL。kill 的 ctx 取消打断阻塞 agent 已 -race 证明（终态 cancelled 非 failed）。

## 不做（明确）
- overlap BufferOne/BufferAll、resume-mid-agent = 仍 v2（D4），不碰。
- stage 只对入口是真实 trigger 源的 workflow 有意义；纯手动入口只有 trigger/kill 适用（entryTriggerRefs 空→错）。
- danger 不在工具声明（LLM 逐次自报，S18）；kill 自然会被 LLM 标 dangerous → 走 R0064 确认门。
