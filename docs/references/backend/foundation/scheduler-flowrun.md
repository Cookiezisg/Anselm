---
id: DOC-013
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Scheduler 与 Flowrun

## 1. 定位

`app/scheduler` 是 durable workflow 解释器；`domain/flowrun` 与
`flowruns`/`flowrun_nodes` 保存一次执行的状态。引擎使用节点结果记忆化和
幂等重走，不使用事件溯源。Advance 与 drain/timeout 解耦的取舍见
[`ADR 0007`](../../../decisions/0007-scheduler-async-advance-pool.md)。

一次 run 的两把确定性锁：

- `flowruns.version_id` 冻结 workflow graph；
- `flowruns.pinned_refs` 冻结可版本化引用的 active version。

Handler 是活态常驻实例，MCP 是无版本外部 server，不进入版本 pin。

## 2. Record-once

`flowrun_nodes` 每行表示 `(node_id, iteration)` 的结果。
`idx_frn_once(flowrun_id,node_id,iteration)` 保证首写赢：

```text
Advance(runID)
→ 读取冻结图与现有节点行
→ 推导 ready 集
→ 执行或求值
→ record-once 写节点行
→ 重复直至 terminal 或 parked
```

一次 Advance 在内存追加刚写成功的行，避免每轮重读全部 result；发生
record-once 冲突时重新从数据库取得权威行集。崩溃恢复只是再次 Advance：
completed 行复用，未落行 activity 可能重跑，因此外部副作用仍要求下游幂等。

节点只写 `completed|failed|parked|cancelled`，不写瞬时 running。
`parked` 表示 approval 等待；`cancelled` 只用于已赢得 run 头取消守卫后收割
parked obligation，不可出现在可 replay 的 run 上。

`ready_at` 是该节点轮次首次进入 ready 集的时间，`started_at` 是引擎开始
求值 input/派发的时间。两者随唯一一次节点 INSERT 落库；被取消且未落结果的
activity 不写节点行。

## 3. Walk

每轮在冻结图和当前行集上构造派生视图：

1. 创建 run 时，trigger seed 与 run 头在同一事务写入。
2. 从 seed 做可达遍历；未决 control 暂时开放出口，已决
   control/approval 只放行选中 port。
3. 节点 ready 当且仅当：已到达、尚无该轮节点行、所有 live 入边源均
   completed。被剪枝入边不参与，因此同一规则同时表达 AND join 与分支 merge。
4. 被选中的 back edge 进入下一 iteration；ready 集按节点声明序与轮次稳定
   排序，`MaxIterations` 限制失控循环。

节点 Input 是以祖先 node id 为根的 CEL。每个已声明但尚无 completed result
的根绑定为空 map，使 `has(loopNode.field)` 在首轮可安全为 false。
Control result 是 emit 字段加保留键 `__port`；Approval result 是
`decision` 与 `reason`。

## 4. 创建与触发

### 手动

`StartRun`：

1. 读取 active workflow version；
2. `BuildPinClosure` 解析引用版本；
3. 选择入口（显式 entryNode、匹配 trigger ref、或唯一 trigger）；
4. 单事务写 run 头和 seed；
5. 同步 drive 至 terminal 或 parked。

HTTP 直接启动的 origin 为 `manual`。Chat 的 `trigger_workflow` 通过 ctx 的
conversation id 盖 `chat` 与 `conversation_id`。

### Firing

自动路径先按 workflow concurrency 判断：

| 策略 | 在途 run 存在时 |
|---|---|
| `serial` | 保持 pending，下次 drain 再试 |
| `skip` | firing → skipped |
| `buffer_one` | 只保留最新 pending |
| `replace` | 取消在途 run，再启动新 run |
| `allow_all` | 并发启动 |

`ClaimFiring` 在单事务内 claim pending firing、seed run、回填 started，避免
claimed-without-run。Workflow kill 先把剩余 pending firing 标记为 shed。
Firing origin 来自 trigger kind；已删除 trigger 导致无法解析时 origin 可
缺席，但不阻止 run。

两个创建入口提交后都发送 durable `run_started`。Replay 重开既有 run，
不发送 started。

## 5. Approval

Approval 渲染后写 parked 行，run 继续保持 running。人工决定和超时都通过
`ResolveParkedNode` 对 `status='parked'` 做条件更新，first-wins：

- reject → `decision=no`；
- approve → `decision=yes`；
- fail → run failed。

`DeadlineFrom(parkedAt)` 是 timeout scanner 与 inbox `deadline` 的共同来源。
空 timeout 表示永不超时。周期扫描 parked 行是系统的 durable timer；不另存
定时器对象。

决定落库后专门发送 approval node tick；Advance 重入看到现有决定行时不会
重复发 tick。

## 6. 失败、Replay 与取消

### 失败与 Replay

节点失败写 failed 行并 fail-fast 终止 run；已 completed 的兄弟结果保留。
Replay 只接受 failed run：

