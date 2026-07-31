---
id: DOC-008
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# HTTP API —— 端点登记

> 全部 HTTP 端点的 method、path 与 wire 语义登记。路由代码是物理事实，
> 本文由 `make -C docs verify` 检查资源词覆盖。

### 通用形状

- 成功信封为 `{"data": ...}`，错误信封为
  `{"error":{"code","message","details"}}`；wire 字段使用 camelCase。
- 无界集合使用 `cursor` + `limit`。有界枚举资源和有界批查返回全集，无
  `nextCursor`；批查的输入上限在对应端点明确登记，越界必须报错。
- 派生投影不使用游标。带窗口参数的 `trigger-schedule` 以 `truncated`
  报告截断；无参数的 `storage-stat`、conversation workdir 与
  workdir-groups 不接收窗口或截断参数。
- Create、单读和 Patch 的 `data` 内层是裸实体；版本实体以内嵌
  `activeVersion` 表达当前版本。复合读才使用具名多 key。
- 创建新资源的异步动作返回 `202 {"data":{"id":"..."}}`。同步
  `:run`、`:call`、`:invoke` 仍保留 N1 信封，但 `data` 内不再增加
  `result` 或 `output` 外壳。
- 改变实体状态的动作返回动作后的完整实体快照；无新产物的变更和 DELETE
  返回 `204 No Content`。
- 非 CRUD 动作使用 `:action`；标准执行动词为 Function `:run`、Handler
  `:call`、Agent `:invoke`、Workflow `:trigger`。

### SSE

`GET /api/v1/messages/stream` · `GET /api/v1/entities/stream` ·
`GET /api/v1/notifications/stream`。三条均为 workspace 级常驻流，frame
契约见 [events.md](events.md)。

## function（`/api/v1/functions`）

| Method · Path | 语义 |
|---|---|
| `POST /functions` | 创建（扁平 payload → 反推 ops 走构建管线），201 |
| `GET /functions` | 分页列表（`?search`：`name` 大小写不敏感子串过滤） |
| `GET /functions/{id}` | 单读（附 activeVersion：代码+env 状态一趟拿全） |
| `PATCH /functions/{id}` | 改 meta（name/description/tags，不升版本） |
| `DELETE /functions/{id}` | 软删 + 销毁 env + 清边，204 |
| `POST /functions/{id}:run` | 执行（TriggeredBy=manual），body `{args, version?}` |
| `POST /functions/{id}:revert` | active 指针移到指定版本号 |
| `POST /functions/{id}:edit` | ops 构建新版本（空 ops = 仅重建 env） |
| `POST /functions/{id}:iterate` | 开 AI 编辑对话，返 `conversationId` |
| `GET /functions/{id}/versions` | 版本分页 |
| `GET /functions/{id}/versions/{version}` | 单版本（接受版本号或 fnv_ id） |
| `GET /functions/{id}/executions` | 执行日志分页（`?status&triggeredBy&conversationId&flowrunId`）；返 `{data:{executions, aggregates}, nextCursor, hasMore}`——分页坐标顶层、聚合在 data 子对象(与 handler/agent/mcp 执行·调用日志同形) |
| `GET /function-executions/{id}` | 单执行详情（含 `logs`——print/调试输出；列表端点不带） |

## handler（`/api/v1/handlers`）

| Method · Path | 语义 |
|---|---|
| `POST /handlers` | 创建（扁平 → ops），201；**不 spawn 实例**（等 config 配齐/Boot/首调） |
| `GET /handlers` | 分页列表（`?search`：`name` 大小写不敏感子串过滤） |
| `GET /handlers/{id}` | 单读（附 activeVersion + configState + missingConfig + runtimeState） |
| `PATCH /handlers/{id}` | 改 meta |
| `DELETE /handlers/{id}` | 停实例 + 软删 + 销毁 env + 清边，204 |
| `POST /handlers/{id}:call` | 调方法（manual），body `{method, args}` |
| `POST /handlers/{id}:restart` | 手动重启常驻实例，返新 runtimeState |
| `POST /handlers/{id}:revert` | 移 active 指针 + 重启实例 |
| `POST /handlers/{id}:edit` | ops 构建新版本 + 重启实例（空 ops = 重建 env + 重启） |
| `POST /handlers/{id}:iterate` | 开 AI 编辑对话 |
| `GET /handlers/{id}/versions` · `GET /handlers/{id}/versions/{version}` | 版本（号或 hdv_ id） |
| `GET /handlers/{id}/config` | 读 config（sensitive 字段掩码 `********`） |
| `PUT /handlers/{id}/config` | JSON Merge Patch 更新（null 删 key）→ 整 blob 重加密 → **重启实例重跑 `__init__`** |
| `DELETE /handlers/{id}/config` | 清空 config + 停实例 |
| `GET /handlers/{id}/calls` | 调用日志分页（`?method&status&triggeredBy&conversationId&flowrunId`）；返 `{data:{calls, aggregates}, nextCursor, hasMore}`(同 function/agent/mcp 同形) |
| `GET /handler-calls/{id}` | 单调用详情（含 `logs`——yield + 调用窗口 stderr；列表端点不带） |

## agent（`/api/v1/agents`）

| Method · Path | 语义 |
|---|---|
| `POST /agents` | 创建（identity + 全量 Config 快照 = v1），201 |
| `GET /agents` | 分页列表（`?search`：`name` 大小写不敏感子串过滤） |
| `GET /agents/{id}` | 单读（附 activeVersion） |
| `PATCH /agents/{id}` | 改 meta |
| `DELETE /agents/{id}` | 软删 + 清边，204 |
| `POST /agents/{id}:invoke` | 跑 ReAct loop（manual），body `{input, version?}` |
| `POST /agents/{id}:revert` | 移 active 指针 |
| `POST /agents/{id}:edit` | 全量 Config 替换 → 新版本（**非** ops、非合并） |
| `POST /agents/{id}:iterate` | 开 AI 编辑对话 |
| `GET /agents/{id}/versions` · `/versions/{version}` | 版本分页 · 单版本（接受版本号或 agv_ id） |
| `GET /agents/{id}/mount-health` | 按需预检 active 版本各挂载（fn/hd/mcp）是否仍可解析（被删/离线/坏 ref），返 `{data:{mounts:[{ref,name?,healthy,error?}], allHealthy}}`——与 invoke 同解析路径、不 fail-fast。供 invoke 前红点预警（无 active 版本/无挂载 = 平凡健康） |
| `GET /agents/{id}/executions` | 执行日志分页（同款过滤）；返 `{data:{executions, aggregates}, nextCursor, hasMore}`(同 function/handler/mcp 同形) |
| `GET /agent-executions/{id}` | 单执行详情（含完整 transcript） |

## workflow（`/api/v1/workflows`）

| Method · Path | 语义 |
|---|---|
| `POST /workflows` · `GET /workflows` · `GET /workflows/{id}` · `PATCH /workflows/{id}` · `DELETE /workflows/{id}` | CRUD（PATCH=meta 不升版本；列表 `?search`：`name` 大小写不敏感子串过滤；DELETE 先摘入口 listener、取消在途 run，再软删主行/清 relation，activation/firing、flowrun 与 immutable versions 历史保留可审计）（含 `concurrency`: serial\|skip\|buffer_one\|replace\|allow_all——overlap 政策，下一次 drain 生效） |
| `POST /workflows/{id}:trigger` | 立即跑一次（任何 lifecycle 下可跑），body `{payload?}`（只读 payload），返 flowrun id |
| `POST /workflows/{id}:stage` | 待命恰一次真实触发后自动撤防（已 active → 409） |
| `POST /workflows/{id}:activate` / `:deactivate` | 上线（挂监听+active）/ 优雅下线（摘监听并 fence 已跨 listener snapshot 的 in-flight report；running run 与已接受 pending firing 排空前为 draining，完成后 inactive） |
| `POST /workflows/{id}:kill` | 硬停：摘监听 + 取消全部在途 run + 将已接受但仍 pending 的 firing 记为 `shed` + inactive，返动作后 workflow 实体快照（状态变更动作铁律，非裸计数） |
| `POST /workflows/{id}:edit` / `:revert` | 图 ops 构建新版本 / 移 active 指针 |
| `POST /workflows/{id}:capability-check` | ref 解析体检（实体、kind、port、method）；返 `problems`（阻断）+ `warnings`（含读取 producer 未声明 output field） |
| `POST /workflows/{id}:iterate` | 开 AI 编辑对话 |
| `GET /workflows/{id}/versions[/{version}]` | 版本 |

## flowrun（`/api/v1/flowruns`）

