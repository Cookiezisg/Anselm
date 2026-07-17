---
id: DOC-008
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# HTTP API —— 端点登记

> 全部端点的单一事实源（method · path · 语义一行）。
> 通则（N 系列）：统一 Envelope `{"data":...}` / `{"error":{code,message,details}}`；线缆 camelCase；**无界集合** List `?cursor&limit` 分页，**有界可枚举资源**（workspaces / skills / memories / documents 树 / sandbox runtimes·envs / todos / model-capabilities）与**有界批查**（flowrun-stats，workflowIds ≤50 封顶 · flowrun-matrix，flowrunIds ≤50 封顶——两者均去重后计数、越界 422 大声拒）豁免——返全集不分页、无 `nextCursor`、分页参数按标准 HTTP 忽略；**有界投影**（trigger-schedule）另立一类——它**不是已存集合**、而是按窗现算的派生时间线，故同样无 `nextCursor`，但 `within`/`limit` 是**真参数**：超上限**钳制**、不可解析或非正 → **422**（不是忽略），响应经 `truncated` 诚实报告窗内还有更多；窗头恒为 now、无游标，故超出 `limit` 的点本次请求不可达（抬 `limit` ≤1000 即可，1000 之外无从翻页——前瞻预览、非可翻集合）；非 CRUD 动作 `:action`；执行动词 `:run`(fn) `:call`(hd) `:invoke`(ag) `:trigger`(wf)；`:iterate` = 开 AI 编辑对话（全实体共享 aispawn）。
> **响应形状铁律**：`data` 内层一律**裸实体**——`POST`(Create) / `GET` 单读 / `PATCH` 同形,前端一套解构到底;**绝不**裹 `{"<entity>": ..., "version": ...}` 外层 key。版本实体(function/handler/agent/workflow/control/approval)的当前版本经实体内嵌 `activeVersion` 字段透出(Create 即附新版本,与 GET 单读完全同形)。复合读(一次返多个并列实体,如 `GET /flowruns/{id}` → `{flowrun, nodes, nextCursor}`,nodes 为 N4 keyset 一页)才用具名多 key。
> **异步动作返 id 铁律**：返回新建资源 id 的异步动作(`POST /{id}:trigger`→flowrun、chat `POST /{id}/messages`→message、`:iterate`/`:triage`→conversation、`:fire`→activation)一律 `202 {data:{"id": <newId>}}`——前端一条规则取新资源 id。**同步执行**(`:run`/`:invoke`/`:call`,阻塞返完整结果)不在此列、返**裸结果**(不裹 `{result}`/`{output}`)。
> **状态变更动作铁律**：改实体状态的动作(`:stage`/`:kill`/`:activate`/`:deactivate`/`:restart`/`:edit`/`:revert`)一律返**动作后实体完整快照**(`{data:<entity>}`),不发 `{staged:true}`/`{killed:N}` 等临时裸键(附加计数等并入实体字段或由相关列表端点查)。**无新产物的变更**(resolve-interaction、search `:reindex`、DELETE)一律 `204 No Content`,绝不返 `{data:null}`。

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
| `POST /workflows` · `GET /workflows` · `GET /workflows/{id}` · `PATCH /workflows/{id}` · `DELETE /workflows/{id}` | CRUD（PATCH=meta 不升版本；列表 `?search`：`name` 大小写不敏感子串过滤）（含 `concurrency`: serial\|skip\|buffer_one\|replace\|allow_all——overlap 政策，下一次 drain 生效） |
| `POST /workflows/{id}:trigger` | 立即跑一次（任何 lifecycle 下可跑），body `{payload?}`（只读 payload），返 flowrun id |
| `POST /workflows/{id}:stage` | 待命恰一次真实触发后自动撤防（已 active → 409） |
| `POST /workflows/{id}:activate` / `:deactivate` | 上线（挂监听+active）/ 优雅下线（摘监听+inactive 或 draining） |
| `POST /workflows/{id}:kill` | 硬停：摘监听 + 取消全部在途 run + inactive，返动作后 workflow 实体快照（状态变更动作铁律，非裸计数） |
| `POST /workflows/{id}:edit` / `:revert` | 图 ops 构建新版本 / 移 active 指针 |
| `POST /workflows/{id}:capability-check` | ref 解析体检（实体在吗/kind 对吗/port·method 在吗）；返 `problems`（阻断）+ `warnings`（建议——含 F156 未声明输出读：读 `producer.field` 而 producer 声明输出不含 field） |
| `POST /workflows/{id}:iterate` | 开 AI 编辑对话 |
| `GET /workflows/{id}/versions[/{version}]` | 版本 |

## flowrun（`/api/v1/flowruns`）