1. `ReopenForReplay` 以 `WHERE status='failed'` first-wins 翻回 running；
2. 物理删除 failed 节点；
3. `replay_count++`；
4. 再次 drive，复用 completed、重跑被清节点。

Cancelled 是终局，不能 replay。Retention 与 replay 的删除边界见
[`database.md`](../database.md)。

### 取消

Workflow kill、replace 和单 run `:cancel` 共用：

1. `MarkRunTerminal(cancelled)` 以 `WHERE status='running'` 仲裁；
2. 只有赢家收割 parked 节点为 cancelled；
3. 只有赢家取消该 run 的在飞 drive ctx；
4. 只有赢家发送 durable `run_terminal`。

若自然完成/失败先赢，取消方不得改写头、收割 approval 或发送第二终态。被
drive ctx 打断的节点返回内部 interrupted 结果，不落 failed 行；节点自己的
超时仍是业务失败。

单 run cancel 对非 running 返回 `FLOWRUN_NOT_CANCELLABLE`。取消 draining
workflow 的最后一个 outstanding run 后，执行与自然终态相同的
draining→inactive 结算。

## 7. 终态与 Attention

completed、failed、cancelled 都通过 first-wins 的头状态写入。
`afterRunSettled` 只有在 workflow 没有 running run 且没有已接受 pending
firing 时才把 draining 收为 inactive。

- completed/failed/cancelled 的赢家发 durable `run_terminal`；
- failed 发 `workflow.run_failed` 并点亮 attention；
- completed 可清除 attention；
- cancelled 是用户处置，不点亮或清除 attention。

## 8. 执行并发

Firing drain 的 claim/seed/overlap phase 严格有序；seed 后的 Advance 进入
有界 worker pool。Recover 与 approval timeout redrive 也入池。手动
Start/Decide/Replay 同步 drive，以便调用方直接得到落定状态。

`drive` 保证同一 run 单飞。并发 redrive 只置标志，当前 driver 结束后在 ctx
仍有效时再走一轮。SQLite 使用单连接，pool 的并行收益主要来自 sandbox、LLM
和 MCP 等 I/O。

关停顺序：

```text
stop drain and timeout feeders
→ bounded wait for feeder exit
→ bounded wait for active work
→ mark scheduler closing
→ cancel inflight drive contexts
→ stop pool
→ close DB
```

Closing 标志使队列中尚未开始的 run 保持 running，由下次 boot Recover；
不得在关停时把 detached 队列无限跑完。队列关闭与 late sender 的竞态按
“丢当前 enqueue、boot 恢复”处理，不得使进程 panic。

## 9. Boot 恢复与后台上下文

Boot `Recover` 枚举所有 still-running run 并入池。恢复时重新计算
ready_at；崩溃前未落库的内存时间戳不伪造为连续。

所有无请求 ctx 的后台入口必须逐 workspace 播种：

```text
forEachWorkspace
→ reqctx.Detached(workspaceID)
→ reattach / drain / timeout / retention work
```

裸 `context.Background()` 不得执行 workspace-scoped store 查询。

## 10. Retention

机器级 `runRetentionDays` 控制终态 run 历史；`0` 表示永久。Sweep 在 boot、
周期 ticker 与 PATCH retention 后运行：

- 只删 cutoff 之前且 `completed_at` 非空的
  completed/failed/cancelled；
- running 与 parked obligation 永不删除；
- 同事务删 run 节点及该 run 的四类执行审计；
- 删除头时再次守卫终态，使并发 replay 胜出；
- firing、notification、touchpoint 保留，允许 flowrunId 悬挂。

删除行后可调用 `infra/db.ReclaimFreePages` 回收 SQLite freelist；这不删除
业务行。完整物理边界见 [`database.md`](../database.md)。

## 11. API 投影

- `GET/POST /flowruns`：运行历史与手动启动；
- `GET /flowruns/{id}`：run 头与分页节点；
- `GET /flowruns/{id}/activity`：执行审计 UNION 时间线；
- `POST /flowruns/{id}:replay|:cancel`；
- `GET /flowrun-inbox`；
- `GET /flowrun-stats`；
- `GET /flowrun-matrix`；
- `POST /flowruns/{id}/approvals/{node}:decide`。

精确 query、响应与错误见 [`api.md`](../api.md) 和
[`error-codes.md`](../error-codes.md)。LLM 工具
`get_flowrun`、`search_flowruns`、`replay_flowrun`、
`decide_approval` 与同一 app service 对齐。

## 12. 派发

Scheduler 通过窄端口派发：

```text
(ctx, ref, pinnedVersionID, input)
```

- Function、Agent 执行 pinned version；
- Handler、MCP 使用活态绑定；
- Control、Approval 在解释器内解析 pinned version 并求值；
- dispatch 前把 flowrun id、node id、iteration 注入 ctx，使 execution/call
  审计与节点真相对账；
- `OK=false` 转换为节点失败并 fail-fast。