| Method · Path | 语义 |
|---|---|
| `GET /flowruns` | 两种互斥分页：keyset `?cursor&limit` → `{data,nextCursor?,hasMore}`；页码 `?offset=<非负整数>&limit` → `{data,total,hasMore}`。同给 cursor/offset 返回 `FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT`；非法 offset 返回 `FLOWRUN_LIST_INVALID_FILTER`。排序恒为 `started_at DESC,id DESC`。过滤按 AND 组合：`workflowId`、`triggerId`、`status=running\|completed\|failed\|cancelled`、`origin=manual\|chat\|cron\|webhook\|fsnotify\|sensor`、`startedAfter/Before`、`completedAfter/Before`。时间使用 RFC3339 半开窗；completed 窗排除 `completed_at IS NULL` 的行，并与 flowrun-stats 的完成/失败窗口使用同一谓词 |
| `POST /flowruns` | 手动起 run（= workflow `:trigger` 的等价入口），body `{workflowId, entryNode?, payload?}`（`entryNode` 消歧多 trigger 图——唯一接受 entryNode 的端点） |
| `GET /flowruns/{id}` | run 头 + 一页节点行；N4 `?cursor&limit`，最新在前，返 `nextCursor`。完整记忆化全集只供解释器内部读取 |
| `GET /flowruns/{id}/activity` | 四类执行日志按 flowrun_id UNION 的只读投影；行 `{nodeId,iteration,kind,execId,status,startedAt,endedAt,elapsedMs,readyAt?}`，`kind`∈function\|handler\|agent\|mcp；按 startedAt/id 升序，N4 分页。无节点真相时 `readyAt` 缺席；run 不存在返回 `FLOWRUN_NOT_FOUND` |
| `POST /flowruns/{id}:replay` | 修复失败 run：清 failed 行 + 重走（completed 复用）；**仅 failed 可重放**——cancelled 是终局终态、不可 :replay（422 `FLOWRUN_NOT_REPLAYABLE`） |
| `POST /flowruns/{id}:cancel` | 仅 running 可取消；DB first-wins 守卫后取消在飞 ctx、收回 parked approval、发 durable terminal。202 返 `{flowrun,nodes,nextCursor}`；否则 `FLOWRUN_NOT_CANCELLABLE` |
| `GET /flowrun-inbox` | parked approval 收件箱；行带 `workflowId`、`workflowName`、可选 `deadline`。软删 workflow 名回落 id；deadline 解析失败只省略该键 |
| `GET /flowrun-stats` | `?workflowIds=<csv>&recentN&since&until` → `{totals,byWorkflow}`；只读有界批查，含 `totals.missed` |
| `GET /flowrun-matrix` | `?flowrunIds=<csv，去重后 ≤50>` → `{cols,rows,cells}`；节点×run 的只读有界批查 |
| `POST /flowruns/{id}/approvals/{node}:decide` | 人工审批决策 `{decision: yes|no, reason?}`（first-wins，输家 422） |

flowrun 行 DTO 带创建时溯源两字段（camelCase、omitempty）：`origin`（manual|chat|cron|webhook|fsnotify|sensor——HTTP 手动=manual、对话 trigger_workflow=chat、firing 按 trigger kind 逐字盖）+ `conversationId`（仅 origin=chat：发起 run 的 cv_）。两列诞生前的旧行为 NULL、**线缆不发键**——客户端按缺席渲 unknown，不认空串。

flowrun 节点行的 `readyAt` 是首次被计算为 ready 的时刻，`startedAt` 是引擎
开始处理该节点的时刻；两者构成排队段。seed trigger 与无排队戳的行省略这些
键，落库语义见 [database.md](database.md)。

**`GET /flowrun-stats` 契约**（喂 scheduler 海洋 rail/Overview 的一次有界批查；有界故 **N4 分页豁免**——`workflowIds` 去重后 ≤50 封顶、超限 422 `FLOWRUN_STATS_TOO_MANY_IDS`（details 带 `allowed`），绝不静默截断）：
- 参数：`workflowIds`=csv（去重保序；缺席/空 → `byWorkflow: []` 只回 totals）；`recentN` 珠串窗（默认 10、钳到 20；非数字或 <1 → 400 `INVALID_REQUEST`，同 page limit 语义）；`since` 开窗起点（RFC3339 绝对起点 或 正回看时长 `24h`/`7d`，默认 7d；解析不了 422 `FLOWRUN_STATS_INVALID_SINCE`）；**`until`**=可选不含上界（**只**收 RFC3339 时间戳——归一 UTC；缺席 → **不设界**〔今日行为、零变化〕；解析不了 422 `FLOWRUN_STATS_INVALID_UNTIL`，details 带 `param`/`got`/`want`——与 flowruns 的 `?startedBefore` 同一份 `parseListTime` 解析）。`since`＋`until` 配成**半开窗 `[since, until)`**、是 `completedSince`/`failedSince`/`successRate`/`avgElapsedMs`/`missed` 的**唯一统一窗口**。**倒挂窗（`until` ≤ `since`）不是错误**——静默给出空窗结果，与 `GET /flowruns?startedBefore=` 同立场。**为何 `until` 刻意不收时长文法**：末端的回看时长有歧义（「从何时起回看」不明），且自定义绝对范围的**结尾**光靠 `since` 表达不了——故 `until` 只认绝对时刻。**不受 `until` 约束**（说清楚）：`running`/`parkedNodes`/`recent`/`lastRunAt`/`consecutiveFailures` 皆非窗口量，`until` 碰都不碰它们。
- `totals`（全 workspace，不限请求 ids）：`running` + `completedSince`/`failedSince`（按 `completed_at` 的 `[since,until)` 半开窗，与 `GET /flowruns?completedAfter=` 同谓词）+ `parkedNodes`（仍 running 且至少有一个 parked 节点的 distinct run）+ `missed`（窗口内 missed firing 数）。
  - **`missed` 是唯一不数 flowrun 的 total**——它数的是**本该存在却不存在**的 run，故本端点是 **Overview 的统计单源**、而非「仅 flowrun 两表的投影」：Overview 问的是**一个**问题（「我的自动化在这个窗口里过得怎么样」），一个从未成为 run 的刻度正是答案的一部分。数据源是 `trigger_firings`（跨域），由 app 层经 scheduler 既有的 **FiringInbox 端口**缝入（domain 只拥有形状、不伸手够 store）。
  - `missed` 与完成/失败统计共用 `[since,until)`；按 firing 的调度刻度 `created_at` 开窗，并与 `GET /firings` 使用同组谓词。它不提供 all-time 累计。
  - 无 firing 存储的部署（纯手动）读 0——那时根本不存在 firing，0 是**真相**；而计数**失败**不静默吞成 0（「你什么都没错过」与「我查不出来」是两句话），整个批查报错。
- `byWorkflow`：**每个请求 id 恒一行、按请求顺序**——无 run 的 id（从未跑/不存在/宿主已软删）回**零值行**、绝不缺席（纯 flowruns 投影、不校验 workflow 存在性；孤儿 run 一等公民）。行 = `workflowId` + `running` + `parkedNodes`（该 workflow 等人处理的 run 数——语义与 totals 桶逐字一致、按 workflow 分桶；rail 琥珀点的数据源）+ `lastRunAt?`（从未跑缺席）+ `recent`（最近 recentN 个 run 状态、新→旧、**含 running** 的诚实珠串）+ `successRate?`（窗口内 completed/(completed+failed)，0..1；cancelled 中性不参与；窗口无终态 run 键缺席——「无数据」≠「0%」）+ `avgElapsedMs?`（窗口内 **completed 且 `replayCount=0`** 的 run 的平均 `completedAt−startedAt`；无此类 run 键缺席）+ `consecutiveFailures`（按 run 序列 `(started_at, id)` 新→旧的连续 failed 数：**running 与 cancelled 均跳过**［前者未定局——连败徽章不因新 run 起跑/park 闪灭；后者中性——见下方 cancelled 立法］、**只有 completed 停**［自愈=证明跑通］；不受 recentN/since 约束）。

> **`cancelled` 在本端点的唯一立法**（三个字段逐字同款）：cancelled 是**中性处置**——「未执行」桶，既非错误亦非功劳。被手动停掉 / 被 replace 顶替的 run 对 workflow 健康**什么都没说**，故**两边都不算**：永不算失败，也永不算健康的证据；运行上与 running 同待遇（**透明**）。反例即代价：算失败 → 用户主动按的 ⏹ 读成故障；算健康 → 一次 ⏹ 就把正在进行的 3 连败整个从失败榜（前端按 `consecutiveFailures > 0` 过滤）抹掉，且用 `replace` 策略的 workflow（每个被顶替的 run 都**自动**取消）连败**永久钉在 ~1**、零用户动作。
>
> `avgElapsedMs` 只统计未 replay 的 completed run；failed 是“多久失败”，replay
> 会把人工修复间隔纳入同一个 run 头，均不能代表正常完成耗时。审批等待计入
> 墙钟。Matrix 的 `cols[].elapsedMs` 则表达单个 run 的真实跨度，因此包含
> replay 间隔与审批等待。

**`GET /flowrun-matrix` 契约**（喂 scheduler 运营主页页顶格阵 `AnRunMatrix`；**有界批查 → N4 分页豁免**——一次按**显式 run id 集**答完格阵，哪些 run 在屏上是客户端的事［它按时间窗文法翻 `GET /flowruns`、逐页拿 id 批取格阵，故本端点自身**不带任何窗口/近期参数**］；**两条**查询：请求的 run 头一条 orm `WhereIn`（重排回正典序）+ 这批 run 的全部节点行一条 `flowrun_id IN (…)`（走 `idx_frn_run`），**绝不逐 run 拉详情**；零 schema 变更）：