| Method · Path | 语义 |
|---|---|
| `GET /flowruns` | 运行历史分页，过滤全 AND 组合（scheduler 工单⑥＋⑮）：`?workflowId&triggerId`（等值）`&status=running\|completed\|failed\|cancelled&origin=manual\|chat\|cron\|webhook\|fsnotify\|sensor`（封闭集——status 越集 422 `FLOWRUN_INVALID_STATUS`、origin 越集 422 `FLOWRUN_LIST_INVALID_FILTER`，details 均带 `allowed`）`&startedAfter&startedBefore`（started_at 半开窗）`&completedAfter&completedBefore`（**工单⑮**：completed_at 上的另一个**半开窗** `[after, before)`——问「run 在此段**落定**」而非「开始」；未落定的 run（running/parked）`completed_at` 为 NULL、`NULL >= ?` 永不为真故任一界都**剔除**它，刻意如此）。两组时间界均 RFC3339、归一 UTC；非 RFC3339 一律 422 `FLOWRUN_LIST_INVALID_FILTER`，details 带 `param`/`got`。**`completedAfter` 是 Overview「24h 失败」牌的深链谓词**——牌数的 `flowrun-stats.totals.failedSince` 按 `completed_at` 开窗，故只有本窗（非 `startedAfter`）建得出「牌数着的**正是**这些 run」的列表；两者谓词**逐字节相同**（`completed_at >= ?` 裸比较），牌上的数 == 列表长度。origin 为 NULL 的旧行不匹配任何 origin 过滤；`startedAfter` 窗走既有 `idx_fr_ws_created`/`idx_fr_ws_workflow`，`?status&completedAfter` 深链走新增 `idx_fr_ws_status_completed`（工单⑮，见 database.md）|
| `POST /flowruns` | 手动起 run（= workflow `:trigger` 的等价入口），body `{workflowId, entryNode?, payload?}`（`entryNode` 消歧多 trigger 图——唯一接受 entryNode 的端点） |
| `GET /flowruns/{id}` | run 头 + **一页节点行**（N4 分页 `?cursor&limit`、最新在前、返 `nextCursor`；长 loop run 数千行不再一次倾倒，F168-M7。完整记忆化全集是解释器内部的、非线缆的） |
| `GET /flowruns/{id}/activity` | **按 run 聚合活动时长**（scheduler 工单⑤，喂 S4 甘特+台账）：四张执行日志表（`function_executions`/`handler_calls`/`agent_executions`/`mcp_calls`）按 flowrun_id UNION 的纯读投影，行 `{nodeId, iteration, kind, execId, status, startedAt, endedAt, elapsedMs, readyAt?}`——`kind`∈function\|handler\|agent\|mcp（审计表族、非图节点 kind：action 按 ref 前缀散入三族；control/approval 内联求值无审计行）、`execId`=审计行 id（fne_/hcl_/agx_/mcl_）、`status`=审计词表（ok\|failed\|cancelled\|timeout）、执行段=审计行自己的 startedAt/endedAt/elapsedMs、`readyAt?`=排队起点（工单⑫，join 自 `flowrun_nodes` 真相行的 `ready_at`，键 (flowrun_id,node_id,iteration)=idx_frn_once；⑫ 前旧行/无对应真相行**键缺席**）。**行序 startedAt 升序**（甘特天然序，id tiebreak——四表 id 前缀各异全局唯一）+ N4 keyset `?cursor&limit`；每支 UNION 走既有 `idx_*_ws_flowrun` 偏索引、零 schema 变更。run 不存在 404 `FLOWRUN_NOT_FOUND`（投影分不清「还没活动」与「无此 run」，先 GetRun 守卫）。at-least-once/:replay 下旧审计尝试行仍在（Log 不删）、可早于存活真相行的 readyAt——呈现端把排队段钳制 ≥0 |
| `POST /flowruns/{id}:replay` | 修复失败 run：清 failed 行 + 重走（completed 复用）；**仅 failed 可重放**——cancelled 是终局终态、不可 :replay（422 `FLOWRUN_NOT_REPLAYABLE`） |
| `POST /flowruns/{id}:cancel` | **取消单个 running run**（scheduler 工单②）：先守卫标头 running→cancelled（first-wins——与自然终态的竞态由 DB 守卫裁决，输家 422）再 cancel 该 run 在飞 ctx（打断卡在 LLM 流式/工具里的节点；**被打断节点不落行、不误写 failed**）+ 收回 parked 审批（收件箱不留死项）+ 发 durable `run_terminal`；取消 draining workflow 最后在途 run 触发 draining→inactive 结算。202 返 `{flowrun, nodes 首页, nextCursor}`（与 :replay 同信封形）；非 running 422 `FLOWRUN_NOT_CANCELLABLE`。cancelled 不点 attention、不发通知（手动终止非故障） |
| `GET /flowrun-inbox` | 审批收件箱（= 全部 parked 节点行），**每行带 workflow 上下文 enrich**（scheduler 工单④）：`workflowId` + `workflowName`（join 自 run 头；workflow 已软删名**回落裸 id**——relation Namer 先例）+ `deadline?`（绝对期限 = parkedAt + 钉死 approval 版本的 timeout，与 `CheckTimeouts` 扫描同一解析语义〔domain `DeadlineFrom` 单源〕；表无 timeout / 解析不出**键缺席**、绝不发零值；approval 版本 resolve 失败仅该行缺 deadline，行本身保持可见可决策）。有界批读（run 头一条 `GetRunsByIDs` + workflow 名一条 `NamesByIDs`、approval 版本按 (ref,钉死版本) 记忆化），绝不逐行 N+1；enrich 住 app `ListInbox` |
| `GET /flowrun-stats` | **运营统计批查**（scheduler 工单③＋⑭，只读投影、零新表零新列）：`?workflowIds=<csv>&recentN&since` → `{totals, byWorkflow}`（详见下段）。**Overview 统计单源**——五张 KPI 牌全读它，含 `totals.missed`（工单⑭，数 `trigger_firings`、经 FiringInbox 端口缝入） |
| `GET /flowrun-matrix` | **节点×run 状态格阵批查**（scheduler 工单⑩，纯读投影、零新表零新列）：`?flowrunIds=<csv，去重后 ≤50>` → `{cols, rows, cells}`（详见下段） |
| `POST /flowruns/{id}/approvals/{node}:decide` | 人工审批决策 `{decision: yes|no, reason?}`（first-wins，输家 422） |

flowrun 行 DTO 带创建时溯源两字段（camelCase、omitempty）：`origin`（manual|chat|cron|webhook|fsnotify|sensor——HTTP 手动=manual、对话 trigger_workflow=chat、firing 按 trigger kind 逐字盖）+ `conversationId`（仅 origin=chat：发起 run 的 cv_）。两列诞生前的旧行为 NULL、**线缆不发键**——客户端按缺席渲 unknown，不认空串。

flowrun **节点行** DTO 带排队戳两字段（scheduler 工单⑫，camelCase、omitempty）：`readyAt`（该 (节点,轮次) 在某轮 walk 首次被算出 ready 的时刻=排队起点）+ `startedAt`（引擎开始处理该节点的时刻——input CEL 求值+派发；执行实体自身的起点在其审计行）。排队段 = readyAt→startedAt。两列可空：⑫ 前旧行与 seed trigger 行（从不排队）为 NULL、**线缆不发键**。replay/恢复下的落戳立法见 [database.md](database.md) flowrun 节。

