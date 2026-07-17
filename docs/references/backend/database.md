---
id: DOC-009
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# 数据库 —— 表 / ID 前缀登记

> 物理 schema 的单一事实源（表 · 关键列 · 索引/约束 · ID 前缀），覆盖全部 32 域。DDL 全文在各 `infra/store/<域>` 的 `Schema`（搜索域在 `infra/search`），幂等 `CREATE IF NOT EXISTS`，启动时 `db.Migrate` 单事务应用。
> 通则（D 系列）：业务表软删 `deleted_at`；Log 表（executions/calls）**只增不删**（D1——物理删的两个例外都在 flowrun 节逐个立法：`:replay` 清 failed 行 / run 历史保留清理）；全表带 `workspace_id`（orm 据 ctx 自动隔离，D2）；name 用 partial-UNIQUE `WHERE deleted_at IS NULL`（软删释放名字）；版本表 `UNIQUE(<entity>_id, version)`。
> **时间戳约定**：实体表与版本表统一带 `created_at` + `updated_at`（orm `,created`/`,updated` tag 自动戳，写时刷新 updated_at）；**Log 表（executions/calls/activations/notifications 等只增审计行）只带 `created_at`**——行写一次不改，updated_at 无意义（D1）。下方各表列清单省略这套标准时间戳，不逐张列。

## 三实体共同形状

每实体三张表：**主表**（身份 + `active_version_id` 指针，软删）· **版本表**（不可变快照，只增，cap 50 裁剪但放过 active）· **执行/调用 Log 表**（终态审计，只增）。Log 表统一溯源列：`conversation_id / message_id / tool_call_id`（chat 路径，ctx 注入）+ `flowrun_id / flowrun_node_id / flowrun_iteration`（workflow 路径，调度器 ctx 注入；`flowrun_iteration` 是循环轮次，使 `(flowrun_id,flowrun_node_id,iteration)` 与 `flowrun_nodes` 真相行 1:1 join——回边 loop 中同节点多轮的审计行否则不可区分，F175-M12）；CHECK 约束 `status IN (ok,failed,cancelled,timeout)` + `triggered_by`。

## function

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `functions` | name · description · tags(json) · active_version_id | partial-UNIQUE(ws,name)；ws+created 游标索引 |
| `function_versions` | version(int) · code · inputs/outputs(json) · dependencies(json) · python_version · **env_id/env_status/env_error/env_synced_at**（env 镜像）· change_reason · built_in_conversation_id | UNIQUE(function_id,version) |
| `function_executions` | version_id · status · triggered_by(chat/agent/workflow/manual) · input/output(json) · error_message · **logs**（print/调试输出，logtail 头尾限长 64KiB；List 置空、仅单条 Get 携带） · elapsed_ms · started/ended_at · 溯源 6 列（含 flowrun 3 列：id/node_id/iteration） | CHECK ×2；ws+function / ws+conversation / ws+flowrun 偏索引 |

ID：`fn_` `fnv_` `fne_` · env：`fnenv_`（infra 侧自有前缀）

## handler

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `handlers` | （同上）+ **config_encrypted**（init-args 值，AES-GCM 加密存盘） | 同上 |
| `handler_versions` | version · **imports / init_body / shutdown_body / methods(json MethodSpec[]) / init_args_schema(json InitArgSpec[])** · dependencies · python_version · env 镜像 4 列 | UNIQUE(handler_id,version) |
| `handler_calls` | method · status · triggered_by(含 agent) · input/output · **logs**（yield + 调用窗口内 stderr，logtail 限长；List 置空） · **instance_id** · 溯源 6 列（含 flowrun 3 列：id/node_id/iteration） | 同款 CHECK + 索引 |

ID：`hd_` `hdv_` `hcl_` · env：`hdenv_` · 实例（内存态，不落库）：`hdi_`