- 参数：`flowrunIds`=csv（**必填**——它**就是**格阵的内容：按请求序去重、空串跳过，去重后空集 400 `INVALID_REQUEST`（无 run 即无格阵，绝不铸一个无意义的空答案）、去重后 >50 → 422 `FLOWRUN_MATRIX_TOO_MANY_IDS`（details 带 `allowed`/`got`）——**逐字**沿用 flowrun-stats 的 ids 纪律：静默截断请求 id **会**撒谎，客户端拿屏上那页与答案对拉、会把短答案读成完整。**不校验 run 存在性**：未知/异 workspace 的 id **静默缺席**（cols 自带 `flowrunId` 键、缺席可发现——不同于 stats 的 1:1 零值行对拉；全未知返三个空列表）——孤儿 run 一等公民）。
- `cols`：一个 run 一列，按 `started_at DESC,id DESC` 排序，与请求 id 顺序无关。列为 `flowrunId`、`startedAt`、`status`、`elapsedMs?`；running 无 completed_at 时省略 elapsed。该值是 run 的墙钟跨度，包含审批等待与 replay 间隔；执行段比较使用 `/activity`。
- `rows`：一个节点 = 一行。行集 = 这批 run 里出现过的 `nodeId` **并集**，序 = **首次出现序**（扫列新→旧、每个 run 内按该节点自身执行序 `COALESCE(started_at, ready_at, created_at)` 升序、id tiebreak）。**为何不是「图拓扑序」**：每个 run 钉死**自己**的 `version_id`（冻结拓扑），跨版本的一批**没有**单一的图可供拓扑——硬解一个即对其余撒谎；而首次出现序在要紧处天然**就是**拓扑序（一个 run 的执行顺序即该 run 冻结图的一个拓扑序，限于跑过的节点），故行读作**最新 run 的拓扑**、只有更老 run 才有的节点（后改名/删除）追加在下方。行 = `nodeId` + `kind`（取该 node id **最新一次出现**的行——跨版本 kind 可漂移，最新 run 是当前真相；本端点是行轴 kind 的唯一诚实来源，跨版本的一批没有单一版本图覆盖得了）。
- `cells`：一个 (run, 节点) = 一格，**稀疏**——某 run 没跑到的节点**无格**（前端渲「未及」；正因稀疏才以格列表下发、非 rows×cols 稠密阵）。格 = `flowrunId` + `nodeId` + `status`（flowrun_nodes CHECK **4 值**）+ `iteration` + `iterations`。**多迭代聚合**（loop 的一个节点在一个 run 里有多行，而格阵每 (run,节点) 只有一格）：`status` = 各迭代中**最坏**处置（`failed` > `parked` > `cancelled` > `completed`）——**不是**「最后一轮」：第 3 轮失败的 loop **就是**在这次 run 里失败过的节点，后来的绿轮不能抹掉它。**档排的是「注意力」、不是「与 run 头一致」**：cancelled run **可以**带一条真 `failed` 行（`failNode` 先写了它、随后输掉头守卫给了取消），那个格在灰色的列上诚实地渲红；而被收割的审批（`cancelled`）压过 `completed`——宣称一个被切断的轮次「干净跑完了」是撒谎——却排在 `failed` 之下（它没失败，只是没人回答）。同档相持取**最新**迭代；`iteration` = 胜出行的迭代号（这格在展示哪一轮）；`iterations` = 该 (run,节点) 的行数（≥1，前端仅 >1 时渲「×N」，与 run 台账折叠同律）。格序 = 按 cols 序、每 run 内按行序。
- cells 不提供逐格 `elapsedMs`：`flowrun_nodes` 没有 `ended_at`；执行段真相由 `GET /flowruns/{id}/activity` 提供。

## trigger（`/api/v1/triggers`）

| Method · Path | 语义 |
|---|---|
| `POST /triggers` · `GET /triggers` · `GET /triggers/{id}` · `PATCH /triggers/{id}` · `DELETE /triggers/{id}` | CRUD。PATCH 热更正在监听的 listener；暂停项在 resume 时使用新 config。读模型含 `paused`、`refCount`、`listening`、`lastFiredAt`；暂停时 `listening=false` 且省略 `nextFireAt`。cron `misfirePolicy` 为 `skip\|catchup_one`，缺席为 skip，create/edit 校验 |
| `POST /triggers/{id}:fire` | 手动催一次（扇给当前监听者），202 返 `{data:{id}}`——新产物 activation 的单 id（triggerId 在 URL、fired 被 202 蕴含）；拿 id 直查 activation 闭环。**已暂停 422 `TRIGGER_PAUSED`**——暂停 = 一个新 firing 都不许，agent 绕不过用户的暂停 |
| `POST /triggers/{id}:pause` · `POST /triggers/{id}:resume` | 持久调度开关。pause 在源头注销 listener，保留引用集且不影响在途 run/pending firing；resume 在仍有 active workflow 引用时按当前 config 重注册。两者幂等，返动作后 trigger；真转移发 ephemeral status `{paused}` |
| `POST /triggers/{id}:iterate` | 开 AI 编辑对话 |
| `GET /triggers/{id}/activations` · `GET /trigger-activations/{id}` | 活动审计（触没触发都有记录） |
| `GET /firings` · `GET /triggers/{id}/firings` | 同一 firing 分页读模型：workspace 级端点可选 `triggerId`，逐 trigger 端点由路径提供它。AND 过滤 `status=pending\|claimed\|started\|skipped\|superseded\|shed\|missed` 与 RFC3339 `createdAfter/Before` 半开窗；非法枚举/时间大声拒绝。`missed.createdAt` 是原调度刻度且 `flowrunId` 为空。Firing 是无界日志，使用 cursor/limit |
| `GET /trigger-schedule` | 前瞻 cron 投影：`within` 为正 Go duration（默认 `168h`、上限 `30d`），`limit` 默认 200、上限 1000；返 `{points:[{at,triggerId,triggerName,workflowIds}],truncated}`。全局排序后截断，只包含正在监听且未暂停的 cron；无游标，非法/非正参数返回 `TRIGGER_SCHEDULE_INVALID_QUERY` |

## control / approval（`/api/v1/controls` · `/api/v1/approvals`）

两域同构：CRUD + `POST {id}:edit / :revert / :iterate` + `GET {id}/versions[/{version}]`。approval 的运行时决策端点在 flowrun 侧（见上）。

## skill（`/api/v1/skills`，name 即 id，目录即真相）

CRUD（`GET {name}` 附 `provenance`〔installed〕与 `dir`〔目录绝对路径，List 皆省〕；`POST` 严格冲突、**新建 name 须符 Agent Skills 规范形态**〔小写字母数字 + 单连字符，允数字开头〕→ 否则 400 `SKILL_INVALID_NAME` / `PUT {name}` 结构化覆盖〔底层保真读-改-写：typed 视图之外的 frontmatter 键与键序不丢；守卫正则从宽，存量下划线名照常可编〕/ `DELETE {name}` 删整目录含捆绑文件）+ `POST /skills/{name}:activate`（inline 渲染注入 / fork 派 subagent）+ **files 子资源（文件即真相面，`{path...}` 尾随通配路由）**：

- `GET /skills/{name}/files`：全文件元数据列表 `[{path,size,updatedAt}]`（**含 SKILL.md**，slash 相对路径、按路径升序；有界不分页，N4 豁免①）。
- `GET /skills/{name}/files/{path...}`：单文件**裸字节**（Content-Type 按扩展名推断〔内置 md/py/sh 等补充表〕，缺省 octet-stream；读护栏统一 1MB——超限清单也可读，用户才能修坏件）。
- `PUT /skills/{name}/files/{path...}`：裸字节体写入 → 204（父目录按需建）；**path=SKILL.md 时为带校验的清单整替**（≤32KB + 围栏可解析 + frontmatter 带 name 时必须==目录名；description 刻意不必填——导入件可缺省；成功后 equip 边重同步）。附属文件护栏 1MB。
- `DELETE /skills/{name}/files/{path...}`：204；**清单拒删**（400 `SKILL_FILE_PATH_INVALID`——删 skill 走 `DELETE /skills/{name}`）。

路径守卫三重：`filepath.IsLocal` 词法早拒（`..`/绝对路径/反斜杠 → 400 `SKILL_FILE_PATH_INVALID`）→ Clean 复核 → 一切 I/O 经 `os.Root` 句柄（symlink 逃逸 / TOCTOU 内核级阻断）。

**安装面（B4，同步阻塞——前端 spinner，202 进度记 backlog）**：

- `POST /skills:inspect-source`：`{source}`（GitHub 简写 `owner/repo[@ref][#subdir]` / github.com URL / 任意 http(s) tarball URL）→ `{data:[{name,description,allowedTools,fileCount,totalBytes,installable,reason?,alreadyExists}]}`——预览不落盘，**allowed-tools 前置亮相**（信任门从挑选步开始）。
- `POST /skills:install`：`{source, names?, force?}` → `{data:{installed:[], skipped:{name:reason}}}`。names 空 = 全部可装；同名已存在非 force 跳过。落盘 = 清单经校验原文路径 + 附属文件经守卫写 + **provenance sidecar**（`.anselm-install.json`：来源/装机时间/文件 sha256 基线/`toolsApproved=false` 起步）+ equip 边同步；`source=installed` 由 sidecar **推导**（frontmatter 零改写，`git pull` 不冲突）。
- `POST /skills/{name}:update`：`{force?}`——按 provenance 来源重拉；本地改动（对安装基线 hash 漂移）非 force → 409 `SKILL_LOCALLY_MODIFIED`（details 列漂移文件）；**allowed-tools 变更重置信任门**（未变则授权延续）。
- `POST /skills/{name}:approve-tools`：打开信任门（`toolsApproved=true`）。非安装来源 → 422 `SKILL_NOT_INSTALLED`。

**信任门语义**：`source=installed` 且未授权时，`:activate` 照常注入正文、active skill 照常记名，但 **allowed-tools 预授权不装**——危险调用照走逐次确认。

## mcp（`/api/v1/mcp-servers` · `/api/v1/mcp-registry`）