**`GET /flowrun-stats` 契约**（喂 scheduler 海洋 rail/Overview 的一次有界批查；有界故 **N4 分页豁免**——`workflowIds` 去重后 ≤50 封顶、超限 422 `FLOWRUN_STATS_TOO_MANY_IDS`（details 带 `allowed`），绝不静默截断）：
- 参数：`workflowIds`=csv（去重保序；缺席/空 → `byWorkflow: []` 只回 totals）；`recentN` 珠串窗（默认 10、钳到 20；非数字或 <1 → 400 `INVALID_REQUEST`，同 page limit 语义）；`since` 统一窗口（RFC3339 绝对起点 或 正回看时长 `24h`/`7d`，默认 7d；解析不了 422 `FLOWRUN_STATS_INVALID_SINCE`）。
- `totals`（**全 workspace**，刻意不限请求 ids）：`running`（在跑 run 数）+ `completedSince`/`failedSince`（窗口内**落定**的终态数——按 `completed_at` 开窗，跑很久刚失败的算新鲜失败；谓词是**裸** `completed_at >= ?`，与 `GET /flowruns?completedAfter=` **逐字节相同**故 `failedSince` 与它点开的失败列表是**同一个事实**，工单⑮）+ `parkedNodes`（**等人处理的 run 数**：仍 running 且持 ≥1 parked 节点的 DISTINCT run——一个 run park 多个审批只计 1，遗留在已终态 run 上的 parked 行不可决策不计；键名按工单定形、语义是 run 数）+ **`missed`**（工单⑭：窗口内 `created_at` 落入的 `missed` firing 数——app 睡着时到期、被记账且**绝不补跑**的 cron 刻度，判决⑥）。
  - **`missed` 是唯一不数 flowrun 的 total**——它数的是**本该存在却不存在**的 run，故本端点是 **Overview 的统计单源**、而非「仅 flowrun 两表的投影」：Overview 问的是**一个**问题（「我的自动化在这个窗口里过得怎么样」），一个从未成为 run 的刻度正是答案的一部分。数据源是 `trigger_firings`（跨域），由 app 层经 scheduler 既有的 **FiringInbox 端口**缝入（domain 只拥有形状、不伸手够 store）。
  - 三条诚实性：①**与 `completedSince`/`failedSince` 同一个 `since`**——`since` 在 app 服务里只默认一次，故第五张牌**物理上**不可能与另外四张漂移；**绝不做 all-time**（只增的「有史以来错过多少」是虚荣数字，规范禁）。②按 `created_at` 开窗，而 missed 行的 `created_at` **就是那个调度刻度**（工单⑨ 回拨盖戳）——故整夜停机摊在**那一夜**、而非全堆在睡醒那一秒。③与 `GET /firings` **同一组谓词**计数，故牌与它点击深链过去的列表不可能互相矛盾。
  - 无 firing 存储的部署（纯手动）读 0——那时根本不存在 firing，0 是**真相**；而计数**失败**不静默吞成 0（「你什么都没错过」与「我查不出来」是两句话），整个批查报错。
- `byWorkflow`：**每个请求 id 恒一行、按请求顺序**——无 run 的 id（从未跑/不存在/宿主已软删）回**零值行**、绝不缺席（纯 flowruns 投影、不校验 workflow 存在性；孤儿 run 一等公民）。行 = `workflowId` + `running` + `parkedNodes`（该 workflow 等人处理的 run 数——语义与 totals 桶逐字一致、按 workflow 分桶；rail 琥珀点的数据源）+ `lastRunAt?`（从未跑缺席）+ `recent`（最近 recentN 个 run 状态、新→旧、**含 running** 的诚实珠串）+ `successRate?`（窗口内 completed/(completed+failed)，0..1；cancelled 中性不参与；窗口无终态 run 键缺席——「无数据」≠「0%」）+ `avgElapsedMs?`（窗口内 **completed 且 `replayCount=0`** 的 run 的平均 `completedAt−startedAt`；无此类 run 键缺席）+ `consecutiveFailures`（按 run 序列 `(started_at, id)` 新→旧的连续 failed 数：**running 与 cancelled 均跳过**［前者未定局——连败徽章不因新 run 起跑/park 闪灭；后者中性——见下方 cancelled 立法］、**只有 completed 停**［自愈=证明跑通］；不受 recentN/since 约束）。

> **`cancelled` 在本端点的唯一立法**（三个字段逐字同款）：cancelled 是**中性处置**——「未执行」桶，既非错误亦非功劳。被手动停掉 / 被 replace 顶替的 run 对 workflow 健康**什么都没说**，故**两边都不算**：永不算失败，也永不算健康的证据；运行上与 running 同待遇（**透明**）。反例即代价：算失败 → 用户主动按的 ⏹ 读成故障；算健康 → 一次 ⏹ 就把正在进行的 3 连败整个从失败榜（前端按 `consecutiveFailures > 0` 过滤）抹掉，且用 `replace` 策略的 workflow（每个被顶替的 run 都**自动**取消）连败**永久钉在 ~1**、零用户动作。
>
> **`avgElapsedMs` 的两条排除、一个理由**：耗时要答「这要跑多久」，而头上的 `completedAt−startedAt` 只在「一次跑完」时才答得上。failed 的耗时是「多久才死」；**被 replay 的** run 其头跨着**人类的修复窗口**——`:replay` 重开同一个头且**绝不移动 `startedAt`**（它是所有 run 列表 / 矩阵列 / 连败游走的排序键，移它即改写历史），故一个 30 秒的 run 三天后 replay 成功会报**三天**（比 failed 的扭曲大好几个数量级，一边滤 failed 一边放它进来是自相矛盾）。无干净样本时**键缺席**——诚实缺席胜过编造数字，与 `successRate` 同立场。**已知且刻意**：**审批等待计入**（审批 workflow 的墙钟本就是人的时间；扣掉 parked 段须 join 工单⑤ activity，超出本有界批查射程）——本字段是**墙钟 触发→完成**。对比 `flowrun-matrix` 的 `cols[].elapsedMs`：那是**一个 run 的真实跨度**（事实，故含 replay 间隔与审批等待），而本字段是**统计**（宣称代表「这要跑多久」，故剔除不可知样本）——两者立场不同、刻意不同源。

**`GET /flowrun-matrix` 契约**（喂 scheduler 运营主页页顶格阵 `AnRunMatrix`；**有界批查 → N4 分页豁免**——一次按**显式 run id 集**答完格阵，哪些 run 在屏上是客户端的事［它按时间窗文法翻 `GET /flowruns`、逐页拿 id 批取格阵，故本端点自身**不带任何窗口/近期参数**］；**两条**查询：请求的 run 头一条 orm `WhereIn`（重排回正典序）+ 这批 run 的全部节点行一条 `flowrun_id IN (…)`（走 `idx_frn_run`），**绝不逐 run 拉详情**；零 schema 变更）：