## agent

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `agents` | （同上，无 config） | 同上 |
| `agent_versions` | version · **prompt · skill(0-1 名) · knowledge(json docIDs) · tools(json ToolRef[]) · inputs/outputs(json) · model_override(json)** · change_reason · built_in_conversation_id | UNIQUE(agent_id,version) |
| `agent_executions` | model_id（实际跑的模型）· **api_key_id + provider**（服务该次运行的凭证溯源——区分暴露同名模型的两个 key、provider 即便 key 已删也自描述；run 在解析 LLM 前失败则 api_key_id 回落到 override 的、provider 留空，F155/F154）· status · triggered_by(chat/workflow/manual，**无 agent**——员工不调员工) · input/output · **transcript(json，完整 block 序列——运行的自包含耐久记录，不入 message_blocks)** · 溯源 6 列（含 flowrun 3 列：id/node_id/iteration） | 同款 |

ID：`ag_` `agv_` `agx_`（agent 无 env——不写代码无 sandbox）

## workflow / control / approval（同构对：主表 + 版本表）

| 表 | 特有列 | 约束 |
|---|---|---|
| `workflows` | active(bool) · **lifecycle_state**(CHECK active/draining/inactive) · **concurrency**(CHECK serial/skip/buffer_one/replace/allow_all，DEFAULT serial) · needs_attention/attention_reason/last_action_by | partial-UNIQUE(ws,name) |
| `workflow_versions` | **graph**(JSON blob：nodes+edges) | UNIQUE(workflow_id,version) |
| `control_logics` / `control_logic_versions` | versions：inputs(json) · **branches**(json Branch[]：port/when/emit) | 同构 |
| `approval_forms` / `approval_form_versions` | versions：inputs · **template**(markdown+{{CEL}}) · allow_reason(bool：是否允许填备注) · timeout("30d"/"2w"/""=永不) · timeout_behavior(reject/approve/fail) | 同构 |

ID：`wf_`/`wfv_` · `ctl_`/`ctlv_` · `apf_`/`apfv_`