servers（name 即键，workspace 唯一）：`GET /mcp-servers`（实时状态列表）· `PUT /mcp-servers/{name}`（手动装/同名替换：stdio `{command, args, env, runtime?, timeoutSec?}`（runtime 缺省按 command 推断：npx→node、uvx→python…）或 remote `{url, transport?, headers}`；**连接失败仍落盘 `status=failed`+`lastError`**，reconnect 可救）· `GET /mcp-servers/{name}`（状态+tools 缓存）· `DELETE /mcp-servers/{name}`（204）· `POST /mcp-servers/{name}:reconnect`（重置按钮）· `GET /mcp-servers/{name}/stderr`（stdio stderr ring 尾，返 `{name, stderr, size}`）· `POST /mcp-servers/{name}/tools/{tool}:invoke`（`{args}` 直接试调、绕过 chat/LLM，返**裸结果**——与 L17 同步执行铁律一致、不裹 `{result}`）· `POST /mcp-servers:import?overwrite=`（Claude Desktop mcp.json 片段，返 `{imported, skipped}`）。
调用台账：`GET /mcp-servers/{name}/calls`（`?tool&status&triggeredBy&conversationId&flowrunId`；返 `{data:{calls, aggregates:{okCount,failedCount}}, nextCursor, hasMore}`——分页坐标顶层、聚合在 data 子对象，与 handler/function/agent 执行日志同形）+ `GET /mcp-calls/{id}`（含 `logs`——progress 通知 + 失败附 server stderr 尾；列表端点不带）。
市场：`GET /mcp-registry`（curated 全列）· `POST /mcp-registry:plan`
（`{name}` → `{transport,runtime?,oauth,envVars,prerequisite?}`；只投影安装计划，
零副作用；未知条目 404、无可运行 package 422）·
`POST /mcp-registry:install`（`{name,env}`；完整 slug 放 body；缺必填 env 或
无可运行 package 分别返回稳定错误）。

## document（`/api/v1/documents`）

CRUD + `POST {id}:move`（防环；nil parent=根）+ `POST {id}:duplicate`（深拷整子树，可选 body `{parentId}`：nil/缺省=落为源的兄弟；新根名自动去重；201 返新根裸实体）+ `POST {id}:iterate`（开 AI 编辑对话）+ `GET /documents?parentId=`（直接子节点；空=根级）+ `GET /documents/tree`（整树 metadata，无 content 正文，侧栏一趟拿全；每行带 `hasContent` bool＝正文非空［≡ `sizeBytes>0`，显式浮出让侧栏免拉正文即可选空页/已写页 icon］）。全文检索走统一 `/search` 与 `search_documents` 工具，无独立 HTTP 端点。

## conversation / chat（`/api/v1/conversations`）