- 参数：`flowrunIds`=csv（**必填**——它**就是**格阵的内容：按请求序去重、空串跳过，去重后空集 400 `INVALID_REQUEST`（无 run 即无格阵，绝不铸一个无意义的空答案）、去重后 >50 → 422 `FLOWRUN_MATRIX_TOO_MANY_IDS`（details 带 `allowed`/`got`）——**逐字**沿用 flowrun-stats 的 ids 纪律：静默截断请求 id **会**撒谎，客户端拿屏上那页与答案对拉、会把短答案读成完整。**不校验 run 存在性**：未知/异 workspace 的 id **静默缺席**（cols 自带 `flowrunId` 键、缺席可发现——不同于 stats 的 1:1 零值行对拉；全未知返三个空列表）——孤儿 run 一等公民）。
- `cols`：一个 run = 一列，**新→旧**（正典 `started_at DESC, id DESC`——与所有 run 列表同序、**与请求里的 id 顺序无关**［客户端打乱的顺序不许左右行轴：rows 的首次出现扫描走的正是这些列］，故一列与它在大表里的行是同位的同一个 run）。列 = `flowrunId` + `startedAt` + `status`（flowrun 头 4 值）+ `elapsedMs?`（**run** 的墙钟时长 `completed_at−started_at`，喂列顶时长微条；仍在跑的 run 无 completed_at → **键缺席**，绝不发会被读成「瞬时」的 0）。**已知且刻意**：这是**墙钟**，含审批等待与 `:replay` 间隔（`:replay` 重开同一个头、不移 `startedAt`，故三天后重放成功的 run 其列真的跨三天）——一列是**一个 run 的真实跨度**，那是**事实**；与 `flowrun-stats` 的 `avgElapsedMs`（**统计**，宣称代表「这要跑多久」故剔除 replay 过的样本）**刻意不同源、立场不同**。前端若要可比的时长微条，读工单⑤ `/activity` 的执行段。
- `rows`：一个节点 = 一行。行集 = 这批 run 里出现过的 `nodeId` **并集**，序 = **首次出现序**（扫列新→旧、每个 run 内按该节点自身执行序 `COALESCE(started_at, ready_at, created_at)` 升序、id tiebreak）。**为何不是「图拓扑序」**：每个 run 钉死**自己**的 `version_id`（冻结拓扑），跨版本的一批**没有**单一的图可供拓扑——硬解一个即对其余撒谎；而首次出现序在要紧处天然**就是**拓扑序（一个 run 的执行顺序即该 run 冻结图的一个拓扑序，限于跑过的节点），故行读作**最新 run 的拓扑**、只有更老 run 才有的节点（后改名/删除）追加在下方。行 = `nodeId` + `kind`（取该 node id **最新一次出现**的行——跨版本 kind 可漂移，最新 run 是当前真相；本端点是行轴 kind 的唯一诚实来源，跨版本的一批没有单一版本图覆盖得了）。
- `cells`：一个 (run, 节点) = 一格，**稀疏**——某 run 没跑到的节点**无格**（前端渲「未及」；正因稀疏才以格列表下发、非 rows×cols 稠密阵）。格 = `flowrunId` + `nodeId` + `status`（flowrun_nodes CHECK **4 值**）+ `iteration` + `iterations`。**多迭代聚合**（loop 的一个节点在一个 run 里有多行，而格阵每 (run,节点) 只有一格）：`status` = 各迭代中**最坏**处置（`failed` > `parked` > `cancelled` > `completed`）——**不是**「最后一轮」：第 3 轮失败的 loop **就是**在这次 run 里失败过的节点，后来的绿轮不能抹掉它。**档排的是「注意力」、不是「与 run 头一致」**：cancelled run **可以**带一条真 `failed` 行（`failNode` 先写了它、随后输掉头守卫给了取消），那个格在灰色的列上诚实地渲红；而被收割的审批（`cancelled`）压过 `completed`——宣称一个被切断的轮次「干净跑完了」是撒谎——却排在 `failed` 之下（它没失败，只是没人回答）。同档相持取**最新**迭代；`iteration` = 胜出行的迭代号（这格在展示哪一轮）；`iterations` = 该 (run,节点) 的行数（≥1，前端仅 >1 时渲「×N」，与 run 台账折叠同律）。格序 = 按 cols 序、每 run 内按行序。
- **刻意无逐格 `elapsedMs`**：`flowrun_nodes` 无 `ended_at`，此处派生的任何单节点时长都是编的；执行段的真相在审计行——`GET /flowruns/{id}/activity`（工单⑤），而格阵视觉只需列顶的 run 时长。

## trigger（`/api/v1/triggers`）

