---
id: DOC-015
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# trigger —— 信号源实体 + durable 收件箱

## 1. 定位

独立的信号源：source 条件满足即 fire（cron 刻度 / webhook / 文件变化 / sensor 探测），把信号**扇出**给所有监听它的 active workflow。trigger 是**配置实体**——无版本模型、无 sandbox/env（Config 是自由 map，加 source 种类不改列）。**故意没有 manual 源**——手动跑是 workflow 自己的能力（`:trigger`），不监听任何东西。

## 2. 心智模型（三层职责切分）

```
infra listener（4 种，只知道"我这个 trigger 做了 X"）
   │ ReportFunc(triggerID, Activity{Fired, Payload, DedupKey…})
   ▼
app onReport（解析 workspace + 监听者；Detached(wsID) ctx）
   │ fanOut：写 1 条 Activation（必写）+ Fired 时每监听 workflow 1 条 Firing
   ▼
durable 收件箱 trigger_firings（pending）……scheduler 每 5s 逐 workspace drain
```

- **Activation**（`tra_`）= "trigger 动了一下"的审计——**触没触发都记**（sensor 每次探测都报，Fired=false 带 ReturnValue/Error/Detail——这让"为什么没触发"可查）；cron/webhook/fsnotify 只在真 fire 时报。
- **Firing**（`trf_`）= **persist-before-act** 的收件箱行：fire 瞬间先落库、早于任何 flowrun。单一 status 枚举即处置结果：pending→claimed（claim 事务内瞬态）→started（终态-ok）；skipped（overlap skip）/superseded（overlap buffer_one——丢更早的等待 firing）/**shed**（资源上限**或所属 workflow 已被删**——后者 F137：`claimFiring` 见 `overlapDecision` 的 `GetWorkflow` 返 `WORKFLOW_NOT_FOUND` 即终态 shed 之，而非留 pending 让 `DrainFirings` 每 tick 重试这条永远成不了 run 的孤儿）/**missed**（misfire 记账，工单⑨，见 §2.5）。skipped/superseded/shed/missed 皆**中性处置**、非错误——UI 归「未执行」桶、不染红。
- **引用计数监听**：N 个 active workflow 共享一个 trigger 只跑**一个** listener（0→1 Register 启动、1→0 Unregister 停止；注册表在内存，boot 由 workflow.ReattachActive 重放）。`RefCount/Listening` 是读时算的非列字段；**`LastFiredAt`** 同为读时派生（非列）——List/Get 各行从 activation 日志取最近一条 `fired=true` 的 `created_at`（走 `idx_tra_ws_trigger` 一次 First；单用户触发器少、无 N+1），供行显示「N 前 fire」。**`NextFireAt`**（仅 cron）亦读时派生（非列）——`attachRuntime` 用 `croninfra.NextAfter(expression, now)` 算下次调度触发，供行显示「N 后触发」（非 cron 或 expr 不可解析则 nil；**已暂停投影 nil**——cron entry 已摘、根本没有排程）。
- **持久暂停开关**（`paused` 列 + `:pause`/`:resume`，scheduler 工单⑦）：暂停 = **不再产生任何新 firing**——底层 source listener 在源头注销（cron 摘 entry / webhook 路径 404 / fs watch 停 / sensor 探测停，**机器停、非只闸扇出**），内存 entry 保留引用集并标 `paused`（`RefCount` 不丢、`Listening=false`），`onReport` 再兜住注销落地前抢进的在飞报告（丢弃、不落 Activation）；手动 `:fire` 大声拒 `TRIGGER_PAUSED`。**在途 run 与已 pending 的 firing 不受影响**（暂停前的合法事件，scheduler 照常消化）。持久列使重启仍暂停（boot Attach 见 paused 建 entry 不 Register）；resume（仍有引用时）用**当前** config 重注册——暂停期间的 Edit 在此生效（`restartIfListening` 对暂停 entry 跳过）。两端点幂等、200 返裸 trigger；每次真转移发 entities 流 ephemeral `status` 信号 `{paused}`（照 mcp status 先例，`paused` 行是重连真相）。
- **一次性待命**（stage）：`AttachOnce` 标记 once，fanOut 后自动 Detach（可能把 listener 1→0 停掉）。

## 2.5 misfire = 跳过 + missed 记账（工单⑨，判决⑥）

桌面 app 会睡、会被关，cron 刻度会掉在地上。判决：**绝不补跑**（睡醒补跑风暴是本地 app 的真实危险），但也**绝不静默吞掉**——每个错过的刻度落一条 `missed` firing 行（中性「未执行」台账，UI 渲灰 ✕）。

- **检测 = 逐 trigger 水位**（`triggers.missed_checked_at`）：语义 =「此刻及之前的每个刻度都已**入账**」。`SweepMisfires` 对每个**正在监听、未暂停**的 cron trigger 走 **`(水位, max(hotSince, now − croninfra.MisfireTolerance)]`**（水位 NULL 或早于 `created_at` 时以 `created_at` 兜底——昨天建的 trigger 不可能错过去年）。**水位不是 lastFiredAt**：后者只记「真 fire 过」、无法表达「这段无人监听/被暂停，不欠账」。
- **窗口上界 = 刻度「再也开不出火」之处、不是 `now`**：
  - **活 listener 要留容差**：它仍认可迟于其刻度至多 `MisfireTolerance` 的回调（`snapTick`），故落在这条尾带里的刻度**仍可能真开火**（笔记本睡着、GC、写锁争用）。此时记 `missed` 会占掉该刻度的 dedup 键，随后到来的真 fire 撞键、`AppendFiring` 返回那条 missed 行——**没有任何可跑的 firing 产生**，workflow 悄无声息地不跑，而台账赌咒说它错过了。两个容差是**同一个导出常量**（`croninfra.MisfireTolerance`）——写成两份必然漂移回这个竞态。
  - **但下界是 `hotSince`（本进程最后一次 Register 该 listener 的时刻），这是常态而非细节**：cron entry 的首次触发从它被排入的那一刻算起，故 hotSince 及之前的刻度**已经死了**（上个进程的 entry 随进程而去、本进程的 entry 永不送达它们），**立刻**可入账。否则**一次重启自己错过的刻度**——桌面 app 上这事最日常的形状——会在 boot 后两分钟内于台账上不可见，而那正是用户开面板问「我错过什么了吗」的窗口。`hotSince` 在 attach 的 0→1 Register、`:resume`、Edit 热更重注册三处盖章（内存态；entry 不存在或已暂停则为零）。
  - 尾带不是被吞：水位同样只推到窗口上界，故它在下一趟 sweep（1min 后）成为可入账时被记下。
- **推进四处**：①每次 cron 扇出后（送达的刻度即已入账）②sweep 收尾（整窗查到**窗口上界**，见上——刻意不含尾带）③`:resume`（**暂停期间的错过不算 misfire**——暂停是用户意志、非事故；resume 把窗闭合但**不产生任何 missed 行**）④**实时** 0→1 挂载（trigger 此前是冷的、无人监听 → 之前的刻度不欠账；今天激活绝不记昨天的账）。**boot 重放（`AttachReplay`）刻意不推进**——那段正是必须记账的停机缺口。
- **两条 attach 语义**（Binder 端口）：`Attach`=实时激活（盖挂载纪元 now）· `AttachReplay`=boot 重放（盖**零值**纪元 =「本进程之前就在监听」）。sweep 以 per-workflow 纪元为下界：中途才挂上的 workflow 绝不被记它挂载前的刻度。
- **幂等 = dedup key，非标志位**：missed 行用与活 listener **完全相同**的刻度键（`croninfra.DedupKey(trigger, tick)`，分钟截断），故 `idx_trf_dedup` 保证一个刻度对每个 workflow 恰入账一次——**fired 与 missed 互斥**，sweep 跑几次都一样（`AppendFiring` 撞键返已存在行）。
- **扇出必须读 `AppendFiring` 的返回行**：撞键时它返**已存在行 + nil**——nil 错误的意思是「这个键已有着落」、**从来不是**「你这次 fire 产生了一次 run」。故 `fanOut` 按返回行的 status 分流：`pending`=可跑（计数）· `missed`=判词被推翻，经 **`RequeueMissedFiring`** 把该行救回 `pending` 让 run 真跑（计数）· 任一终态=该刻度已有处置，本次扇出不产生 run，故 `firingCount` **不许**为它 +1。只看 err 不看行，就会得到「`firingCount:1` + 台账说 missed + workflow 从没跑」三方互相矛盾。
- **落戳诚实**：missed 行 `created_at` = 错过的**调度刻度**（`AppendMissedFiring` 在 orm 盖 now 后定点回拨）；否则整夜停机的每条行都自称睡醒那一秒发生、时间线上挤成一堆。`flowrun_id` 恒空——missed 不是 run。
- **两处 sweep 入口**：boot（**严格在 `ReattachActive` 之后**——sweep 读监听表才知道谁在监听，表空则静默什么都不记）+ 自己的慢 ticker（`misfireInterval`=1min）——笔记本睡一小时醒来、进程**还活着**的 misfire 与关机一模一样，没有重启，只有正在跑的 sweep 会发现。
- **listener 侧守卫**：睡醒时 robfig 会补送**一次**过期回调；`snapTick` 把回调吸附到 now 及之前、`croninfra.MisfireTolerance`(2min) 内**最近**的刻度，无此刻度即判为墙钟跳变伪 fire 并丢弃——否则那就成了一次**隐式补跑**、背叛判决⑥。缺口交给 sweep 记账。**该丢弃只对比容差稀疏的调度才真的发生**：`* * * * *` 永远有刻度落在最近两分钟内，故它的睡醒伪 fire 会吸附到**当前**刻度而非被丢（无害——该刻度本就到期，dedup 键使它恰算一次）；守卫真正防的是「醒来把昨夜 03:00 隐式补跑一遍」。
- **`catchup_one`**（逐 trigger 自选，`config.misfirePolicy`，默认 `skip`）：记账之后对**最近一个真落账**的错过刻度经正常 fanOut 补一次 fire（origin 仍 cron、并发策略照常，与真 cron run 无从分辨）；更早的刻度仍是 `missed`——「补一个」就是一个。
  - **闸门 = 本趟真落账的刻度、不是窗口里装着什么**：已入账的刻度（dedup 命中——它 fire 过、或上趟已记）不许再补。「重查一个什么都记不下的窗」正是本 sweep 要扛的崩溃窗（扇出已提交、`AdvanceMissedWatermark` 没有、进程死在两者之间），按 `len(ticks)>0` 开火就是把同一刻度跑**第二遍**。
  - **补跑用刻度自己的键、无 `|catchup` 平行键**：扇出落在刚记的那条 `missed` 行上、把它 `RequeueMissedFiring` 成这次 run——**一个刻度、一行台账、一个处置**，且 `idx_trf_dedup` 像管别的 fire 一样管住补跑。平行键会让台账**同时**断言该刻度既错过了又跑了（与本节「更早的刻度仍是 missed」自相矛盾），且它会是 dedup 索引唯一管不到的开火径。
- **有界（台账 + 遍历两道）**：①**台账**单次 sweep 每 trigger 封顶 `maxMissedPerTrigger`(200) 条、保留**最近**的刻度（`* * * * *` 跨一周关机 = 1 万刻度，全记只淹台账不增真相）。②**遍历**封 `maxMisfireLookback`(30d)——首次 sweep 前水位恒 NULL，窗下限回落 `created_at`（升级中的安装＝trigger 有多老就多老），把 `* * * * *` 展开一年 = 五十万次 robfig `Next()`，且跑在**同步 boot 径**上。先用 cap+1 的探针判「窗里到底装没装下超过 cap 个刻度」：**没有**（稀疏调度，如每周一次的 cron 停机半年 ≈ 26 刻度）→ 整窗**分毫不差**记下，地板碰都不碰；**装下了** → 重锚到地板再走（那些老刻度本来也要被 cap 丢掉）。代价是刻意的：cadence 粗于 ~3.6h 且缺口 >30d 的调度（如日更 cron 停机一年）记最近 30 天、而非 cap 的 200 天——与 cap 同一条理由（超过一定量的计数是噪声）。两道封顶下水位照样跳到窗口上界，故老缺口恰入账一次、绝不重走。
- **无新事件**：missed 与其兄弟处置（skipped/superseded/shed）同族——它们都只写行、不发信号（`MarkFiringOutcome` 先例）；firing 行是真相，前端经 `GET {id}/firings?status=missed` 读。missed **不**上铃铛（trigger 无生命周期通知）、不染红。

## 3. 去重（D3：`idx_trf_dedup` = UNIQUE(workflow_id, trigger_id, dedup_key)）

`AppendFiring` 幂等：撞键返已存在行（不丢不重）。**UNIQUE 永久，故 key 必须含时间成分**（裸内容键会永久吞掉之后的合法重复触发）。四源各自的"同一物理事件"标识：

| 源 | DedupKey | 折叠什么 | Fire Payload（trigger 节点 result、下游按 node id 读） |
|---|---|---|---|
| cron | trigger + tick 时刻 | 同一刻度的重复材化 | `{firedAt}` |
| webhook | sha256(body) 前 8 字节(16 hex) + **分钟桶** | 秒级网络重试；下一分钟起同 payload 照常触发 | `{firedAt, method, path, headers, body(JSON 解析)\|bodyRaw(非 JSON 原串)}`；外部 POST 到 `/api/v1/webhooks/{triggerId}/{config.path}`（config.path 只是子路径） |
| fsnotify | path + op + **秒桶** | 编辑器一次保存的事件突发 | `{firedAt, path, eventKind}`；**eventKind 用配置词汇**（create/modify/delete/rename/chmod 小写、组合事件 `\|` 连，非 fsnotify 原始大写 Op）——`configEventKind` 在交付端归一 |
| sensor | trigger + probe 时刻（秒） | 一次探测至多一条/工作流 | = `config.output` CEL 产出的形状（作者自定义） |

> **sensor = 电平触发（level-triggered，F65）**：dedup key 含 probe 秒戳，故每个轮询周期条件为真都 fire 一条新 firing——**持续坏态会每 poll 反复触发**（非 false→true 边沿一次）。alert-storm 由 listener workflow 的并发策略兜住（默认 `serial` 排队；要单跑设 `skip`/`buffer_one`）。**无内建 edge-trigger/跨 poll 状态**——只想"翻转时触发一次"须在 handler 条件里自存上次状态。create_trigger 工具描述同款记此节奏。

**`outputs` 字段（声明下游可读的 payload 字段）**：cron/webhook/fsnotify 在 create/edit 时由 `triggerdomain.CanonicalOutputs(kind)` **盖上**（= 上表 Fire Payload、**覆盖作者所填、永不与 listener emit 漂移**）；sensor 由作者按 `config.output` 自定义、app 不覆盖。`CanonicalOutputs` 须与 listeners 的 fire payload 同步。**被 workflow `capability_check` 消费**（F95）：trigger 的 `Outputs` 经 `RefInfo.DeclaredOutputs` 灌入，使下游 `start.<field>` 读如普通 producer 一样校验——读不在其中的字段 → 建议性 warning（cron/webhook/fsnotify 因 canonical 盖定故是 sound 提示、sensor 因作者声明故 advisory）。

## 4. 生命周期 / 行为

- **4 源 config**（`ValidateConfig` 按 kind 分检）：cron=robfig **5 段**表达式（分钟粒度，与分钟桶 dedup 一致；`@every`/秒级不支持，错误消息指路）（`TRIGGER_INVALID_CRON`）；webhook=挂载路径 + 可选 secret（**明文**：caller 带 `X-Webhook-Secret: <secret>` 头或 `?token=<secret>` 查询；**HMAC**（config `signatureAlgo:"hmac-sha256-hex"`）：caller 带 `X-Hub-Signature-256: sha256=<小写 hex hmac_sha256(rawBody,secret)>` 头、头名可经 config `signatureHeader` 改；不匹配 → 401 纯文本响应，不走标准 envelope 错误码）；fsnotify=路径(必填) + 可选事件类型 + 可选 pattern；sensor=周期 invoke function/handler/mcp（targetKind 三选一；handler/mcp 需 method=方法名/工具名，function 整体即单元）+ CEL 条件（`TRIGGER_INVALID_CEL`/`TRIGGER_INVALID_INTERVAL`/`TRIGGER_SENSOR_TARGET_REQUIRED`）+ **目标存在性 eager 校验**（F102，与 F96/F98/F112 同族）：经 `SensorTargetValidator`（bootstrap 装、走 function/handler 的 `Get` + mcp 的 `ResolveServerID`）在 create/edit 即拒 dangling 目标→`TRIGGER_SENSOR_TARGET_NOT_FOUND`（details 带 targetKind/targetId），免其绑上 dangling `equip` 边、首探才大声失败；validator 允许 nil（未全装配的测试跳过）。
- **Edit 热更**：正在监听的 trigger 用新 config 重 Register（**已暂停的跳过**——新 config 在 `:resume` 时生效）。
- **Edit 只写实体列、碰不到运行时轴**：Edit 是「读→校验→写」，经 **`EditTrigger`** 定点 UPDATE `name/description/config/outputs`，**绝非整行 upsert**（`SaveTrigger` 只归 Create）。`paused`（工单⑦）与 `missed_checked_at`（工单⑨）只归 `SetTriggerPaused` / `AdvanceMissedWatermark`：产品有 chat agent 的 `edit_trigger` 工具，「agent 在改、用户同时按 ⏸」真实可达，而整行 upsert 会把读时拷贝写回盘——**止血阀被无声弹回、且跨重启永久丢失**，水位一并被回拨、重开一个已入账的窗。响应里的运行时轴写完**重取**（本次 Edit 没看见的 `:pause` 才是真相）。
- **`:fire`**（FireManual）：手动催一次——扇给当前监听者（可能 0 个，那就只是一条 0 firing 的 Activation）。**合成 payload 仅 `{manual:true}`、不带自定义数据**（要给 workflow 喂测试数据走 `trigger_workflow`，非 `:fire`）。**已暂停 422 `TRIGGER_PAUSED`**（暂停语义见 §2 持久暂停开关——agent/UI 都绕不过）。
- **`:pause` / `:resume`**：运行时调度止血阀（工单⑦，语义全文见 §2 持久暂停开关）——幂等、同步 200 裸 trigger、暂停跨重启持久、在途 run 不受影响。两者经 `switchMu` **互相串行**（各是横跨 DB 写与监听表写的读-改-写，并发交错会让行与监听表就「暂停没暂停」各执一词）。
- **Resume 的 Register 失败 = 回滚成可重试的暂停**：source 拒绝起来时，持久开关**翻回 `paused=true`**、entry 的 paused 保持、错误上抛。绝不能留 `paused=false` + 冷 listener——attach 只在 0→1 引用时 Register，而 entry 一旦自称已恢复，第二次 `:resume` 就是 no-op，那个状态**只有重启出得来**，行却还赌咒说它在跑。保持暂停才诚实且**可重试**：source 一好，再按一次 `:resume` 即可。
- webhook 异步 fire + recover（handler 不被慢/panic 拖累）、202 立即返回。
- **webhook 路由模型**：listener 在 `New` 时只挂**一个 catch-all** route（`/api/v1/webhooks/` 前缀，共享 mux 上独占此前缀）；Register/Unregister 只动内存 registry map（`full path → registration`），mux 永不增长。catch-all 用确切请求路径重建 registry 键派发，registry miss → 404（Unregister / Edit 改路径后旧路径自然 404）。**故意不 per-trigger HandleFunc**——stdlib ServeMux 不能 unmount，且重注册一个已注销路径会因重复 pattern panic；单 catch-all 两患皆除。
- **优雅关闭 join**：进程退出 `Shutdown` 顺停 4 listener。cron `Stop` 阻塞至 `cron.Stop()` ctx Done、fsnotify `Stop` `wg.Wait()`、**sensor `Stop` cancel 所有探测 goroutine 后 `wg.Wait()` join**（探测中途的 Invoke 持 function/handler 子进程，须收尾再让调用方 `db.Close`）；webhook `Stop` no-op（mux 归 HTTP server）。

## 5. 关键设计决策

listener 永不知道 workflow（扇出是 app 的事）；Activation 与 Firing 分开（观测 vs 待办——名字即语义）；收件箱轮询（5s tick）而非事件驱动——单进程本地的简单正确选择，serial 推迟的 firing 天然在下个 tick 重试；trigger 实体（trg_）与 firing 运行时（trf_）是两回事（对位 approval 的 apf_ vs 运行时 parked 行）。

## 6. 契约（引用）

端点（CRUD + `:fire`/`:pause`/`:resume`/`:iterate` + activations 两查询 + `GET {id}/firings` + **`GET /trigger-schedule`**〔工单⑧ 前瞻时间线，有界免游标〕）→ [api.md](../api.md) · 表（`triggers`〔含 `paused`/`missed_checked_at` 演化列〕/`trigger_activations`/`trigger_firings`——后两张 Log）→ [database.md](../database.md) · 码 `TRIGGER_*` 17+3 → [error-codes.md](../error-codes.md) · ID：`trg_`/`tra_`/`trf_`。LLM 观测工具：`search_activations`（"它**有没有 fire**"——逐次动作日志，含未 fire 的 sensor 探测因）+ `get_activation` + **`search_firings`**（"它 fire 了但 workflow **跑没跑、为什么没跑**"——firing 收件箱的处置面：started/pending/skipped/superseded/shed/missed；status 过滤经 `FiringStatuses` 封闭集校、非法值 422 `TRIGGER_FIRING_INVALID_STATUS` 而非静默空页，F175-M7 + F168-M2 延伸）。activations vs firings = 触发面 vs 运行面，名字即语义。

## 7. 跨域集成

被 workflow 经 Binder 端口驱动（Attach/AttachOnce/**AttachReplay**〔boot 重放，工单⑨：只有它盖零值挂载纪元，故 sweep 才敢为其记停机缺口〕/Detach）；firings 被 scheduler 经 FiringInbox 端口消费（ListPendingFirings/ClaimFiring 单事务/MarkFiringOutcome/SupersedeAllButNewestPending + **TriggerKind**——claimFiring 给 run 盖 origin 溯源章用，软删 trigger 读作 not-found、调用侧 best-effort 留 NULL）；sensor listener 经 invoker 端口调 function/handler/mcp（bootstrap/sensor.go 适配，TriggeredBy=workflow；sensor 出向 `equip` 边按 targetKind 指 function/handler/mcp 实体）；catalog/mention/relation 三适配器同构。