| Method · Path | 语义 |
|---|---|
| conversation CRUD | `POST` · `GET`(list：`?search&archived&sort&workDir&pinned`) · `GET/{id}` · `PATCH/{id}`（含 ModelOverride 三态 + **`workDir`**）· `DELETE/{id}`。**`?workDir`（驻地过滤，WD1.5）** = 三态、按**键是否出现**读：缺席 = 完全不按驻地过滤（每条对话，WD1.5 之前的默认）\| **出现且为空**（`?workDir=`）= **仅未挂**的线程（rail「最近」段——不住在任何目录里的那些）\| 有值 = 仅该驻地（一个 rail 组，自行 keyset 翻页；值须逐字等于行上存的绝对路径，即 `GET /workdir-groups` 回的那个）。前两者用裸 `Get()` 分不清，故必须读 presence——否则「最近」段会静默列出整个 workspace。**`?pinned`（置顶过滤，WD1.5）** = 缺席(两者皆返,默认) \| `true`·`1`(仅置顶——rail「置顶」段,跨驻地) \| `false`·`0`(仅未置顶——驻地组与「最近」两段)。它存在只为一件事：分组后的 rail 里每条线程必须**恰好出现一次**，而「所有置顶线程」在其余各轴都按驻地过滤之后**再也**不能靠「置顶都落首页」的假定复原（住在**收起**的组里的置顶线程根本不会被取回来）。**`?sort`** = `activity`(默认，置顶优先再 `last_message_at` 降序——最近聊过) \| `created`(置顶优先再创建序) \| `name`(置顶优先再 `title` A–Z，大小写不敏感 `COLLATE NOCASE`)；切换 sort 须重置分页（游标随排序列走、跨 sort 无意义）。**`?archived`** = 缺省/其余(仅活跃,默认) \| `true`·`1`·`archived`(仅归档) \| `all`(活跃+归档同列,归档行带 `archived=true`——rail「显示已归档」灰点)。List/Get 每条带 `lastMessageAt` + **`isGenerating`** / **`awaitingInput`** / **`hasUnread`**（前两个派生只读：chat 是否有在途回合 / 是否有待决人在环 interaction[等你批准·回答]；`hasUnread` 是**持久**只读：有完成的 assistant 回复未看[绿点]——用户发送 / `:seen` / 创建时清，assistant 完成终态时置；供冷启动活动圆点·「等你」点·「答完未读」点；均不入 PATCH）。**`workDir`（驻地，WD1）** = 对话可选的工作目录，**朴素字符串、非三态**（该列的空值已表示「未挂」，故 `""` **就是**清除；缺键=不动，与其余 PATCH 字段一致）：写时经 `fspath.Expand` **归一化**（展开 `~`、`Clean`），故存下并回显的恒是真绝对路径；非绝对（展开后仍相对）→ **422 `CONVERSATION_INVALID_WORK_DIR`**；**刻意不校验存在性**（目录日后被移走/删掉是合法可渲染状态，见 `GET /{id}/workdir` 的 `exists`）。挂上后后端做三件事：相对路径以它为根解析（`Read/Write/Edit/LS/Glob/Grep`）· `Bash` 的 `cmd.Dir` 设为它 · 每轮 system prompt 带一段 `work_dir`（见 [domains/chat.md](domains/chat.md) §3.6）。**它不是沙箱**——往外**读**分毫不受影响（用户裁定：「想看外面什么的，都可以」），只有往外**写**（`Write`/`Edit` 目标 canonical 路径在子树外）会**无视 LLM 自报 danger、强制走既有人闸**（见 [foundation/loop.md](foundation/loop.md) 人闸两触发）。线程中途切换会给对话追加一条 `marker` 块（`GET /{id}/messages` 读回，**不加新 SSE 帧型**，见 [database.md](database.md) `message_blocks`）；`:fork` **复制**本列（分叉继承驻地） |
| `POST /{id}/messages` | **Send**：落 user 回合 + 开 assistant 回合 + 入队，返 assistant msg id |
| `GET /{id}/messages` | 回合历史 keyset 分页（含 blocks，最新在前）。同路由三种读形态、**互斥**（同给 → `400 INVALID_REQUEST`）：①`?cursor&limit` 向旧翻页（默认）②**`?around=<messageId>&limit`** 深跳开窗——以目标为中心（limit 摊前后两半、目标额外恒返回、钳 ≥2），返**窗 envelope** `{data, targetId, olderCursor?, newerCursor?, hasOlder, hasNewer}`（坐标顶层绝不进 data；olderCursor 喂回 `?cursor=`、newerCursor 喂 `?cursor=&dir=newer`——续翻不自铸协议）；目标不存在/不属本对话 → `404 MESSAGE_NOT_FOUND`（身份锚点）③**`?dir=newer&cursor`** 沿时间**向前**续翻（必须带 cursor、否则 400；`dir` ∈ 缺省/`older`/`newer`，其余 400）。所有形态 data 恒 newest-first——单一排序规则 |
| `GET /{id}/anchors` | **场次条导航锚点** keyset 分页（`?cursor&limit`，最新在前）：行 = `{kind, messageId?, blockId?, title?, count?, at}`，kind ∈ `user`(回合首行节选 ≤120 rune) \| `tools`(锚点间连续非危险工具**折叠簇**，count 计数、钉簇首块；人类内容是硬边界) \| `danger`(危险工具调用，title=工具名·entityName) \| `compaction`(压缩标记) \| `abnormal`(status error/cancelled 回合，title=stopReason/errorCode) \| `gate`(待决人闸——broker 活状态无日志行，**只骑首页顶、不占 limit、keyset 之外**，blockId=toolCallId)。未知对话 → `404 CONVERSATION_NOT_FOUND` |
| `GET /{id}/workdir` | **驻地投影（WD1→WD3）**：返 `{path, exists, isGitRepo, branch?, dirty, branches?[], worktrees?[]}`——已挂路径 + **此刻**关于它为真的东西。**逐请求现算、零缓存**：文件系统与 git **就是**真相，故用户刚删掉的目录、或刚在自己终端里切的分支，读作它**现在的样子**（缓存进对话行的生命周期会让菜单撒谎）。`path` 回显该列使客户端一次读服务整个菜单；`exists` 为 false 而 `path` 非空 = **警示态**（挂过、然后被移走或删了，UI 真要渲的一格，非错误）；路径上是普通**文件**同样 `exists=false`（`exists` 意为「可作工作目录用」）；`branch`/`dirty` 仅在 `isGitRepo` 时有意义（`branch` 空则省略，detached HEAD 归一为 `"HEAD"`），经**一次** `git status --porcelain=v2 --branch` 得出、2s 超时、无 `git` 二进制或非仓库皆答 `isGitRepo=false`（**缺席从不是错误**）。**`branches[]`（WD2）** = 仓库的**本地**分支、最近提交在前（`for-each-ref --sort=-committerdate refs/heads`）——菜单提议切过去的那些；**`refs/remotes` 刻意排除**，而正是这个排除让它保持有界无游标（`refs/heads` 是这个人自己建的那一集［人类尺度］，会跑到上千条的是 fetch 来的远端）。**`worktrees[]`（WD3）** = `[{path, branch?, current}]`，本仓库的每一份 checkout、**含主树并标出 `current`**（「有哪些 worktree」的诚实答案包含你正站着的那一份；`current` 是拿工作树的**根**比的，故挂在**子目录**上的驻地依然知道自己站在哪一份里）。两者**仅在 `isGitRepo` 时出现**（对普通目录它们会是两个必然空手而归的进程），故客户端分得清「这里没有 git」与「一个没有分支的仓库」［后者不可能存在］。付费阶梯：未挂/已消失 = 一次 `os.Stat`；普通目录 = 再加一次 `git status`；**只有真仓库**才付那个可操作菜单所需的四次读。**未挂**对话返 **200 + 零投影**（`path=""`、`exists=false`）、**不是** 404——「这条线程没有驻地」是对该问题的一个**成功**回答，且驻地按钮也得渲染那一态；只有对话本身不存在才 404 `CONVERSATION_NOT_FOUND`。**N4 豁免——有界投影之「零参数单对象」形**：一个按需现算的对象，无游标、无 `nextCursor`、**不收任何参数**（故无从钳制、无从 422、从不上报截断），与 `GET /storage-stat` 同形、与 trigger-schedule **不**同形 |
| `POST /{id}/workdir:switch-branch` · `POST /{id}/workdir:create-branch` | **驻地的分支两动作（WD2，N5 `:action`，骑在 `workdir` 子资源上）**。body `{branch}`；各返 **200 + 重探后的整个 `WorkDirInfo`**（一次切换同时改它好几个字段，让客户端再 GET 一次就等于让它画出一帧旧分支）。**为何挂在子资源上而不是 `{id}:switch-branch`**：Go ServeMux 每个模式只许**一个**处理器，而 `POST /api/v1/conversations/{idAction}` 已被 chat 的 `:cancel`/`:seen`/`:fork`/`:retry` 派发器占了，故对话级 `:action` 会被迫从**别人**的文件里 switch；挂子资源后各是自己的字面段、自己的路由（与 `POST /{id}/sandbox-envs:reset-all` 同形），且读得更真——它们作用于**驻地**。<br>**`:switch-branch` 的护栏（本批唯一真正的决定）**：**工作区脏 → 拒 422 `CONVERSATION_WORK_DIR_DIRTY`**，message 自带下一步（先提交或贮藏，再切分支）。**绝不 `--force`、绝不静默 stash、也不「让 git 自己判」**——git 自己的行为是能带过去就带、冲突才拒，于是那个**令人意外**的结局（活现在待在一条你以为不是的分支上）成了**静默的成功**路径；对一个 agent 正在其中干活的驻地，那比一个错误更糟。拒绝是唯一一个连一行都丢不了的选项。脏态在**服务端此刻现读**、不信客户端上次看到的投影（菜单打开之后用户可能刚在自己编辑器里改了文件）。目标必须是**已存在的本地分支**（先 `rev-parse --verify` 问一次 → 404 `CONVERSATION_BRANCH_NOT_FOUND`；这一问同时封掉 `git checkout` 的 DWIM，故一个拼错永不会悄悄变成一条远端跟踪分支）。<br>**`:create-branch` 刻意不受脏区门**（`checkout -b`，从当前 HEAD 起）：新分支起点就是已 checkout 的那个 commit，故工作树一个字节都不变、冲突不可能存在——未提交的活只是变成了新分支上的未提交的活，而那是最常见的开分支流程（「先动手，然后意识到这该有自己的分支」）；给它上门等于守一道什么都不守的护栏。名字已存在 → 409 `CONVERSATION_BRANCH_EXISTS`（新建与切换是两种意图，静默执行后者正是用户落到别人的活上面的方式）。<br>**分支名校验交给 git**：`check-ref-format refs/heads/<n>`（原则 #8，不手搓），另拒空与前导 `-`（以 `-` 开头的 ref 对 git **合法**却会被下一条命令读成选项）→ 422 `CONVERSATION_INVALID_BRANCH`。**所有 git 调用传参数数组、绝不拼 shell 字符串**。驻地不是仓库（含未挂/已消失/无 `git` 二进制）→ 422 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`；git 拒的其余一切 → 422 `CONVERSATION_GIT_FAILED`，**git 逐字 stderr 在 `details.git`**。**本批不做也永不做** commit / push / pull / merge / rebase / reset |
| `POST /{id}/workdir:add-worktree` | **「为此对话开一个 worktree」一条龙（WD3，N5 `:action`）**。body **`{name}`——是名字、绝不是路径**；返 200 + **新**目录的 `WorkDirInfo`。一次请求做完四件事：建目录 → 建（或**复用**）分支 → **该对话的驻地自动切过去** → 线程上落一条 WD1 已有的 **`marker`** 块（复用、不新增块型；走的正是文件夹按钮那条 PATCH 路径，故 `conversation.work_dir` 回声也白得——E1/E2 不加流不加帧型）。<br>**路径与分支约定与 `make worktree` 逐字对齐**：`make worktree NAME=<x>` → `../Anselm-<x>` 分支 `wt/<x>`，即**主**工作树根的**兄弟**位置、名为 `<根的 basename>-<name>`、分支 `wt/<name>`（Makefile 里写死 `../Anselm-` 是因为 Anselm **就是**它那个根的名字）。从**主**树派生、不是当前那棵——否则约定会嵌套（在 `Anselm-a` 里开一份会得到 `Anselm-a-b`、再一份 `Anselm-a-b-c`），而纪律是主仓库旁边**一排平的**兄弟、一个并发会话一个。<br>**收名字而不收路径就是那条安全性质**：目标由约定**派生**，故只可能落在仓库旁边；名字须是**单个路径段**（拒 `..`／`/`／`\`／绝对写法／前导 `-`）且 `wt/<name>` 过 `check-ref-format` → 否则 422 `CONVERSATION_INVALID_WORKTREE_NAME`（比分支名**更严**，因为这个名字**也会**成为一个目录段）。<br>**两种撞车各有答案**：**目录**已存在 → 409 `CONVERSATION_WORKTREE_EXISTS`，**`details.path` 带挡路的那个目录**（它装着某人的活、可能是另一个会话的，静默接管正是两个 agent 编辑同一棵树的方式——而那正是 worktree 纪律所要防的事故）；**分支**已存在 → **复用**，与 Makefile 完全一致（`make worktree-rm` **刻意**保留分支，故在它之上重开一份 worktree 正是被写进文档的回头路）。若那条分支已在**别处**被 checkout，只有 git 知道 → 422 `CONVERSATION_GIT_FAILED`，而 git 自己那句话**点出**占着它的目录，那正是下一步。**建成之后驻地切换失败**（对话不存在等）会留下一份完好的worktree 与仍在原处的线程——那是可以停在的诚实半状态：什么都没被毁，用户手动挂上即可 |
| `GET /conversations/workdir-groups` | **驻地分组投影（WD1.5）**：返 `[{workDir, activeCount, archivedCount, lastMessageAt}]`——每个住着**未置顶**线程的非空 `work_dir` 一行，**按组内最近活跃降序**（`MAX(last_message_at) DESC`，`work_dir ASC` 作 tiebreaker 使顺序全序）。**它是本批后端存在的唯一理由**：rail 无限翻页，若在一窗内做客户端分组，组成员与计数会随滚动**漂移**——组头会报出一个在 workspace 什么都没变时自己会变的数。故分组对整个 workspace **一次 GROUP BY** 算出（走新索引 `idx_conversations_ws_workdir`）。**被计数的集合是「未置顶」**：置顶线程被提到 rail 自己的置顶段、必须恰好出现一次，故在此计入它会让组头的数与它下面的行**不一致**；`:archive-workdir`/`:delete-workdir` 遵守**同一条**规则，正是这一点让**一个**数既作组头、又作确认框盘点。**已软删的行不算**；**未挂线程不构成组**（`work_dir = ''` 不出现在结果里——它们没有文件夹头、没有 ⋯ 菜单）；一个驻地的未置顶线程全部离开（归档不算、退出驻地/删除算）后组**自行消失**——**组是投影、不是实体**：无表、无 id、无生命周期、**不做空组管理**。`activeCount`/`archivedCount` **分列**（一趟 `COUNT … FILTER` 扫出）使 rail 的「显示已归档」开关自行取其一或求和、批量动作盘点二者之和，**而端点保持零参数**；`lastMessageAt` **跨两种归档态**，故切换视图绝不重排组序。**N4 豁免——有界投影之「零参数」形**：无游标、无 `nextCursor`、**不收任何参数**（分页参数按标准 HTTP 忽略，非 422），有界性来自「一个人会挂多少个目录」而非有多少条对话 |
| `POST /conversations:archive-workdir` · `POST /conversations:delete-workdir` | **驻地组批量动作（WD1.5，集合级 N5 `:action`，与 `POST /notifications:mark-all-read` 同族）**。body `{workDir}`；各返 `{workDir, archived}` / `{workDir, deleted}` = **真正改变**了几条对话。**为何是端点而非前端循环 N 次 PATCH**：循环可能半途被打断（把用户要收起的一个文件夹留在既非收起也非未收起的状态），且循环的第 N 次失败没有任何诚实的话可报；这里是**一个事务里的一条语句**，恰好只有两种结局（id 集在**同一**事务内读出并与写入行数**交叉核对**，故一次静默的半个动作会变成一次回滚的错误）。**两者共同的范围**：该驻地下的**未置顶**对话（置顶存活——置顶是用户在说「这条我在意」，一次目录级清扫不该把它带走；其范围与组头计数逐字相同，故确认框的盘点诚实）。**`:archive-workdir`** 只动 `archived = 0` 的行，故计数说的是**改变了什么**、重跑答 0 且不发回声。**`:delete-workdir`** **跨归档态**（破坏性动作不该静默取决于哪个视图开关开着），**它到底删了什么**：那些 `conversations` 行上的 `deleted_at` 戳 + 每条线程的 relation 边与触点台账（与单条 `DELETE` 完全相同的级联，事务提交后逐行 best-effort）；**它没有删什么**：**任何消息行**（`messages`/`message_blocks` 是 D1 Log 表——无 `deleted_at`、绝不物理删，逐字记录逐字节留在盘上），以及**文件系统上的任何东西**（驻地是行上的一个字符串，此处只当分组键读；它点出的那个目录**绝不被碰**——正因如此 UI 的用词是「删除全部对话」而**绝不是**「删除目录」）。逐行发**既有**的 `conversation.archived` / `conversation.deleted` 回声（E1/E2：不加流、不加帧型；rail 的对账方式正是重读信号点出的那一行，一条聚合帧点不出任何行）。**两种点不出组的拼法被拒**：**空** `workDir` → `400 INVALID_REQUEST`（`work_dir = ''` 是正当的列表**过滤**、但**不是一个组**；接受它会让一个请求归档/删除本 workspace 里每一条从未选过目录的线程，那是没有任何界面提供、也从未被任何确认框盘点过的动作）· 非绝对路径 → `422 CONVERSATION_INVALID_WORK_DIR`（WD1 已立的法：相对的根扎不住任何东西）。**不引入新错误码** |
| `POST /{id}:cancel` · `POST /{id}:seen` | **Cancel** 在途生成 / **Seen** 清 `hasUnread`（用户打开线程，幂等 204；与 `:cancel` 共 `{idAction}` 派发器）；动作语法,非删子资源，均 204 |
| `POST /{id}:fork` | **Fork**：把线程分叉成一条**新对话**，承载直到 `atMessageId`（**含它**）的前缀，源对话**分毫不动**。body `{atMessageId?}`——**可选**，缺省/空 = 从**最新**消息处分叉（左岛 rail 的「分叉对话」手上没有 message id）；`atMessageId` 不属本对话 → `404 MESSAGE_NOT_FOUND`（身份锚点，同 `?around=`）；无消息的源 → 纯配置副本。与 `:cancel`/`:seen` 共 `{idAction}` 派发器。**复制**：对话头 `system_prompt` / `attached_documents` / `model_override` + 前缀窗内**全部**消息行（**含 subagent 行**——LLM 装配按 `subagent_id` 自然排除）+ 其 blocks（`seq` **从 1 重排**、`parent_block_id` **remap 进分叉自己的 block id**、`context_role` 重置为 hot）。**summary 两分支**：前缀**到达**水位（前缀内最大源 seq ≥ `summary_covers_up_to_seq`）→ summary 随行 + 水位**重定基**到分叉的 1..N 编号；前缀**止于水位之前** → summary 与水位**都不带**（水位 0）——摘要概括了超出前缀的内容，带走即撒谎。标题 = 「原标题 (fork)」（源无标题则分叉亦无标题、留给自动命名）、`auto_titled=false`、`archived`/`pinned` **不复制**（分叉以活跃未置顶起步）。**不复制**：touchpoint / relation（除下述血缘边）/ 通知 / flowrun / todos——那是**源**的历史；人闸 always-allow 白名单按对话 id 键、故分叉重新授权（同 Claude Code `--fork-session`）。**附件零拷贝**：内容寻址（`att_` 行 + sha256 blob，无 conversation_id），引用共享、GC 按 workspace 活跃 sha 保活。血缘落 `forked_from_conversation_id` / `forked_from_message_id` 两列 + 一条 relation `create` 边（源 → 分叉，按分叉**入向**侧 diff-sync）。**201** + 新 Conversation 全行（分叉是客户端要导航过去的资源、无异步回合可等，故非 202 `{id}`）；纯追加、零删除（D1）；不加新 SSE 流/帧型（E1/E2），rail 靠既有 `conversation.created` 长出新行 |
| `POST /{id}:retry` | **Retry**：把对话的**末回合**换成一个**新版本**，**只追加**。body `{content?, modelOverride?}`（两键皆可选，空 body 合法）；与 `:cancel`/`:seen`/`:fork` 共 `{idAction}` 派发器。**两分支**：无 `content` = **重生成**——supersede 末 assistant 回合、入**既有**对话串行队列重跑、**不写新 user 回合**（那个问题从未被重新问过）；有 `content` = **编辑重发**——supersede 末 user **与**其 assistant **两条**，落一条带编辑后文本的新 user 回合（**保留原附件引用**——附件内容寻址、零拷贝共享；**@ 提及快照刻意不带**：它是冻结**内容**而非引用，而编辑后的文本完全可能已删掉那个 `@`，注入它等于把消息已不再说的话喂给模型——body 无 `mentions` 键，故也不重新解析）+ 一条新 assistant 回合。`modelOverride`（`{apiKeyId, modelId}`，**朴素指针、非 PATCH 三态**——重试没有「清除」这一格可表达，缺席即「用这条线程现有的设置」）**只作用于本回合**、**不回写对话头**（换线程默认仍走 `PATCH`）；该版本行的 `provider`/`model_id` 溯源随即记下究竟哪个模型产出了它。**「替换」= 指针**：旧行写 `superseded_by` = 新行 id、新行 `attrs.retryOf` = 旧行 id，旧行**留在盘上并照常从三种读形态返回**（版本翻页据此逐版回看、`?around=` 仍可寻址）；**只有** `LoadThreadForLLM` 按 `superseded_by = ''` 过滤，故模型恰好看到该回合的**一个**版本。**门**：末回合须已终态，否则 **409 `STREAM_IN_PROGRESS`**（读两处，因为它们答两个不同问题：内存队列 `IsGenerating` 答「此刻是否有回合在跑/在排」+ 末行耐久状态答「线程自己的尾巴是否终态」［硬崩溃留下的 pending/streaming 行不是可叠着重试的东西］。**不引入新码**——一条非终态的尾巴**就是**一个［就耐久真相而言］仍在跑的回合）；无回合可重试 → **404 `MESSAGE_NOT_FOUND`**（身份锚点，同 `?around=`/`:fork`）；未知对话 → `CONVERSATION_NOT_FOUND`。归档线程自动解档（同 Send）。**202** + `{id}` = 新 assistant message id（与 Send 同形——同一种行为：一次经 messages SSE 流式的生成）；回合走**既有帧型**（新回合正常 message_start / delta / message_stop，`retryOf` 搭在 message 节点的 content 上、**start 与 stop 两处都带**［stop 的 close 快照是 replay 客户端唯一拿得到的东西，缺了它重连方会把被取代的版本渲成多出来的一轮］，使**不是发起方**的客户端也能把版本组起来），**不加新流、不加新帧型**（E1/E2）；纯追加、零删除（D1——为何合宪见 [database.md](database.md) 的 `messages.superseded_by`）|
| `GET /{id}/interactions` · `POST /{id}/interactions/{toolCallId}` | 待决人机交互重同步 / 决议（body `{action, answer?}`：action ∈ approve\|approve_always\|deny\|accept\|decline，枚举外 → `422 INTERACTION_INVALID_ACTION`（先于 broker 查找就拒，不静默当 deny）；answer 仅 ask accept 用），成功 204 |
| `GET /{id}/system-prompt-preview` · `GET /{id}/usage` | 调试预览 / token 用量 |
| `GET /{conversationId}/todos` | 对话工作清单 |
| `GET /{conversationId}/touchpoints` | **对话触点台账**（上下文台账，右岛数据源）：keyset 分页（`?cursor&limit`，`last_at DESC`）+ 可选 `?kind=`（relation 11 kind + `attachment`）/ `?verb=`（mentioned/created/edited/viewed/executed/attached/deleted）过滤（枚举校验，`TP_INVALID_KIND`/`TP_INVALID_VERB`）；行 = `{id,itemKind,itemId,itemName,verb,lastActor,count,firstAt,lastAt,lastMessageId}`。只读——写入仅后端水龙头（chat Send + loop 工具咽喉） |

## attachment / memory（`/api/v1/...`）

attachment：`POST /attachments`（上传）· `GET /{id}` · `GET /{id}/content` · `POST /{id}/playback-lease` · `GET /attachment-playback/{token}` · `DELETE /{id}`。上传与 metadata GET 返回附件行字段外，另带可选 `preparation`：`{status,phase?,target?,width?,height?,mimeType?,sizeBytes?,errorCode?,canCancel?,canRetry?,updatedAt?}`，其中 image 会认领/暴露 `model-default` 代理准备态（`pending|running|ready|failed|cancelled`），`phase` 是 UI 分组（queued/processing/ready/failed/cancelled/not_required/unavailable），非 image 为 `not_required`，状态侧车失败为 `unavailable` 且不影响附件元数据可用性。`playback-lease` 仅对 audio 附件签发短期 loopback URL（body 空，返 `{url,expiresAt}`），签发仍走 bearer + workspace；`attachment-playback/{token}` 是给原生播放器使用的 bearerless 短租约 fetch 路由，token 绑定 workspace/attachment、仅内存保存、过期 404，支持 Range/seek，非 audio 签发返回 `ATTACHMENT_PLAYBACK_UNSUPPORTED`。
memory：`GET /memories` · `GET/PUT/DELETE /memories/{name}` · `POST /{name}/pin|unpin`（name 即 id）。

## search（`/api/v1/search`，统一搜索）

| Method · Path | 语义 |
|---|---|
| `GET /search` | 综搜/垂搜同端点：`?q`(必填) `&types`(csv，空=综搜) `&tags`(csv) `&updatedAfter/Before`(RFC3339) `&includeArchived`(默认 true) `&cursor&limit`(默认 20 上限 50,走 ParsePageBounded;非数字/<1 → 400)。返 `{data:{hits, total}, nextCursor, hasMore}`——分页坐标顶层、total 在 data 子对象;hit 含 entityType/entityId/name/snippet(`<mark>`)/anchor/tags/archived/score/matchedChunks/refHint（仅积木六类） |
| `POST /search:reindex` | 就地 force-reconcile workspace 索引，204；词法行逐实体覆盖而非先清空，向量缓存失效后重嵌。同 workspace 单飞，重复调用 409 `SEARCH_REINDEX_RUNNING`；不同 workspace 不互阻 |
| `GET /search/settings` | 机器级搜索设置 + 引擎实时状态 `{embedder, ollamaBaseUrl, ollamaModel, engine:{status: ready\|downloading\|absent\|error\|off, model, lastError}}`（Ollama 字段恒回显生效值） |
| `PATCH /search/settings` | 修补设置：`{embedder?: builtin\|ollama\|off, ollamaBaseUrl?, ollamaModel?}`（缺省字段不动；Ollama 参数空串重置默认）；非法 embedder 400 `SEARCH_EMBEDDER_INVALID`；改 model 即旧模型向量按 model 列失效、后台重嵌 |

LLM 工具面（非 HTTP）：`search_blocks`（积木面板：六类可接线单元，返 ref 直填 workflow 节点）；8 个 `search_<entity>` 垂搜工具保 schema 换引擎（非空 query 走内容引擎、引擎错误回退原子串路径）。

## P6 支撑域

workspace：CRUD（守最后一个；PATCH 含 `webFetchMode`: local|jina）+ `GET {id}/stats`（删除确认的内容盘点,WRK-062 S-11——`{conversations,functions,handlers,agents,workflows,documents,runningFlowruns,generatingConversations,blobBytes}`;计数滤软删、flowruns 数 `status='running'`、generating=chat 内存在飞快照与本 ws 活行求交;`blobBytes` 500ms 预算内 walk 文件树、超时/未接线返 **-1**=诚实未知;路由在 workspaces 豁免前缀、path id 铸 ctx;未知 id 404）+ `PUT/DELETE {id}/default-models/{scenario}`（dialogue|utility|agent 三聊天场景 + image|speech|video 三生成场景(WRK-082 §3.2,生成**工具**的路由 key、与聊天解耦;**受管开通播种全部六个、含视频**——免费档六个全供〔H1:用户把视频放进免费档、10 条/天/install,推翻了原先「视频不进免费档」那条我自己的决定〕,故已不存在「播进去会显示一个永远路由不通的『已配置』」的槽)；DELETE 清该场景默认回未配；**写时校 apiKeyId 存在性**——引用不存在的 key 即 404 `API_KEY_NOT_FOUND`，非只 invoke 时失败，与「删被引用 key 挡 `API_KEY_IN_USE`」对称，F153；modelId 拼写不校、留 invoke 时 fail-loud）+ `PUT/DELETE {id}/default-search`（搜索 key）+ `POST {id}:activate`（刷 lastUsedAt）。apikey（路径字面 `/api-keys`：`GET/POST /api-keys` · `PATCH/DELETE /api-keys/{id}` · `POST /api-keys/{id}:test`）：CRUD（受管 provider 行 **PATCH 与 DELETE 均返 422 `API_KEY_IMMUTABLE`**——受管 install id 行由后端拥有，删除会割裂安装身份与配额历史，删除与编辑对称守卫，WRK-062 S-1）+ `:test`（probe）+ `GET /providers`（provider 目录——**8 条本地条目 + models.dev 目录里我们说得了方言的全部家**，逐项 `{name, displayName, defaultBaseUrl?, baseUrlRequired, baseUrlHint?, managed, category, curated, dialect, credential, models}`。`managed`=内置免费档 `anselm`;`curated`=本 app 手写过 spec〔约 160 家为 false:靠机械 `npm` → 方言映射抵达、我们没试过,UI 据此把「你的 key 不对」与「这家我们没试过」分开〕;`dialect`=要说的那条线缆〔**说不了的方言整家不下发**——摆出来等于邀请一次我们早就知道的失败〕;`credential`=`api_key` | `service_account_json`〔Vertex 收的是服务账号 JSON **文件**〕;`baseUrlHint`=**模板形状**、刻意不预填〔`https://{resource}.openai.azure.com` 之类,地址里有一样只有这个用户知道的东西〕;`models`=目录为这家收录的模型数,**本地条目为 0 意为「没有目录清单」而非「零个模型」**,故 UI 不渲那一行。**`mock` 仅 `ANSELM_DEV=1` 时下发**——T6 测试设施不进产品下拉，但建 key 白名单恒接受它，S-5）。freetier：`GET /freetier/quota`（免费档本月配额代理——后端解出受管 anselm key 的公开 install id、由设备 proof transport 签名调用网关 `GET /v1/quota`，返 `{limit,used,remaining,resetAt,available}`；客户端无法直读——Ed25519 私钥加密留在 Go sidecar、永不出本机；无受管行 404 `FREETIER_NOT_PROVISIONED`，网关自身失败原样冒泡 `LLM_AUTH_FAILED`/`LLM_RATE_LIMITED`/`LLM_PROVIDER_ERROR`）+ `POST /freetier:provision`（手动重开通,S-7——幂等:无行则建;**已有行则探测,仅当网关答 `INVALID_INSTALL` 时自愈**——重新登记设备并**就地**换受管行的 install id(行 id 不变,scenario 默认无需重接;瞬时失败[离线/限流/网关重启]绝不轮换);返 `{provisioned:bool}`,true=事后存在受管行,false=开通降级(离线/网关挂/无指纹,状态非错误);boot/OnCreated 钩子仍是主路径,此为用户侧重试与**修复**口。设置页免费档卡的空态「启用」与错态「修复」两个按钮都打它）。speech：`GET /speech/asr`（本机 WebSocket sidecar，浏览器/桌面只发 16k PCM binary + `{type:commit|finish|cancel}` 控制帧；sidecar 用 device proof 代理 managed Anselm 网关 `/v1/speech/asr`，不拿用户 BYOK 做语音适配；client/gateway 两条 WebSocket leg 都由 sidecar 发送 ping，收到 message/pong 后滚动 30s 读 deadline，单会话仍受 2min 绝对上限；无 managed 行或网关不可用 → `SPEECH_UNAVAILABLE`）。**read-aloud**(朗读,WRK-082 批C/P10——与 asr **反方向**,故不共用路径段):`GET /read-aloud/availability`(返 `{available}`——没有 key 能说话就不给按钮,诚实缺席同工具注入闸)+ `POST /read-aloud:read`(body `{text,voice?}`,`text` 非空 ≤4000 rune;**`voice` 可以是一个克隆音色的名字**——与合成走同一条路由,故名字在此被解析成网关句柄、再由网关按 install 解析成供应商 id(两跳,H9);未匹配上的名字**原样透传**(预置音色不是我们表里的行);返 `{attachmentId,filename,mimeType,sizeBytes,cached}`——交回**附件**而非字节,故播放复用既有 `playback-lease` 一等路径;`cached=true` 表示本次按下**零上游花费**。**不经 LLM、零 token**;缓存键=(文本+音色+provider+model),命中在**合成之前**就判定,故重听根本不走 provider;码 `READALOUD_TEXT_REQUIRED`/`READALOUD_TEXT_TOO_LONG`/`SPEECH_NO_ROUTE`/`SPEECH_GEN_FAILED`)。model：`GET /model-capabilities` · `GET /scenarios`。sandbox：`GET/POST /sandbox/runtimes` + `GET /sandbox/runtimes/available`（用户可装语言运行时 + 默认/钉死版本，UI 据此渲染、免硬编 pin map；引擎产物 llamasrv/embedmodel 与 docker 不列）+ `DELETE /sandbox/runtimes/{id}` · `GET /sandbox/envs[/{id}]` + `DELETE /sandbox/envs/{id}` · `GET /sandbox/disk-usage` · `GET /sandbox/bootstrap-status` · `POST /sandbox:gc` · `POST /sandbox:retry-bootstrap`；对话级 scratch env：`GET /conversations/{id}/sandbox-envs` · `POST .../sandbox-envs/{kind}:reset` · `POST .../sandbox-envs:reset-all`。relation：list / `GET /relations/neighborhood` / `GET /relgraph`。catalog：`GET /catalog`。tools：`GET /tools`（**可授权工具目录**——每项 `{name, summary}`（summary=工具 Description 首行、截断 200 符），全部内置工具按 name 排序；skill `allowed-tools` 选择器的**内置候选源**（实体 id fn_/hd_ 从实体 list 挑、MCP 工具从 `GET /mcp-servers` 挑，皆不在此静态集）；**有界系统固定集**——无 `nextCursor`、分页参数忽略（N4 豁免①）；**不含 danger/execution_group**——那是 LLM 逐次自报（S18）、非静态工具属性，目录只答「有哪些工具可预授权」）。limits（**机器级全局单设置**——落 `<dataDir>/settings.json`、与 workspace 无关；统一 auth 门要求 workspace header 仅作身份、对 limits 值无隔离作用，任一 workspace 改的都是这台机器的同一份上限。本地单用户语义下「全局」即正确，非 per-workspace bug）：`GET /limits`（活动运行上限）+ `GET /limits/schema`（逐字段 default/min/max/unit/desc 元数据，UI 据此渲染范围、免复刻 Go 常量）+ `PATCH /limits`（部分 JSON 合并、校验后持久化 `<dataDir>/settings.json` 并热换——消费方下次读取即生效；越界 400 `SETTINGS_LIMITS_INVALID`）+ `POST /limits:reset`（无 body，恢复 `Default()`、持久化并热换——默认由服务端持有，客户端不硬编）。network（机器级同 limits——`<dataDir>/settings.json` 的 `network` 段）：`GET /network` + `PATCH /network`（**整体替换**、非合并;`{httpProxy?,httpsProxy?,noProxy?}` 出站代理;boot 与 PATCH 时应用到进程环境[Go `http.ProxyFromEnvironment` 读之],完整生效须重启 sidecar[既有 HTTP 客户端缓存代理];空=直连;WRK-062 工单⑩）。retention（**机器级**同 limits/network——落 `<dataDir>/settings.json` 的 `retention` 段，无 workspace 维度；scheduler 工单⑬、判决④）：`GET /retention`（返 `{runRetentionDays}`，恒具体值——全新安装读回服务端自持的默认 **90**、绝不 null，故客户端不硬编）+ `PATCH /retention`（**部分合并**、非替换；body `{runRetentionDays?}`——缺省字段不动，故 `{}` 是忠实 no-op 而非意外的「永久」；落盘并**踢一趟清理**［收紧的线立刻回收 run，而非等 ticker 的 6h］。**`0` = 永久保留**［清理绝不跑，碰都不碰 DB］，且往返存活——段在文件里用指针形，「段缺席」与显式 0 可区分；**唯一校验是物理的**：负天数 400 `SETTINGS_RETENTION_INVALID`，UI 的 30/90/180/永久 值集是**产品**可供性、后端不强制［60 照收，拒它是校验剧场，设计原则 #6］；未知字段严格拒 400）。**清理语义**：按**终态 run 的 `completed_at`** 往回数［与 flowrun-stats 的 `completedSince` 同窗口语义——跑了很久刚失败的 run 是**新鲜**的］，只删终态（completed/failed/cancelled）、**running/parked 永不删**（不管多老）；boot 起、每 6h、及每次 PATCH 各跑一趟，逐 workspace 分批物理删。**无 `:sweep` 端点**（裁量：清理是后台卫生、非用户动作；PATCH 已给出「改配置即见效」的即时通路，另开端点是多余 API 面）。**无 `/retention/schema`**（单字段、值集是前端产品决策，无范围可渲）。**D1 归档线例外立法见 [database.md](database.md) flowrun 节**。notification：list / `POST /notifications/{id}:mark-read` / `POST /notifications:mark-all-read` / `POST /notifications:mark-all-unread`（mark-all-read 的镜像：清全部 read_at → 全变未读，204、不发帧、幂等；未读徽标靠 unread-count 重取对账，N0）/ `GET /notifications/unread-count`。**两个 mark-all 端点带可选 body** `{after?,before?}`（RFC3339）——`created_at` 上的半开窗 `[after, before)`，托盘用它把某时间组的「全部已读/未读」限在该组行（清「今天」不动「更早」的积压）；缺省字段=该界不设，故**无 body 调用标整本账（向后兼容）**；非 RFC3339 界 422 `NOTIFICATION_INVALID_WINDOW`、绝不静默标一切。aispawn：`POST /<entity>/{id}:iterate` 分布于各实体 + `POST /executions/{id}:triage`（按 execId 前缀 function/handler/agent/flowrun 分发）。