| Method · Path | 语义 |
|---|---|
| `POST /triggers` · `GET /triggers` · `GET /triggers/{id}` · `PATCH /triggers/{id}` · `DELETE /triggers/{id}` | CRUD（PATCH=Edit，热更监听中的 listener；**已暂停的不热更**——新 config 在 :resume 时生效）。List/Get 每条带持久 **`paused`**（恒在 bool，scheduler 工单⑦）+ 派生 `refCount`/`listening` + **`lastFiredAt`**（最近一次 fire 的时间，nil=从未；行可显示「N 前 fire」，读时从 activation 日志投影）；暂停时 `listening=false`、`nextFireAt` **缺席**（无排程、给时间戳即撒谎）。cron 的 `config.misfirePolicy`（`skip`\|`catchup_one`，缺席=skip，scheduler 工单⑨）在 create/edit 走封闭词表校验，越集 422 `TRIGGER_INVALID_MISFIRE_POLICY`（写错的词绝不静默按 skip 走） |
| `POST /triggers/{id}:fire` | 手动催一次（扇给当前监听者），202 返 `{data:{id}}`——新产物 activation 的单 id（triggerId 在 URL、fired 被 202 蕴含）；拿 id 直查 activation 闭环。**已暂停 422 `TRIGGER_PAUSED`**——暂停 = 一个新 firing 都不许，agent 绕不过用户的暂停 |
| `POST /triggers/{id}:pause` · `POST /triggers/{id}:resume` | **运行时调度开关**（scheduler 工单⑦，止血阀）：pause 持久化 `paused=true` 并**在源头注销** source listener（cron 摘 entry / webhook 路径 404 / fs watch 停 / sensor 探测停），引用集保留、在途 run 与已 pending firing 不受影响；resume 持久化翻回并（仍有 active workflow 引用时）用**当前** config 重注册。两者**幂等**（重复无害 no-op）、同步 200 返动作后**裸 trigger**（与 PATCH 同形）；暂停跨重启持久（boot 重挂跳过 Register）。每次真转移发 entities 流 ephemeral `status` 信号 `{paused}` |
| `POST /triggers/{id}:iterate` | 开 AI 编辑对话 |
| `GET /triggers/{id}/activations` · `GET /trigger-activations/{id}` | 活动审计（触没触发都有记录） |
| `GET /firings`（**workspace 级**，工单⑭）· `GET /triggers/{id}/firings`（逐 trigger） | **firing 收件箱分页**——「触发了为什么没跑」的处置面。**一个 handler、两个 URL**（路径 id 只是替 `?triggerId` 把 filter 填上；不是两套文法）：前者 workspace 级、`?triggerId` **缺席 = 跨所有 trigger**（firing 是 (trigger × workflow × activation) 的 workspace 级日志行，故「近 24h 的所有 firing」是一等问题——Overview 调度轨道即问它，逐 trigger 翻答不了它除非把每本账拖干）；后者 trigger 取自路径（entities 海洋 trigger 观测 tab 的现役消费者），`?triggerId` 在其上忽略。过滤全 AND 组合：`?triggerId`（等值）`&status=pending\|claimed\|started\|skipped\|superseded\|shed\|missed`（封闭集，越集 422 `TRIGGER_FIRING_INVALID_STATUS`、details 带 `allowed`）`&createdAfter&createdBefore`（RFC3339、归一 UTC，created_at 上的**半开窗** `[after, before)`——相邻窗无缝拼接不重叠；非 RFC3339 一律 422 `TRIGGER_FIRING_INVALID_FILTER`，details 带 `param`/`got`）。**`missed`**（工单⑨）= app 停机/睡眠期间到期、醒来记账而**不补跑**的 cron 刻度，行 `createdAt` = 错过的**调度刻度**（非睡醒时刻，故 24h 窗读到的正是那 24h 的刻度）、`flowrunId` 恒空。**N4 分页**（cursor+limit）——firing 是**无界** Log（每分钟 cron 一天写 1,440 条），**非**有界投影豁免。窗/status/trigger 三查询各走 `idx_trf_ws_created`/`idx_trf_ws_status`（计数为覆盖索引）/`idx_trf_ws_trigger`（工单⑭ 新增三索引；此前无任何索引带 `workspace_id`＝每次读全表扫）|
| `GET /trigger-schedule` | **前瞻调度时间线**（scheduler 工单⑧）：`?within=`（Go duration，默认 `168h`、上限 `30d`）内每个 cron 刻度，`?limit=`（默认 200、上限 1000）封顶，返 `{data:{points:[{at, triggerId, triggerName, workflowIds}], truncated}}`——`at` 升序（同刻按 triggerId 定序）、`workflowIds` 从**内存监听表**反查（= `refCount` 同源引用集，故点绝不承诺不会发生的运行）。**cap 跨 trigger 全局**：并集排序后才截断，故最早 N 个点是真正最早的 N 个；`truncated=true` 诚实报告窗内还有更多（**N4「有界投影」豁免**：派生时间线、非已存集合，故无游标；窗头恒 now，超出 `limit` 的点本次不可达——抬 `limit`〔≤1000〕即可，1000 之外无从翻页）。只有**正在监听且未暂停**的 cron 贡献点——暂停的、无 active workflow 引用的、以及 webhook/fsnotify/sensor（下次 fire 不可知）一律缺席。`within`/`limit` 不可解析或非正 → 422 `TRIGGER_SCHEDULE_INVALID_QUERY`（details 带 `param`/`got`） |

## control / approval（`/api/v1/controls` · `/api/v1/approvals`）

两域同构：CRUD + `POST {id}:edit / :revert / :iterate` + `GET {id}/versions[/{version}]`。approval 的运行时决策端点在 flowrun 侧（见上）。

## skill（`/api/v1/skills`，name 即 id）

CRUD（`POST` 严格冲突 / `PUT {name}` 覆盖 / `DELETE {name}`）+ `POST /skills/{name}:activate`（inline 渲染注入 / fork 派 subagent）。

## mcp（`/api/v1/mcp-servers` · `/api/v1/mcp-registry`）

servers（name 即键，workspace 唯一）：`GET /mcp-servers`（实时状态列表）· `PUT /mcp-servers/{name}`（手动装/同名替换：stdio `{command, args, env, runtime?, timeoutSec?}`（runtime 缺省按 command 推断：npx→node、uvx→python…）或 remote `{url, transport?, headers}`；**连接失败仍落盘 `status=failed`+`lastError`**，reconnect 可救）· `GET /mcp-servers/{name}`（状态+tools 缓存）· `DELETE /mcp-servers/{name}`（204）· `POST /mcp-servers/{name}:reconnect`（重置按钮）· `GET /mcp-servers/{name}/stderr`（stdio stderr ring 尾，返 `{name, stderr, size}`）· `POST /mcp-servers/{name}/tools/{tool}:invoke`（`{args}` 直接试调、绕过 chat/LLM，返**裸结果**——与 L17 同步执行铁律一致、不裹 `{result}`）· `POST /mcp-servers:import?overwrite=`（Claude Desktop mcp.json 片段，返 `{imported, skipped}`）。
调用台账：`GET /mcp-servers/{name}/calls`（`?tool&status&triggeredBy&conversationId&flowrunId`；返 `{data:{calls, aggregates:{okCount,failedCount}}, nextCursor, hasMore}`——分页坐标顶层、聚合在 data 子对象，与 handler/function/agent 执行日志同形）+ `GET /mcp-calls/{id}`（含 `logs`——progress 通知 + 失败附 server stderr 尾；列表端点不带）。
市场：`GET /mcp-registry`（curated 全列）· `POST /mcp-registry:plan`（`{name}` → `{transport, runtime?, oauth, envVars:[{name,description,isSecret,required?}], prerequisite?}`——安装表单的数据源:后端 `Plan()` 选包结果的线上投影,选包逻辑绝不复刻到客户端;不安装、零副作用;未知条目 404 `MCP_REGISTRY_NOT_FOUND`、无可跑 package 422 `MCP_NO_RUNNABLE_PACKAGE`;WRK-062 工单⑨）· `POST /mcp-registry:install`（`{name, env}`——完整 slug 在 body 因含 `/`，无 per-name 详情端点（列表即全量）；缺必填 env 422 `MCP_ENV_MISSING`、无可跑 package 422 `MCP_NO_RUNNABLE_PACKAGE`）。

## document（`/api/v1/documents`）

CRUD + `POST {id}:move`（防环；nil parent=根）+ `POST {id}:duplicate`（深拷整子树，可选 body `{parentId}`：nil/缺省=落为源的兄弟；新根名自动去重；201 返新根裸实体）+ `POST {id}:iterate`（开 AI 编辑对话）+ `GET /documents?parentId=`（直接子节点；空=根级）+ `GET /documents/tree`（整树 metadata，无 content，侧栏一趟拿全）。全文检索走统一 `/search` 与 `search_documents` 工具，无独立 HTTP 端点。