## trigger（配置实体 + 两张 Log）

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `triggers` | kind(CHECK cron/webhook/fsnotify/sensor) · **config**(自由 json map;cron 的 `misfirePolicy`=skip\|catchup_one 存这里、**不加列**,工单⑨) · outputs(json) · **paused**(INTEGER NOT NULL DEFAULT 0——运行时暂停开关,工单⑦:持久化使重启仍暂停) · **missed_checked_at**(DATETIME NULL——misfire 水位,工单⑨:「此刻及之前的每个 cron 刻度都已入账」;NULL=从未入账,窗下限回落 created_at。每次 cron 扇出/sweep 收尾/`:resume`/实时 0→1 挂载时**单调**推进[裸 UPDATE 守卫 `< ?`],且刻意**不**碰 updated_at——机器记账不该搅动行的编辑时间) | partial-UNIQUE(ws,name) |
| `trigger_activations`（Log） | kind · fired(bool) · return_value/payload(json) · error · detail · firing_count | 按 trigger+created 索引 |
| `trigger_firings`（Log，durable 收件箱） | trigger_id · workflow_id · activation_id · payload(json) · **dedup_key** · status(pending/claimed/started/skipped/superseded/shed/**missed**) · flowrun_id | **`idx_trf_dedup` UNIQUE(workflow_id,trigger_id,dedup_key)**（D3）+ pending 偏索引 + **读三索引**（工单⑭，见下）：`idx_trf_ws_created(workspace_id,created_at DESC,id DESC)` · `idx_trf_ws_status(workspace_id,status,created_at DESC,id DESC)` · `idx_trf_ws_trigger(workspace_id,trigger_id,created_at DESC,id DESC)` |

> **`missed` 处置与 CHECK 重建**（工单⑨，判决⑥）：`missed` = app 停机/睡眠期间到期的 cron 刻度，**记账不补跑**。行 `created_at` = 错过的**调度刻度**（非 sweep 时刻——否则整夜停机的每条 missed 行都自称睡醒那一秒发生；经 `AppendMissedFiring` 在 orm 盖章后定点回拨），`flowrun_id` 恒空。**幂等即 dedup_key**：missed 行用与活 listener 完全相同的刻度键（`croninfra.DedupKey`），故 `idx_trf_dedup` 保证一个刻度对每个 workflow 恰入账一次、**fired 与 missed 互斥**，无论 sweep 跑多少次。**`missed` 不是终态**：唯一出口 = `RequeueMissedFiring` 把它翻回 `pending`（守卫 `status='missed'`，故绝不可能把跑过的行救活），两个调用方同一含义「这个刻度终究要跑、`missed` 的判词被推翻」——`catchup_one` 刻意补跑它刚记的最近一个错过点，以及 dedup 键被 missed 行占住的扇出（sweep 判早了、真 fire 还是来了）。被救回的行保持回拨到刻度的 `created_at`（drain 最老优先，补跑本就是等得最久的那个），故**一个刻度始终只有一行**、台账绝不同时说它既错过又跑了。
>
> **`trigger_firings` 读三索引**（工单⑭）：此前**没有任何**索引带 `workspace_id`，而 orm 给每条查询前置 `workspace_id = ?`（D2）——故每次 firing 读都是**全表扫 + 临时 b-tree 排序**，只因从没有人在 workspace 尺度读过这张表才一直没露馅（`idx_trf_pending` 是 `WHERE status='pending'` 偏索引、只服务 drain）。三条各自是某个真实查询**唯一**的可索引依靠，实测 129,600 行（每分钟 cron 跑 90 天）+ 第二 workspace + 一个稀有 trigger：`idx_trf_ws_created` → Overview 24h 轨道（ws+时间窗、全状态）**23.9ms → 802µs**；`idx_trf_ws_status` → 「错过 N」计数（**覆盖索引** **15.8ms → 23µs**）与 missed 深链，在**健康** workspace 上决定性（`status=missed` 零匹配，别的索引要走遍整个 ws 才能证明：**7.7ms → 31µs**）；`idx_trf_ws_trigger` → 逐 trigger firing 串，**并非可选**——有 `ws_created` 而无它时 SQLite 会为 `trigger_id=?` 选择走 `ws_created`，稀有 trigger 的一页要 **49.6ms**、**比它取代的 14.4ms 全表扫更慢**（只加 ws_created 就是发一个回归；有它则 144µs）。均为**纯 additive `CREATE INDEX`**（不重建表、结果幂等）；写代价可忽略（firing 插入受 cron 刻度限速）。守卫=`firings_plan_test.go` 经记录型 driver 抓下 store **真正**跑的 SQL 再 `EXPLAIN QUERY PLAN`，断言索引名 + **完整谓词签名**（只断言索引名不够：把一个界包进 `julianday()`，计划照样点到索引而查询已在走遍全 ws）；时间数字不入门禁（会 flake）。
>
> **列演化两径**（SQLite 现实）：加列走 `ALTER TABLE ADD COLUMN`（结果幂等，`duplicate column name` = 已应用；先例 flowruns `origin`、triggers `paused`/`missed_checked_at`）；**CHECK 加词无法 ALTER**，须**整表重建**——`db.MigrateRebuild(table, marker, stmts…)` 查 `sqlite_master` 现行 DDL，仅当标记词缺席才在单事务内建新表→逐列拷贝→删旧→改名→重建索引（结果幂等：全新安装的 CREATE 已含新词 → 永不重建；重建后每次启动 no-op）。`trigger_firings.status += 'missed'` 是首例。



ID：`trg_`/`tra_`/`trf_`

## flowrun（两张 Log——引擎的全部状态）

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `flowruns` | workflow_id · **version_id**(钉死拓扑) · **pinned_refs**(json pin 闭包) · trigger_id/firing_id · **origin**(可空,CHECK manual/chat/cron/webhook/fsnotify/sensor——创建时溯源盖章,NULL=两列诞生前旧行) · **conversation_id**(可空,仅 origin=chat:发起 run 的 cv_) · status(CHECK running/completed/failed/cancelled) · replay_count · error | **五索引**：`idx_fr_ws_created(workspace_id,started_at DESC,id DESC)` · `idx_fr_ws_workflow(workspace_id,workflow_id,started_at DESC,id DESC)` · `idx_fr_running(status) WHERE status='running'`（**偏索引、无 workspace_id**——跨 ws boot 恢复刻意跨隔离）· `idx_fr_ws_wf_status(workspace_id,workflow_id,status,started_at DESC,id DESC)`（连败游走，见下）· `idx_fr_ws_status_completed(workspace_id,status,completed_at DESC,id DESC)`（**工单⑮**「24h 失败」牌深链，见下）；origin/conversation_id 经 `ALTER TABLE ADD COLUMN` 演化段补列（db.Migrate 对加列的 duplicate-column 按已应用跳过=结果幂等）|
| `flowrun_nodes` | flowrun_id · **node_id**(图内名) · **iteration**(循环轮次) · kind · ref · status(CHECK completed/failed/parked/**cancelled**——立法见下) · **result**(json 记忆化) · error · **ready_at/started_at**(可空排队戳,工单⑫——立法见下) | **`idx_frn_once` UNIQUE(flowrun_id,node_id,iteration)**（D3 record-once）+ parked 偏索引（收件箱）；ready_at/started_at 经 `ALTER TABLE ADD COLUMN` 演化段补列（同 flowruns origin 结果幂等先例）；status 加词 `cancelled` 经 **`db.MigrateRebuild`** 整表重建（SQLite 无 ALTER CHECK；结果幂等=查现行 DDL 缺标记词才重建，全新安装与重建后启动皆 no-op；同 `trigger_firings` += `missed` 先例）|

ID：`fr_`/`frn_`。两张无 deleted_at（D1）；**物理删恰有两个例外，逐个立法在此**（除此之外这两张表只增不删）：

**D1 例外① `:replay` 清 failed 行**（`DeleteFailedNodes`）：failed 行是**非结果**，删它让幂等重走重跑——record-once 真相不损、什么历史都没抹。

**D1 例外② run 历史保留清理**（scheduler 工单⑬、判决④；`PurgeTerminalRunsBefore`）——**性质与①不同：它删的是真实历史**，故立法必须显式：

- **为何正当**：这是**用户配置的容量治理**、不是业务逻辑偷偷丢行。线是显式的（Settings → 存储 → 「Run 历史保留」，见 [api.md](api.md) `retention` 段）、服务端自持（默认 90d，`0`=永久）、在 UI 里诚实（run 大表翻到线上出**墓碑行**「更早的运行已按保留策略(Nd)清理」，绝不静默留缺口），且**保留窗内的审计真相完整**——保留线只决定「多久之前的历史不再留」，绝不改写窗内任何一行。所有统计与失败聚合窗口（≤7d）远在默认线之内，天然不受影响。
- **删什么**（只删 run **自己**的行）：`flowruns` 头 + 它的 `flowrun_nodes` 行 + **该 run 产生的**审计行（四张执行日志表 `function_executions`/`handler_calls`/`agent_executions`/`mcp_calls` 中 `flowrun_id = <该 run>` 的行——存储面板的回收承诺落在这里：payload 是字节的大头，清 run 却留 payload = 承诺落空）。从对话跑的同实体审计行 `flowrun_id = ''`、**不受影响**。四表间无 FK（schema 未声明）故无级联，**子先于父、全在一个事务里**。
- **不删什么**（旁系台账各有自己的真相轴）：trigger `firings`（`idx_trf_dedup` 是 D3 去重铁律，删它即破幂等）、`notifications`、touchpoint 行**一律留存**——它们的 `flowrunId` 成**悬挂引用**，深链落 404、呈现端渲孤儿墓碑（前端 §13 先例）。这是保留线的已知且诚实的后果。
- **删的边界**：只删**终态**（completed/failed/cancelled）且 `completed_at` **非 NULL 且严格早于** cutoff 的行。**running/parked 永不删，不管多老**——在飞的 run 不是历史，等人的 run 是活的义务（收件箱绝不因一个时钟丢项）。终态但 `completed_at` 为 NULL 的行也留（断不了年份的破坏性清理必须留，不能猜）。窗口按 **`completed_at`** 开——与 flowrun-stats 的 `completedSince` 逐字同源：跑了很久刚失败的 run 是**新鲜**的、不是旧的。
- **怎么删**：逐 workspace（`forEachWorkspace` + Detached ctx，S9）分批（`RetentionBatchSize=200`/事务——DB 单连接，无界 DELETE 事务会阻塞所有其他写）；批间查 ctx 使关停在**批边界**停（已提交的批保持提交、下个 tick 续）。删头时**重申终态守卫**：SELECT 与 DELETE 之间的一次 `:replay` 会把 run 翻回 running，清理必须**输掉**这场竞速（重开它意味着用户要它）。谓词是**裸** `completed_at < ?`（与本表所有 completed_at/started_at 窗一致——同一种规范 UTC 文本格式内文本序即时间序，`TestTimeText_OrdersChronologically` 钉死；工单⑮ 把清理从 `julianday()` 拆到裸比较，统一一条规则），排序键 `completed_at ASC` 无覆盖它的升序索引故每批走一次扫描——本地单用户量级可接受、不为一次后台卫生加升序索引。
- **触发时机**：boot 起一趟 + 每 6h ticker + 每次 `PATCH /retention`（收紧的线立刻回收、而非 6h 后才像是生效）。线为 `0`（永久）时**碰都不碰 DB**。

**`flowruns` 索引立法（五索引，逐个是某条真实查询的唯一可索引依靠）**：`idx_fr_ws_created`/`idx_fr_ws_workflow` 服务运行历史分页（ws / +workflow，`started_at DESC` 排序）；`idx_fr_running` 是 `WHERE status='running'` **偏索引、刻意不带 workspace_id**——它唯一的消费者 `ListRunningRuns` 是 boot 恢复、**跨 workspace** 扫在途 run（那也是这张表唯一跨隔离的读）。

- **`idx_fr_ws_wf_status(workspace_id,workflow_id,status,started_at DESC,id DESC)`**（连败游走 stats.go ④）：「有没有比这条 failed 更新的 completed」是逐行 EXISTS，无 status 列则每次探测扫遍该 workflow 所有更新的行、**恰在 workflow 正在失败时**扫空 ⇒ 在连败长度 K 上呈平方。实测 129,600 行 K=4000：**4.27s → 0.397s** 且**平**（K 离开运行时）。守卫 `stats_bench_test.go`。
- **`idx_fr_ws_status_completed(workspace_id,status,completed_at DESC,id DESC)`**（**工单⑮**，Overview「24h 失败」牌深链 `?status=failed&completedAfter=`）：其余索引全按 `started_at` 排、`completed_at` 窗根本 seek 不了，且形状又是那个恶毒的——**健康 workspace 才爆炸**（页要 51 行、24h 内只 ~4 次失败 ⇒ SQLite 沿 `idx_fr_ws_created` 走遍整个 workspace 证明没有第 5 条）。实测 129,600 行 + 第二 workspace：**50.3ms → 33.6µs**（1,507×），且比无 status 的 `(ws,completed_at)` 变体快 17.5×。**并非可选、且不是回归**（工单⑭ 教训）：逐条实测既有五读全不动、各守自己的索引；唯一真代价是**不带 status 的裸 `?completedAfter`** 改选本索引 53µs→731µs（无消费者、亚毫秒、且是「给 completed_at 加索引」本身的固有代价、窄窗上反转，接受不藏）。守卫 `flowrun_plan_test.go` 经记录型 driver 抓下 store **真正**跑的 SQL 再 `EXPLAIN QUERY PLAN`，断言索引名 + **完整谓词签名**、且**用真实边界**（非 NULL——本索引靠选择性赢、NULL 参数下规划器看不见窗窄会误报）。均为**纯 additive `CREATE INDEX`**（不重建表、结果幂等），写代价一个索引/run 头。
- **时间比较全裸**（无 `julianday()`）：落库 DATETIME 与绑定 time.Time 走同一序列化器（`2026-07-17 10:00:00+00:00`，hex 实证两侧同）、写者全盖 `.UTC()`、Go 去小数尾零 ⇒ 一种规范 UTC 格式内文本序**即**时间序（`TestTimeText_OrdersChronologically` 钉 225 对 + UTC 前提 + julianday 只到毫秒的反例）。工单⑮ 前 stats `since` 窗曾包 `julianday()` 声称「归一格式漂移」——**实测无漂移**，且 `julianday()` 只到毫秒 ⇒ 一个界前 0.4ms 落定的 run 被牌数进、被 `?completedAfter` 列表排除 =「牌上写 3、点开列表显示 4」，故拆掉。`julianday()` 只余 stats ① 的 `AVG(julianday(a)-julianday(b))`（时长**算术**、非窗口）。

**节点 status 立法（CHECK 四值 `completed`/`failed`/`parked`/`cancelled`）**：

- **只写终态**（`parked` 是唯一非终态：approval 挂起前写它，决策/超时再翻它）——无瞬时 running 行；「哪些 run 在等人」从 parked 行派生（parked 行即收件箱，无投影表）。
- **`cancelled` = 中性处置、非故障**（呈现层「未执行」桶，与 skipped/superseded/shed 同族——染红即假警报）。**唯一写者** = `CancelParkedNodes`：收割被手动停掉的 run（`:cancel`/kill/replace）所 park 的审批。记 `failed` 是**无中生有**一次该 run 从未有过的失败——真实因（cancelled）在 run 头上，故读**节点**的消费者（矩阵格/台账行/byStatus）会与头**自相矛盾**：灰 run 上的红格、没有错误文字却自动展开的失败台账行。
- **★ 让它对引擎免费的不变式**：`cancelled` 行**只**存在于头为 `cancelled` 的 run 上——收割**闸在赢得头守卫**（`MarkRunTerminal` 的 `won`）上，而 cancelled run 是**终局终态**（`:replay` 只收 failed、`Recover` 只收 running）⇒ **解释器永不在 walk 中观察到 cancelled 行**，它不在 `completed()` 咽喉里也就零代价。**破了那道闸**（让 first-wins 输家也收割）它就成「有行、却未 completed」：`hasRow` 挡住重排 + `predecessorsSatisfied` 挡住每条下游边 = 一个 `:replay` 也清不掉的**永久停滞子图**（`DeleteFailedNodes` 只收 failed 行，且见上方 D1——不容第三个删）。输家的 run 走到的是它自然的终态；若那是 `failed`，其 parked 行仍然活着（`:replay` 能救回 run、人仍可决策），这也正是 `failRun` 路径同样从不收割的原因。
- **与 `nodeInterrupted` 正交**：被取消 ctx 打断的在飞节点走 `failNode` 的 interrupted-bail、返内部伪状态 `interrupted` 并**不写任何行**（不在 CHECK 四值内、绝不落库）；`cancelled` 则是把**已存在的** parked 行收成终态。前者「不写」，后者「收已写的」。
- **加词的落地**：SQLite 无 ALTER CHECK ⇒ 已有安装经 `db.MigrateRebuild` 整表重建（结果幂等：查 `sqlite_master` 现行 DDL 缺标记词才重建；全新安装的 CREATE 已含该词故 no-op，重建后每次启动亦 no-op）。重建须逐列拷贝**含经 `ALTER ADD COLUMN` 补的 `ready_at`/`started_at`**（原 CREATE 从未提它们）并重建三个索引——其中 `idx_frn_once` 是 **D3 record-once 键**、随旧表一起落，忘了重建即**静默卸掉 record-once 本身**。

**排队戳立法（scheduler 工单⑫——`ready_at`/`started_at` 的语义，含 replay/恢复呈现）**：

- **定义**：`ready_at` = 该 (节点,轮次) 在某次驱动的 walk 中**首次被算出 ready** 的时刻（排队起点；同批节点共享同一瞬——它们同轮变 ready，批内靠后节点排在兄弟顺序执行之后，其 ready→started 间隔是真实等待）；`started_at` = 引擎**开始处理**该节点的时刻（input CEL 求值 + 派发——执行实体自身的执行起点在其审计行的 started_at）。排队段 = ready_at→started_at；执行段真相在执行日志行。
- **record-once 不损**：戳在驱动期间**内存暂存**、随该行**唯一一次**终态/parked INSERT 落盘——行仍只写终态（无先插行后终化）；被打断的驱动什么都不写、戳随之消亡。parked 行带挂起时的两戳，决策/超时（`ResolveParkedNode`）只翻 status/result/completed_at、**戳保留**。
- **:replay**：failed 行物理删后重跑，在**同 iteration 写新行=新戳**（新的排队起点）；completed 旧行被抄不重跑、**戳逐字保留**。执行日志的旧失败尝试行仍在（Log 不删），其 started_at 可**早于**新真相行的 ready_at——呈现端把排队段钳制 ≥0。
- **崩溃恢复**：内存戳不越过崩溃；boot `Recover` 重走时 walk 重算 ready → `ready_at` = **恢复驱动**的 walk 时刻（诚实：恢复是新的排队起点，绝不回填原排队时刻伪装无缝）。at-least-once 下同 (节点,轮次) 可有多条审计行，ready_at 属于 record-once **真相行**（成功写行的那次驱动）。
- **NULL 语义**：⑫ 前旧行与 seed trigger 行（run 创建时原子写入、从不排队）恒 NULL；线缆 omitempty 不发键，缺席即诚实。

## skill / mcp / document

| 表 | 关键列 | 说明 |
|---|---|---|
| **skill：无表** | — | 文件式：`~/.anselm/workspaces/<ws>/skills/<name>/SKILL.md`（目录/条，纯按需扫描） |
| `mcp_servers` | transport(stdio/sse/streamable-http) · runtime(node/python/docker/dotnet) · command/args · url · **config_enc**（加密的 {env,headers,oauth}——Env/Headers/OAuth 凭据束均非列）· timeout_sec · source(registry/manual/import) · registry_id | 软删；partial-UNIQUE(ws,name) |
| `mcp_calls`（Log） | server_id · tool · status/triggered_by(CHECK) · input/output · **logs**（progress 通知 + 失败附 server stderr 尾，logtail 限长；List 置空） · elapsed_ms · 溯源 6 列（含 flowrun 3 列：id/node_id/iteration）| ws+server 索引 + flowrun 偏索引 |
| `documents` | parent_id(nullable=根) · name · content · **path**(物化全路径) · **position**(同级序) · size_bytes · tags | 软删；同父名唯一（应用层重试加后缀）；**position 单事务原子赋（`max(兄弟)+1`、防并发同父撞车）、无 position 唯一索引（Move/Duplicate 会重排/原样复制）** |

ID：`mcp_`/`mcl_` · `doc_`（skill 无 id——slug 即身份）

## 对话运行时族

| 表 | 关键列 | 说明 |
|---|---|---|
| `conversations` | title · auto_titled · system_prompt · **summary / summary_covers_up_to_seq**（压缩器写）· attached_documents(json) · archived/pinned · model_override(json) · **last_message_at**（最近活跃排序键：创建时=now、chat 每条消息刷；列表索引 `idx_conversations_ws_list (ws, pinned DESC, last_message_at DESC, id DESC)` + keyset 游标键此列）· `unread`（持久布尔，0/1：有完成的 assistant 回复未看=1[rail 绿点]。TouchLastMessage 折进同一 UPDATE 原子设——用户发送=0、assistant **完成**终态=1、非完成终态=0；MarkSeen[`:seen` 动作]清 0；创建默认 0。**非排序/游标键、无索引**；存布尔非时间/seq watermark→绕开墙上时钟比较，重启照样在） | 软删；`cv_`；三条排序覆盖索引各对一种 `?sort`：活跃 `idx_conversations_ws_list (…, last_message_at DESC, id DESC)` · name `idx_conversations_ws_title (…, title COLLATE NOCASE ASC, id ASC)` · created `idx_conversations_ws_created (…, created_at DESC, id DESC)`——每种 keyset 走各自列、避免全表扫 + filesort（R12 族） |
| `messages` | conversation_id · **subagent_id**（≠'' = subagent 产出）· role/status(CHECK) · stop_reason · error_code/message · input/output_tokens · provider/model_id（溯源）· attrs(json：附件/提及快照) | **append-only**（D1）；`msg_` |
| `message_blocks` | message_id · parent_block_id · **seq**（落盘分配）· type(CHECK 六型含 progress/compaction) · attrs/content · status · **context_role**(CHECK hot/warm/cold/archived——压缩投影) | append-only；`blk_` |
| `attachments` | sha256(内容寻址，非唯一) · filename · mime_type · kind(image/document/text/audio/video/other) · size_bytes · blob 字节在 infra/fs/blob 按 sha256 寻址 | 软删；`att_`；≤50MB |
| `todos` | **`scope_id`**(pk = subagent id ?? conv id) · conversation_id · subagent_id · items(json ≤64) | 整表替换写 |
| `conversation_touchpoints` | conversation_id · item_kind(relation 11 kind + attachment) · item_id · **item_name**(显示名快照，实体删后仍诚实可显) · verb(CHECK 7 动词) · last_actor(CHECK user/assistant/subagent) · count · first_at/last_at · last_message_id | **聚合行**：`UNIQUE idx_tp_dedup (ws, conversation_id, item_kind, item_id, verb)`（并发记账撞此收敛）+ `idx_tp_conv (ws, conversation_id, last_at)`（新鲜度分页）；**硬删**（派生台账，同 relations——唯一删除路径=对话删除级联 PurgeConversation，实体删除**不**清行[历程真相]）；`tp_` |
| **memory / subagent：无表** | — | memory=文件式（`workspaces/<ws>/memories/<name>.md`）；subagent=运行时机制（回合落父对话 messages） |

## search（统一搜索索引——派生数据）

| 表 | 关键列 | 约束/索引 |
|---|---|---|
| `search_docs` | workspace_id · entity_type(CHECK 12 类) · entity_id · chunk_no · anchor（message_id/方法名/工具名/标题链/节点 id）· title · body · tags(json) · archived | UNIQUE(ws,entity_type,entity_id,chunk_no)；`idx_sd_ws_entity`(ws,entity_type,entity_id)；`idx_sd_ws_updated`(ws,updated_at)——服务补算扫描/LIKE 回退的 `ORDER BY updated_at LIMIT` 走索引区间扫而非全表 filesort（R12） |
| `search_fts` | FTS5 **external-content 虚表**（content=search_docs，`tokenize='trigram'`，title/body 两列）+ 三触发器（AI/AD/AU）构造性同步 | bm25 权重 title:body=4:1 在查询侧 |
| `search_meta` | key/value：`fts_schema_version`（不匹配→boot 清空重建）· `embedder`（builtin\|ollama\|off，空=builtin，机器级） | PK(key) |
| `search_embeddings` | doc_id(=search_docs.id) · model · dims · vector(BLOB float32 LE)——model 逐行记账，换 embedder 旧向量直接可辨失效 | PK(doc_id) |

ID：`sd_`。**派生数据**：物理删（实体删/级联/重建即删行），D1 不适用、无软删。**D2 豁免点（全库唯一）**：FTS5 虚表在 pkg/orm 之外，`infra/search` 手写 raw SQL——每条查询显式 `workspace_id = ?` 谓词，隔离由专项测试钉死（`infra/search/search_test.go::TestSearch_WorkspaceIsolation`）。

## 支撑域

| 表 | 说明 |
|---|---|
| `workspaces` | **全局表（无 ws 列——它即 workspace）**；语言/三场景模型默认/默认搜索 key/`web_fetch_mode`（local\|jina，CHECK，空=local）；`ws_` |
| `api_keys` | 密文整列加密；probe 归档；软删；`aki_` |
| `relations` | from/to (kind,id) × edge kind；硬删（PurgeEntity 级联）；`rel_` |
| `notifications` | type(`<domain>.<action>`) · payload · read_at；`noti_`。只存 `Emitter.Emit`（落行档）的事件；`Broadcast` 档（rail/树对账回声）只推 SSE 帧、**此表无行**（分径见 [events.md](events.md) 「notifications 流」⊞/⤳） |
| `sandbox_runtimes` | runtime manifest（全机解释器/镜像：kind+version · path · size_bytes，`UNIQUE(kind,version)`）——**系统级**（无 ws 列、owner 无关）、**硬删**（盘上镜像是实体，墓碑无意义）；`sr_` |
| `sandbox_envs` | env manifest（owner kind+id · runtime · status）——**系统级**（owner-id 全局隔离、无 ws 列）、**硬删**（盘上目录是实体，墓碑无意义）；`se_` |
| catalog / mention / model / websearch / aispawn / humanloop / contextmgr / entitystream：**无表** | 派生/契约/运行时机制 |

> **运行时/infra ID 前缀（无表，S15 仍登记）**：`sig_`（entitystream 信号帧 id）· `bsh_`（shell 工具的 bash 进程句柄）· `subagt_`（subagent run id）· `hdi_`（handler 实例，见 handler 节）。infra 侧 ID 一律用自己前缀、不从消费实体 id 派生。