**模型默认的 native options 合同**：所有 `PUT {id}/default-models/{scenario}` 的非空 `options` 必须精确匹配该已探测 `apiKeyId`/`modelId` 在 `GET /model-capabilities` 公开的 native knob 与值；未知字段返回 422 `MODEL_OPTION_UNSUPPORTED`，非法值返回 400 `MODEL_OPTION_VALUE_INVALID`。因此 adapter 不会静默丢弃一个用户已保存的设置。空 `options` 不要求模型目录命中，仍保留自定义/未探测模型的 fail-loud-at-invoke 路径。

## 系统 / 可观测性

`GET /api/v1/health`（liveness，N1 envelope，免 workspace；**但不免 bearer**——见下 loopback 加固）· `GET /api/v1/version`（返 `{version}`——构建期 `-ldflags "-X main.version=$(VERSION)"` 盖章,裸 go run 为 `"dev"`;免 workspace 同 /health、bearer 照过,onboarding 前可读,关于页消费）· `GET /api/v1/system/data-dir`（返 `{dataDir}`——解析后的数据目录 = 本地优先存储位置，供桌面端「显示 / 在文件管理器打开」；guarded，与 `/limits` 同走 workspace 门——同为**机器级**端点，header 仅作身份、非隔离轴）。 · `GET /api/v1/network` + `PATCH /api/v1/network`（出站代理配置,工单⑩——机器级同 limits;PATCH 整体替换 `{httpProxy?,httpsProxy?,noProxy?}` 并应用代理 env,重启 sidecar 完整生效）。 · `GET /api/v1/storage-stat`（T4/WRK-070 + WRK-082 H5.9——返 `{dbBytes,deadBytes,attachmentBytes,attachmentDeadBytes}`：**两个存储并排**。前两项是 SQLite 库文件的逻辑大小 + 其中 DELETE 腾出却未还给 OS 的死空间[`page_count·freelist_count × page_size`，先 `wal_checkpoint(TRUNCATE)` 才读 freelist 否则 WAL 中的删除不计入]；存储面板据此诚实显示「X MB,其中 Y MB 可回收」。后两项是**附件字节**——blob 是 `workspaces/<ws>/blobs` 下按内容寻址的**文件**、**根本不在 .db 里**,故只报 dbBytes 在视频出现之前就已经少报了一半以上（实测:轻度使用的开发机 blobs 6.8MB vs 库 4.9MB;一段 3MB 的片子只让 dbBytes 动几百字节元数据）;`attachmentDeadBytes` 是已软删、孤儿 blob GC 仍可回收的那一半,与 `deadBytes` 对位,使面板对两个存储读法一致。**附件求和刻意跨全部 workspace**——`dbBytes` 本就是（一个 .db 装所有 workspace 的行）,在「整个安装的数据库」旁边报「本 workspace 的附件」会把两种口径塞进同一个面板；此处用不带 workspace 谓词的原始查询是诚实形状,换任何别处都是 bug。表缺席时**报错而非返 0**——静默的 0 恰好会藏住这个数字存在的理由所指的那种故障。**机器级**同 data-dir/limits，header 仅身份；**N4 豁免**：单一系统资源、单对象、无游标=有界资源[非集合、非已存投影]，分页参数按标准 HTTP 忽略）。 · **voices**(WRK-082 H9——克隆音色的**管理面**;登记**不在这里**,它是 `enroll_voice` 工具调用,因为要源附件与 LLM 对「用哪段」的判断):`GET /api/v1/voices` 返 `{items:[{id,name,provider,upstreamId,sourceAttachmentId,createdAt}], capacity, remaining}`——**`capacity`/`remaining` 随响应走**,因为**上限正是用户来这里的理由**:一个列出两行却不说「就这些了」的列表,会让下一次登记的失败无从解释;空库存序列化成 `[]` 而非 `null`(让客户端先判 null 才数得了数,那个分支是我们逼它写的)。**N4 豁免①**:有界可枚举资源(上限**就是**那个界)、返全集无游标。· `DELETE /api/v1/voices/{id}` **先删上游登记、再删行**——行是唯一持有 `upstream_id` 的东西,先删行会让一个已付费的登记在别人服务器上**永远不可见**地活着,同时继续占着用户正想腾出的那个库存位;**上游失败即中止**(行留着、可重试、库存计数继续说真话),绝不以一条 warn 日志糊过去。204;未知 id → 404 `VOICE_NOT_FOUND`) · `ANSELM_MASTER_KEY`（静态加密主密钥种子，WRK-062 拍板 #14——设则优先于机器指纹派生（`bootstrap.Config.Fingerprint` 既有缝），桌面端经 OS 钥匙串铸存注入；⚠️ 换种子=既有密文（api_keys/mcp config）全部解不开，key 须重录）· `ANSELM_PARENT_WATCH`（WRK-070 T2 侧车死人开关，`cmd/server` 薄壳级：设则 goroutine 读 stdin 至 EOF 即视父进程已死，汇入与 SIGINT/SIGTERM **同一个** `signal.NotifyContext` 取消 → 同一有序关停（SSE 流 → HTTP 排空 → 后台 → DB，子进程 kill-set 一并收割）；桌面端 spawn 恒设 `1` 且终生握子进程 stdin——父亲以**任何**形态退出（⌘Q/SIGTERM/SIGKILL/崩溃）管道必 EOF；macOS 无 `Pdeathsig` 故此为可移植做法。dev `make -C backend run`/testend 不设 = 连 goroutine 都不起、零行为变化）· **`ANSELM_GATEWAY_URL`**（受管免费档网关 origin,空=生产 `https://api.anselm.website/v1`。**建 workspace 会触发异步免费档开通**,故任何会建 workspace 的进程都会在此处解析出的那个网关上登记**真** install——写死常量时那永远是生产:一次完整 `make -C backend testend` 约 50 个 install,且只要某个场景的生成路由回落到受管家就**真花掉配额**;受管行还是**异步**落地的、而兜底顺序偏好 `anselm`,于是相隔一秒的两个相同请求会解析到**不同的供应商**。testend harness 因此把它指向一个**关闭的**回环端口,让开通快速失败、workspace 里只剩场景自己建的 key。dev 亦可用它挂 staging 网关）。