## conversation / chat（`/api/v1/conversations`）

| Method · Path | 语义 |
|---|---|
| conversation CRUD | `POST` · `GET`(list：`?search&archived&sort`) · `GET/{id}` · `PATCH/{id}`（含 ModelOverride 三态）· `DELETE/{id}`。**`?sort`** = `activity`(默认，置顶优先再 `last_message_at` 降序——最近聊过) \| `created`(置顶优先再创建序) \| `name`(置顶优先再 `title` A–Z，大小写不敏感 `COLLATE NOCASE`)；切换 sort 须重置分页（游标随排序列走、跨 sort 无意义）。**`?archived`** = 缺省/其余(仅活跃,默认) \| `true`·`1`·`archived`(仅归档) \| `all`(活跃+归档同列,归档行带 `archived=true`——rail「显示已归档」灰点)。List/Get 每条带 `lastMessageAt` + **`isGenerating`** / **`awaitingInput`** / **`hasUnread`**（前两个派生只读：chat 是否有在途回合 / 是否有待决人在环 interaction[等你批准·回答]；`hasUnread` 是**持久**只读：有完成的 assistant 回复未看[绿点]——用户发送 / `:seen` / 创建时清，assistant 完成终态时置；供冷启动活动圆点·「等你」点·「答完未读」点；均不入 PATCH） |
| `POST /{id}/messages` | **Send**：落 user 回合 + 开 assistant 回合 + 入队，返 assistant msg id |
| `GET /{id}/messages` | 回合历史 keyset 分页（含 blocks，最新在前）。同路由三种读形态、**互斥**（同给 → `400 INVALID_REQUEST`）：①`?cursor&limit` 向旧翻页（默认）②**`?around=<messageId>&limit`** 深跳开窗——以目标为中心（limit 摊前后两半、目标额外恒返回、钳 ≥2），返**窗 envelope** `{data, targetId, olderCursor?, newerCursor?, hasOlder, hasNewer}`（坐标顶层绝不进 data；olderCursor 喂回 `?cursor=`、newerCursor 喂 `?cursor=&dir=newer`——续翻不自铸协议）；目标不存在/不属本对话 → `404 MESSAGE_NOT_FOUND`（身份锚点）③**`?dir=newer&cursor`** 沿时间**向前**续翻（必须带 cursor、否则 400；`dir` ∈ 缺省/`older`/`newer`，其余 400）。所有形态 data 恒 newest-first——单一排序规则 |
| `GET /{id}/anchors` | **场次条导航锚点** keyset 分页（`?cursor&limit`，最新在前）：行 = `{kind, messageId?, blockId?, title?, count?, at}`，kind ∈ `user`(回合首行节选 ≤120 rune) \| `tools`(锚点间连续非危险工具**折叠簇**，count 计数、钉簇首块；人类内容是硬边界) \| `danger`(危险工具调用，title=工具名·entityName) \| `compaction`(压缩标记) \| `abnormal`(status error/cancelled 回合，title=stopReason/errorCode) \| `gate`(待决人闸——broker 活状态无日志行，**只骑首页顶、不占 limit、keyset 之外**，blockId=toolCallId)。未知对话 → `404 CONVERSATION_NOT_FOUND` |
| `POST /{id}:cancel` · `POST /{id}:seen` | **Cancel** 在途生成 / **Seen** 清 `hasUnread`（用户打开线程，幂等 204；与 `:cancel` 共 `{idAction}` 派发器）；动作语法,非删子资源，均 204 |
| `GET /{id}/interactions` · `POST /{id}/interactions/{toolCallId}` | 待决人机交互重同步 / 决议（body `{action, answer?}`：action ∈ approve\|approve_always\|deny\|accept\|decline，枚举外 → `422 INTERACTION_INVALID_ACTION`（先于 broker 查找就拒，不静默当 deny）；answer 仅 ask accept 用），成功 204 |
| `GET /{id}/system-prompt-preview` · `GET /{id}/usage` | 调试预览 / token 用量 |
| `GET /{conversationId}/todos` | 对话工作清单 |
| `GET /{conversationId}/touchpoints` | **对话触点台账**（上下文台账，右岛数据源）：keyset 分页（`?cursor&limit`，`last_at DESC`）+ 可选 `?kind=`（relation 11 kind + `attachment`）/ `?verb=`（mentioned/created/edited/viewed/executed/attached/deleted）过滤（枚举校验，`TP_INVALID_KIND`/`TP_INVALID_VERB`）；行 = `{id,itemKind,itemId,itemName,verb,lastActor,count,firstAt,lastAt,lastMessageId}`。只读——写入仅后端水龙头（chat Send + loop 工具咽喉） |

## attachment / memory（`/api/v1/...`）

attachment：`POST /attachments`（上传）· `GET /{id}` · `GET /{id}/content` · `DELETE /{id}`。
memory：`GET /memories` · `GET/PUT/DELETE /memories/{name}` · `POST /{name}/pin|unpin`（name 即 id）。

## search（`/api/v1/search`，统一搜索）

| Method · Path | 语义 |
|---|---|
| `GET /search` | 综搜/垂搜同端点：`?q`(必填) `&types`(csv，空=综搜) `&tags`(csv) `&updatedAfter/Before`(RFC3339) `&includeArchived`(默认 true) `&cursor&limit`(默认 20 上限 50,走 ParsePageBounded;非数字/<1 → 400)。返 `{data:{hits, total}, nextCursor, hasMore}`——分页坐标顶层、total 在 data 子对象;hit 含 entityType/entityId/name/snippet(`<mark>`)/anchor/tags/archived/score/matchedChunks/refHint（仅积木六类） |
| `POST /search:reindex` | **就地**重建 ctx workspace 索引，204（fire-and-forget、无可轮询产物；force-reconcile 覆盖每个实体词法行、**不** purge-then-rebuild——词法索引从不清空，故并发 Search 返完整结果而非不全/空且无信号，F168-M8/F175-M2；向量缓存仍 invalidate + 重嵌，词法主检索保持完整；**同一 workspace** 运行中再调 409 `SEARCH_REINDEX_RUNNING`——单飞锁 per-workspace、不阻塞别的 workspace 的 reindex，F175-M3） |
| `GET /search/settings` | 机器级搜索设置 + 引擎实时状态 `{embedder, ollamaBaseUrl, ollamaModel, engine:{status: ready\|downloading\|absent\|error\|off, model, lastError}}`（Ollama 字段恒回显生效值） |
| `PATCH /search/settings` | 修补设置：`{embedder?: builtin\|ollama\|off, ollamaBaseUrl?, ollamaModel?}`（缺省字段不动；Ollama 参数空串重置默认）；非法 embedder 400 `SEARCH_EMBEDDER_INVALID`；改 model 即旧模型向量按 model 列失效、后台重嵌 |

