---
id: DOC-043
type: decision
status: active
owner: @weilin
created: 2026-06-21
reviewed: 2026-06-21
review-due: 2099-12-31
audience: [human, ai]
---

# 0007 — Scheduler async Advance worker pool (head-of-line-blocking fix)

## 背景

durable 引擎的执行驱动原是**单 goroutine 串行内联**：`drainLoop`（每 5s tick）逐 workspace 调 `DrainFirings`，phase-2 的 `s.Advance` **内联**把节点跑到完成；`CheckTimeouts` 排在同一闭包里。`Advance` 的节点执行（function sandbox / agent LLM turn / handler RPC / MCP 请求）可达**分钟级**。

后果（F174 实测）：一个慢节点把那**一个** goroutine 占死整段时长，连锁卡住——本 run 后续节点、同批后面的 run、后面所有 workspace、`CheckTimeouts`（审批超时也卡）、以及下一个 tick。drain wave ≈ Σ(在途节点时长)、非 5s。3×30s-sleep workflow：buffer_one pending 1→7 不 collapse、running=0 整 60s、wave ~100s。

## 决策

把 phase-2 `Advance` 从 drain/timeout 循环**解耦**到一个**有界 worker 池**（`advanceWorkers=4`，`pool.go`）：

- **`DrainFirings` phase-1**（claim / seed / overlap 决策）**保持严格顺序+有序**——overlap 策略（serial/skip/buffer_one/replace，见 [F138]）的正确性依赖每个存活者在下一条 firing 被决策前已落 running、`CountRunningByWorkflow` 数到它。**只 phase-2 并行**：把每个 seed 的 run **入队**到池，drain goroutine 只 claim+入队即返回。
- **`Recover`（boot）/ `CheckTimeouts→settleTimeout`** 同样入队——慢的恢复节点不阻塞 boot；超时扫描跑在**独立 `timeoutLoop` ticker** 上，满载的池绝不饿死审批超时结算。
- **手动路径**（`StartRun`/`DecideApproval`/`Replay`）仍**内联**经 `drive` 同步跑到终态/parked——一个用户、一个 run，本无 HOL，保住 `StartRun` 「跑到终态才返回」契约。
- **per-run 单飞 guard**：`drive` 强制同一 run 同时至多一个 goroutine advance（原是串行驱动器的**副产物**、现是**显式不变式**）；并发触发同一 run 时其余置 redrive 标志、活跃驱动者再走一轮。record-once 护持久性、guard 防重复副作用。
- **池未启动**（测试 / 纯手动部署）时 `enqueueAdvance` **内联驱动**——现有 firing/overlap 测试保持同步、零改动。

## 候选方案 & 取舍

| 方案 | 取舍 | 结论 |
|---|---|---|
| **A. 有界 worker 池（按 flowrunID 单飞）** | 封顶子进程扇出（R 系列）；复用现有 inflight cancel map；per-run guard 确定性防双驱；手动路径保持同步=测试零改 | ✅ **采纳** |
| B. 每 run 一 goroutine（无界） | 写法最简、并行最大 | ❌ 突发 firing / 大 boot Recover 炸 fd/进程数；SQLite 单连接已串行 DB，多 goroutine 只增争用 |
| C. 仅批内并行 + CheckTimeouts 独立 | DrainFirings 仍 block-until-driven，测试免 quiescence helper | ❌ **没真修 HOL**：最慢 run 仍占死 drain 整 tick、卡下一 tick |

## 并发安全论证

- **SQLite 单连接**（`SetMaxOpenConns(1)` + busy_timeout + WAL）：所有 durable 写 Go 层串行——并发 Advance 在连接上排队、无 SQLITE_BUSY 升级竞争、无死锁（慢调用**不持连接**，节点结果是慢调用后单独 bounded INSERT）。**绝不调高 MaxOpenConns**（db.go 注释明令）。池只在 I/O 密集的慢调用上买到并行。
- **handler 常驻**：并发打同一 handler 在其单 mutex stdio 管道上串行（叶子锁、无嵌套、不死锁）；不同 handler 自由。
- **record-once**：`InsertNodeResult` first-wins（`idx_frn_once` UNIQUE），对任何并发写同 (run,node,iter) 安全。
- **kill / replace**：保留「先标 cancelled（WHERE running）再 cancel ctx」序——异步化使 cancel 真能打断在飞 worker（更强、仍正确：被打断 advance 的 failNode 匹配 0 行 no-op）。per-run guard 保证恰一个 worker 持该 run 的 cancel。
- **timeout 结算**：`ResolveParkedNode` first-wins（WHERE parked）防与 `DecideApproval` 双结算；`afterRunSettled` 的 `MarkRunTerminal` 必须先于 `CountRunningByWorkflow`（单连接串行此读后写、无丢唤醒）。
- **关闭（R3/F100）**：停 ticker → 等循环返回 → `WaitPoolDrained`（宽限）→ `scheduler.Shutdown()`（cancel 全部在飞 ctx）→ `StopPool()`（WaitGroup 等 worker 退出）**才** `db.Close`。
- **SSE / notify**：entities bridge 互斥守、notification Emit 无状态（落 DB 串行 + bridge 守）——并发 worker 调用安全。

## 已知可见影响（非回归）

异步后在途 run 存活更久 → `CountRunningByWorkflow` 见正数更久 → serial/buffer_one **defer 更多**、replace **取消更多**。这是**正确语义**（run 确实还在飞）、非 bug；测试断言新（正确）行为、不是旧的串行-collapse 行为。

## 后果

- HOL 在每个层面消除：慢节点跑在池 worker 上、drain/timeout 循环只做快的纯 DB 活。
- N=4 **硬编码**（非 settings 旋钮）：SQLite 单连接 + handler 单管道使吞吐天花板结构性地低，小 N 吃满收益又封顶扇出。以后要调再升为旋钮。
- 不可变；要改并发模型须新建一篇 supersede 本篇。