LLM 工具面（非 HTTP）：`search_blocks`（积木面板：六类可接线单元，返 ref 直填 workflow 节点）；8 个 `search_<entity>` 垂搜工具保 schema 换引擎（非空 query 走内容引擎、引擎错误回退原子串路径）。

## P6 支撑域

workspace：CRUD（守最后一个；PATCH 含 `webFetchMode`: local|jina）+ `GET {id}/stats`（删除确认的内容盘点,WRK-062 S-11——`{conversations,functions,handlers,agents,workflows,documents,runningFlowruns,generatingConversations,blobBytes}`;计数滤软删、flowruns 数 `status='running'`、generating=chat 内存在飞快照与本 ws 活行求交;`blobBytes` 500ms 预算内 walk 文件树、超时/未接线返 **-1**=诚实未知;路由在 workspaces 豁免前缀、path id 铸 ctx;未知 id 404）+ `PUT/DELETE {id}/default-models/{scenario}`（dialogue|utility|agent 三场景模型；DELETE 清该场景默认回未配；**写时校 apiKeyId 存在性**——引用不存在的 key 即 404 `API_KEY_NOT_FOUND`，非只 invoke 时失败，与「删被引用 key 挡 `API_KEY_IN_USE`」对称，F153；modelId 拼写不校、留 invoke 时 fail-loud）+ `PUT/DELETE {id}/default-search`（搜索 key）+ `POST {id}:activate`（刷 lastUsedAt）。apikey：CRUD（受管 provider 行 **PATCH 与 DELETE 均返 422 `API_KEY_IMMUTABLE`**——受管 gwk_ 凭证无用户侧重开通入口，删除与编辑对称守卫，WRK-062 S-1）+ `:test`（probe）+ `GET /providers`（provider 白名单列表，每项带 `managed` 标记——内置免费档 `anselm` 为 true；**`mock` 仅 `ANSELM_DEV=1` 时下发**——T6 测试设施不进产品下拉，但建 key 白名单恒接受它，S-5）。freetier：`GET /freetier/quota`（免费档本月配额代理——后端解出受管 anselm key 的 `gwk_` install token、Bearer 调网关 `GET /v1/quota`，返 `{limit,used,remaining,resetAt,available}`；客户端无法直读——token AES-GCM 加密存后端、永不出明文；无受管行 404 `FREETIER_NOT_PROVISIONED`，网关自身失败原样冒泡 `LLM_AUTH_FAILED`/`LLM_RATE_LIMITED`/`LLM_PROVIDER_ERROR`）+ `POST /freetier:provision`（手动重开通,S-7——幂等:已有受管行短路;返 `{provisioned:bool}`,true=事后存在受管行(原有或新建),false=开通降级(离线/网关挂/无指纹,状态非错误);boot/OnCreated 钩子仍是主路径,此为用户侧重试口）。model：`GET /model-capabilities` · `GET /scenarios`。sandbox：`GET/POST /sandbox/runtimes` + `GET /sandbox/runtimes/available`（用户可装语言运行时 + 默认/钉死版本，UI 据此渲染、免硬编 pin map；引擎产物 llamasrv/embedmodel 与 docker 不列）+ `DELETE /sandbox/runtimes/{id}` · `GET /sandbox/envs[/{id}]` + `DELETE /sandbox/envs/{id}` · `GET /sandbox/disk-usage` · `GET /sandbox/bootstrap-status` · `POST /sandbox:gc` · `POST /sandbox:retry-bootstrap`；对话级 scratch env：`GET /conversations/{id}/sandbox-envs` · `POST .../sandbox-envs/{kind}:reset` · `POST .../sandbox-envs:reset-all`。relation：list / `GET /relations/neighborhood` / `GET /relgraph`。catalog：`GET /catalog`。limits（**机器级全局单设置**——落 `<dataDir>/settings.json`、与 workspace 无关；统一 auth 门要求 workspace header 仅作身份、对 limits 值无隔离作用，任一 workspace 改的都是这台机器的同一份上限。本地单用户语义下「全局」即正确，非 per-workspace bug）：`GET /limits`（活动运行上限）+ `GET /limits/schema`（逐字段 default/min/max/unit/desc 元数据，UI 据此渲染范围、免复刻 Go 常量）+ `PATCH /limits`（部分 JSON 合并、校验后持久化 `<dataDir>/settings.json` 并热换——消费方下次读取即生效；越界 400 `SETTINGS_LIMITS_INVALID`）+ `POST /limits:reset`（无 body，恢复 `Default()`、持久化并热换——默认由服务端持有，客户端不硬编）。network（机器级同 limits——`<dataDir>/settings.json` 的 `network` 段）：`GET /network` + `PATCH /network`（**整体替换**、非合并;`{httpProxy?,httpsProxy?,noProxy?}` 出站代理;boot 与 PATCH 时应用到进程环境[Go `http.ProxyFromEnvironment` 读之],完整生效须重启 sidecar[既有 HTTP 客户端缓存代理];空=直连;WRK-062 工单⑩）。retention（**机器级**同 limits/network——落 `<dataDir>/settings.json` 的 `retention` 段，无 workspace 维度；scheduler 工单⑬、判决④）：`GET /retention`（返 `{runRetentionDays}`，恒具体值——全新安装读回服务端自持的默认 **90**、绝不 null，故客户端不硬编）+ `PATCH /retention`（**部分合并**、非替换；body `{runRetentionDays?}`——缺省字段不动，故 `{}` 是忠实 no-op 而非意外的「永久」；落盘并**踢一趟清理**［收紧的线立刻回收 run，而非等 ticker 的 6h］。**`0` = 永久保留**［清理绝不跑，碰都不碰 DB］，且往返存活——段在文件里用指针形，「段缺席」与显式 0 可区分；**唯一校验是物理的**：负天数 400 `SETTINGS_RETENTION_INVALID`，UI 的 30/90/180/永久 值集是**产品**可供性、后端不强制［60 照收，拒它是校验剧场，设计原则 #6］；未知字段严格拒 400）。**清理语义**：按**终态 run 的 `completed_at`** 往回数［与 flowrun-stats 的 `completedSince` 同窗口语义——跑了很久刚失败的 run 是**新鲜**的］，只删终态（completed/failed/cancelled）、**running/parked 永不删**（不管多老）；boot 起、每 6h、及每次 PATCH 各跑一趟，逐 workspace 分批物理删。**无 `:sweep` 端点**（裁量：清理是后台卫生、非用户动作；PATCH 已给出「改配置即见效」的即时通路，另开端点是多余 API 面）。**无 `/retention/schema`**（单字段、值集是前端产品决策，无范围可渲）。**D1 归档线例外立法见 [database.md](database.md) flowrun 节**。notification：list / `POST /notifications/{id}:mark-read` / `POST /notifications:mark-all-read` / `GET /notifications/unread-count`。aispawn：`POST /<entity>/{id}:iterate` 分布于各实体 + `POST /executions/{id}:triage`（按 execId 前缀 function/handler/agent/flowrun 分发）。

## 系统 / 可观测性

`GET /api/v1/health`（liveness，N1 envelope，免 workspace；**但不免 bearer**——见下 loopback 加固）· `GET /api/v1/version`（返 `{version}`——构建期 `-ldflags "-X main.version=$(VERSION)"` 盖章,裸 go run 为 `"dev"`;免 workspace 同 /health、bearer 照过,onboarding 前可读,关于页消费）· `GET /api/v1/system/data-dir`（返 `{dataDir}`——解析后的数据目录 = 本地优先存储位置，供桌面端「显示 / 在文件管理器打开」；guarded，与 `/limits` 同走 workspace 门——同为**机器级**端点，header 仅作身份、非隔离轴）。 · `GET /api/v1/network` + `PATCH /api/v1/network`（出站代理配置,工单⑩——机器级同 limits;PATCH 整体替换 `{httpProxy?,httpsProxy?,noProxy?}` 并应用代理 env,重启 sidecar 完整生效）。 · `GET /api/v1/storage-stat`（T4/WRK-070——返 `{dbBytes,deadBytes}`：SQLite 库文件的逻辑大小 + 其中 DELETE 腾出却未还给 OS 的死空间[`page_count·freelist_count × page_size`，先 `wal_checkpoint(TRUNCATE)` 才读 freelist 否则 WAL 中的删除不计入]；存储面板据此诚实显示「X MB,其中 Y MB 可回收」。**机器级**同 data-dir/limits，header 仅身份；**N4 豁免**：单一系统资源、单对象、无游标=有界资源[非集合、非已存投影]，分页参数按标准 HTTP 忽略）。 · `POST /api/v1/storage:compact`（T4/WRK-070，N5 `:action`——存储面板「压缩数据库」按钮：一次**同步全量 `VACUUM`**，返 `{reclaimedBytes,migrated}`[还给 OS 的字节 + 是否顺带把 mode=0 库升级到 `auto_vacuum=INCREMENTAL`]。**200 非 202**：VACUUM 阻塞几秒、有具体结果、非异步流——客户端等待[按钮转圈]拿回回收数。`SetMaxOpenConns(1)` 使锁库期间并发请求在唯一连接上排队而非竞争[可接受的短暂阻塞——用户主动、知情]。**非危险动作**：VACUUM 不删任何逻辑行[D1 裁定不变，见 database.md]。失败[磁盘满、无 VACUUM 临时空间]→ 500 `STORAGE_COMPACT_FAILED`，库不动、可重试）。**仅 dev**（`ANSELM_DEV=1`，`bootstrap.registerDebug`，非 /api/v1 路径故免 workspace 中间件、出货 sidecar 不挂——pprof 是信息泄露/DoS 面）：`GET /debug/pprof/*`（Go pprof——`goroutine`(`?debug=2` 列卡住的栈)/`heap`/`allocs`/`profile`(cpu)/`trace`，抓 goroutine 泄漏=数只涨、内存泄漏=堆只涨、CPU 失控）+ `GET /debug/stats`（运行时快照 JSON：`goroutines`/`heapAllocMB`/`heapObjects`/`stackInuseMB`/`numGC`/`gomaxprocs`/`cgoCalls`）。

**loopback 加固**（本地 HTTP 服务的安全姿态，sidecar 模型）：server 默认绑 **`127.0.0.1`**（env `ANSELM_ADDR` 覆盖；原 `:8080` 全网卡）。中间件栈在日志之后、业务之前加两道门（`router.Chain`，覆盖含 SSE GET 与 /health 的全部 /api/v1）：① **`RequireLoopbackHost`**（**常开**，仅放行 Host=`127.0.0.1`/`::1`/`localhost`，防 DNS rebinding；否则 403 `FORBIDDEN_BAD_HOST`）；② **`RequireBearerToken`**（强制 `Authorization: Bearer <ANSELM_AUTH_TOKEN>`，常时比较；否则 401 `UNAUTH_BAD_TOKEN`。桌面父进程每次启动铸随机 token 注入子进程 env——本机其它进程/网页够到端口也无 token 无法动手。**仅当 server 设了 token 时强制**：dev `make server` / `testend` 不设 `ANSELM_AUTH_TOKEN` 即关闭、零鉴权可用。豁免：`OPTIONS`（CORS 预检无 Authorization）+ `/api/v1/webhooks/`（外部调用方不知 token、自带 HMAC）；**`/api/v1/health` 不豁免**——门控它的是铸 token 的同一进程）。env：`ANSELM_AUTH_TOKEN`（空=关 bearer 强制）· `ANSELM_MASTER_KEY`（静态加密主密钥种子，WRK-062 拍板 #14——设则优先于机器指纹派生（`bootstrap.Config.Fingerprint` 既有缝），桌面端经 OS 钥匙串铸存注入；⚠️ 换种子=既有密文（api_keys/mcp config）全部解不开，key 须重录）· `ANSELM_PARENT_WATCH`（WRK-070 T2 侧车死人开关，`cmd/server` 薄壳级：设则 goroutine 读 stdin 至 EOF 即视父进程已死，汇入与 SIGINT/SIGTERM **同一个** `signal.NotifyContext` 取消 → 同一有序关停（SSE 流 → HTTP 排空 → 后台 → DB，子进程 kill-set 一并收割）；桌面端 spawn 恒设 `1` 且终生握子进程 stdin——父亲以**任何**形态退出（⌘Q/SIGTERM/SIGKILL/崩溃）管道必 EOF；macOS 无 `Pdeathsig` 故此为可移植做法。dev `make server`/testend 不设 = 连 goroutine 都不起、零行为变化）。
