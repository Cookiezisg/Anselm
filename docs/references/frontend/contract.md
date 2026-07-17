---
id: DOC-046
type: reference
status: active
owner: @weilin
created: 2026-06-26
reviewed: 2026-06-26
review-due: 2026-09-26
audience: [human, ai]
---

# 前端契约层 —— 后端线缆的 Dart 投影（`core/contract/`）

> 契约层 = **后端契约的逐字镜像**，非独立设计。所有 DTO 是 `references/backend/{api,database,events,error-codes}.md` + `domains/` 的 1:1 投影；后端改字段 → **同提交**改这里的 Dart DTO + golden（文档纪律延伸到前端契约，见 [`CLAUDE.md`](../../../CLAUDE.md) 前端节）。
> 分层位置见 [`architecture.md`](architecture.md) §2；envelope/paging/错误码契约依据 [`api.md`](../backend/api.md)（N 系列）+ [`error-codes.md`](../backend/error-codes.md)。

## 1. 一句话

后端是事实源，前端零业务规则。契约层只做**编解码**：freezed 不可变值类型 + json_serializable（`explicit_to_json: true`，嵌套对象序列化为对象而非 `toString`）。**线缆 camelCase**（N3）、**无 rename map**（唯一例外：`default` 保留字 → `defaultValue`）。

## 2. 物理结构

```
core/contract/
  api_error.dart           # N1 信封 + ApiException + AnselmErr（前端分支用的精选码常量）
  page.dart                # N4 keyset 分页:Page<T>（data 列表）+ PageWithAggregate<T,A>（data 对象:列表 + 聚合 sidecar）
  workspace.dart           # Workspace(+ ModelRef) —— 唯一鉴权轴实体
  entities/                # Quadrinity 实体 DTO(Phase 4.1 STEP 0,~22 类型)
    values.dart            # 跨域共享值类型 + NodeKind 封闭枚举
    function.dart          # FunctionEntity/Version/Execution + FunctionRunResult(bare)
    handler.dart           # HandlerEntity/Version/Call
    agent.dart             # AgentEntity/Version/Execution + InvokeResult(bare) + MountHealth(Report)
    workflow.dart          # WorkflowEntity/Version + Flowrun/FlowrunNode/FlowrunComposite
    approval.dart          # ApprovalForm/Version(非 Quadrinity 支撑 rail kind;template + 决策规则)
    control.dart           # ControlLogic/Version + Branch(非 Quadrinity 支撑 rail kind;+ 图编辑器边端口下拉)
    trigger.dart           # TriggerEntity(无版本)+ Activation/Firing + TriggerSource/FiringStatus 封闭枚举(支撑 rail kind;观测面)
    document.dart          # DocumentNode(Notion 树节点,一 DTO 兼服 /tree[省 content]与 /{id};file-like 用户可编,无版本)+ 护栏常量
    skill.dart             # Skill + Frontmatter(SKILL.md:name slug 即身份、body+YAML frontmatter;file-like)+ 护栏常量(body≤32KB/desc≤1024/name 正则)
    relation.dart          # EntityRelation(关系图一条边,镜像 relation.go RelationView:kind 4 动词封闭集 + from/to {kind,id,name},名读时 hydrate;文档 backlinks = GET /relations?toKind=document&toId=…&kind=link)
    common.dart            # ExecutionAggregates + CapabilityReport(跨域)
  conversation.dart        # Conversation(rail 行 + isGenerating/awaitingInput/hasUnread 三点 + modelOverride)+ ModelRef
  notification.dart        # NotificationItem(通知中心行:id/type[开放 <域>.<动作>]/payload map/readAt?[null=未读]/createdAt;domain·action·isUnread 读派生)——只投影 Emit 落行档,Broadcast 仅帧回声不现于此(events.md ⊞/⤳)
  interaction.dart         # Interaction(人在环 humanloop.Request 投影:danger 门{summary,args}/ask 提问{message,options}判别联合 + resolved 对称信号[kind/tool 空串在场、判 resolved 位])+ InteractionKind(danger/ask/unknown 前向兼容)+ InteractionAction(approve/approve_always/deny/accept/decline 封闭集,.wire)——信号 content 与 GET interactions 一行同形双源解析
  messages/                # 消息 / run-轨迹块契约(STEP 5;Chat 4.2 共用)
    block_content.dart     # BlockKind(6 sealed)+ Text/ToolCall/ToolResult/Message Content(SSE 帧载荷)
    chat_message.dart      # ChatMessage/ChatBlock —— REST 回合历史投影(GET /{id}/messages,含 blocks)
```

## 3. 信封 + 分页 + 错误（`api_error` · `page`）

- **N1 信封**：成功 `{data:...}`；失败 `{error:{code,message,details}}`。`ApiException.fromEnvelope(body, status)` 解错误体 → 持 `code`/`message`/`details`/`httpStatus` + 状态谓词（`isConflict`/`isGone`/`isUnauthorized`/`isNotFound`/`isTransport`）。`AnselmErr` 只登记**前端实际分支用的**精选码常量（`unauthNoWorkspace`/`unauthBadToken`/`seqTooOld`/`unknown`/`transport`）——~261 错误码全集**保持开放**，不在前端枚举（见契约开放性铁律）。
- **N4 分页**：分页坐标（`nextCursor`/`hasMore`）**永在 envelope 顶层、绝不进 `data`**。`Page<T>.fromBody` 解 `data` 为列表；`PageWithAggregate<T,A>.fromBody` 解 `data` 为对象（`{<listKey>:[...], <aggregate>}`），用于日志页（列表 + ok/failed 聚合）。`isLastPage` = `nextCursor` 缺失 ∨ `hasMore` false（防御性兼容两者不一致）。

## 4. 实体 DTO（`entities/`，Quadrinity 投影）

### 4.1 共享值类型（`values.dart`）

`Field`（typed I/O，`type` 粗粒度开放 String，后端不强校）· `ToolRef`（agent 工具挂载 `fn_…`/`hd_….method`/`mcp:…`）· `MethodSpec`（handler 方法）· `InitArgSpec`（handler `__init__` 配置项，带 required/sensitive/`default`）· `NodePosition`/`RetryConfig`/`Edge`/`Node`/`Graph`（workflow 图）。

**`NodeKind` 封闭枚举**（`trigger`/`action`/`agent`/`control`/`approval` + `unknown` 兜底）—— 5 图节点 kind 是真封闭集（合 CLAUDE.md「仅 seal 真封闭集」），`Node.kind` 用 `@JsonKey(unknownEnumValue: NodeKind.unknown)`，后端若扩集前端不崩。

### 4.2 四实体（function/handler/agent/workflow）

每实体三件套：**Entity**（公共头 `id`/`name`/`description`/`tags`/`activeVersionId`/时间戳 + 嵌入 `activeVersion`，bare-entity 规则）· **Version**（append-only 版本体）· **Execution/Call/Flowrun**（日志行）。差异：

| 实体 | Version 特有 | 日志行 | 实体头特有 |
|---|---|---|---|
| Function | `code` + I/O Fields + env mirror | `FunctionExecution`（`logs` 仅单 GET） | — |
| Handler | imports/init/shutdown/`methods`/`initArgsSchema` + env mirror | `HandlerCall`（+ `method`/`instanceId`） | `configState`/`missingConfig`/`runtimeState`（计算态） |
| Agent | `prompt`/`skill`/`knowledge`/`tools`/I/O/`modelOverride`(复用 `ModelRef`) | `AgentExecution`（+ `modelId`/`apiKeyId`/`provider`/`transcript`，**无 logs**） | — |
| Workflow | `graph`(raw JSON,真相) + `graphParsed`(解析 `Graph`) | `Flowrun`（+ 溯源 `origin?`/`conversationId?`）/`FlowrunNode`（record-once 记忆化行） | `active`/`lifecycleState`/`concurrency`/`needsAttention` |

- **Flowrun 溯源两键**（scheduler 工单①,`origin`/`conversationId` 皆 **`omitempty` 可空**）:`origin` ∈ `manual`/`chat`/`cron`/`webhook`/`fsnotify`/`sensor`(创建时盖章、永不变;**开放 String 非 seal**——线缆缺席=溯源之前的旧行,前端渲「未知来源」、绝不零值撒谎);`conversationId` **仅 `origin=chat`** 在场(调 `trigger_workflow` 的那个 `cv_`)。消费:scheduler 大表行身份=来源短语 + `?origin=` 过滤(工单⑥)。
- **FlowrunNode 排队两戳**（scheduler 工单⑫,`readyAt`/`startedAt` 皆 **`omitempty` 可空**）:随该行**唯一一次 record-once INSERT** 落盘(行仍只写一次、只写终态/parked,绝无先插后终化);因果序 **`readyAt` ≤ `startedAt` ≤ `completedAt`**——`readyAt`=某轮 walk 首次算出该 (节点,轮次) ready 的时刻(排队起点)、`startedAt`=引擎开始处理它的时刻(input CEL 求值+派发;**执行实体自身的起点在其审计行**、非此处)。**两键缺席=旧行或 seed trigger 行(从不排队)→ 无排队段,绝不渲 0**。**`createdAt` 是行的写入时刻=终态/停车时刻,绝非节点起点**(拿它当起点即是 ⑫ 之前的假象);`completedAt` 停车期间为 nil、决断时盖章,故「approval 的 createdAt→completedAt」正是人等区间。消费:甘特三段条(排队灰/执行/停车琥珀)+ 台账与卷宗头「排队 x · 执行 y」双数同源。
- **FlowrunActivityRow**（scheduler 工单⑤,`GET /flowruns/{id}/activity`,N4 分页,**行序 `startedAt` 升序**）= `{nodeId, iteration, kind, execId, status, readyAt?, startedAt, endedAt, elapsedMs}`——四张执行日志表 UNION 的纯读投影。**`kind` 是审计表族**(`function`/`handler`/`agent`/`mcp`)**而非图节点 kind**:`action` 节点按 ref 前缀散入三族,而 **control/approval 内联求值、根本没有审计行**——某节点无活动行是正常事实、不是缺口(呈现端此时回落到该行自身的两戳)。`execId`=审计行 id(`fne_`/`hcl_`/`agx_`/`mcl_`,执行日志深链坐标);`status`=**审计词表**(`ok`/`failed`/`cancelled`/`timeout`)、非节点行三态;`readyAt?` join 自真相行的 ⑫ 排队戳(⑫ 前旧行/无对应存活真相行时**键缺席**;`:replay` 下旧审计尝试行仍在[Log 不删]、可早于存活真相行的戳 → **排队段须钳制 ≥0**)。
- **SchedulerStats / SchedulerTotals / WorkflowRunStats**（scheduler 工单③＋⑭,`GET /flowrun-stats?workflowIds=<csv≤50>&recentN=&since=`,**有界批查 → N4 豁免**、无 `nextCursor`）= `{totals, byWorkflow}`。**`since` 统一窗口收两种文法:RFC3339 绝对起点 或 正回看时长(`24h`/`7d`)**,默认 7d,解析不了 422 `FLOWRUN_STATS_INVALID_SINCE`;`workflowIds` 去重后 >50 → 422 `FLOWRUN_STATS_TOO_MANY_IDS`。**totals(恒全 workspace,刻意不受请求 ids 限制)** = `{running, completedSince, failedSince, parkedNodes, missed}` 五键**全无 omitempty、恒在**;`parkedNodes` **键名叫 nodes、语义是 run 数**(仍 running 且持 ≥1 parked 节点的 DISTINCT run——按工单定形的键名,勿按字面读成节点数)。**`missed`(工单⑭)是唯一不数 flowrun 的 total**——它数的是**本该存在却不存在**的 run:窗内 `created_at` 落入的 `missed` firing 数(跨域数 `trigger_firings`,后端 app 层经 FiringInbox 端口缝入,故本端点是 **Overview 的统计单源**、而非仅 flowrun 两表的投影)。**三条消费端必须知道的性质**:①它与 `completedSince`/`failedSince` **同一个 `since`**(后端只默认一次,故第五张牌物理上不可能与另外四张漂移;**绝不 all-time**——只增的「有史以来错过多少」是虚荣数字,规范禁)②按 `created_at` 开窗,而 missed 行的 `createdAt` **就是那个调度刻度**(工单⑨ 回拨盖戳),故整夜停机摊在**那一夜**、非睡醒那一秒 ③它与 `GET /firings` **同一组谓词**计数(后端 `firingQuery` 单点,`SearchFirings` 与 `CountFirings` 共用)→ **消费端要深链它数的那个列表,就必须把同一个绝对时刻同时发给两个端点**:发相对词 `'24h'` 会让后端按**它的** now 解锚、客户端只能为列表再猜第二个,两份谓词在窗口边缘静默打架=「牌上写 3、点开列表显示 4」。计数**失败绝不吞成 0**(整个批查报错冒上去——「你什么都没错过」与「我查不出来」是两句话)。**byWorkflow**=`{workflowId, running, parkedNodes, lastRunAt?, recent[], successRate?, avgElapsedMs?, consecutiveFailures}`,每个请求 id **恒一行、按请求序**(无 run 的 id 回零值行、绝不缺席;不校验 workflow 存在性——孤儿 run 一等公民);`successRate`/`avgElapsedMs` **窗口无数据即键缺席**(「无数据」≠「0%」,渲 em-dash);`consecutiveFailures` **跳过 running 与 cancelled、只有 completed 停**(cancelled 中性:既不算失败也不算健康的证据)、**不受 recentN/since 约束**。**`failedSince` 是 `missed` 的孪生案例(工单⑮):它同样按 `completed_at` 开窗,故「24h 失败」牌深链到 `GET /flowruns?status=failed&completedAfter=` 时,必须把牌所数的**同一个绝对时刻**发给列表的 `completedAfter`(与发给 stats `since` 的逐字节相同)——同上「牌上写 3、点开列表显示 4」之禁**;不同于 `missed` 深链场次条,`failedSince` 深链的是一个**按 run 的失败列表**(`SchedulerFailedZone`,`failedRuns.length` 即牌数、拉全 `listFailedSince`),绝非 7d 失败聚合(那按 workflow 连败聚合、窗与轴皆不同)。消费:Overview 五张 KPI 牌(全可深链)+ rail 状态点 + 失败聚合连败徽。
- **Firing 检索**(scheduler 工单⑭,`GET /firings`[**workspace 级**] · `GET /triggers/{id}/firings`[逐 trigger],**一个 handler 两个 URL**,N4 **cursor+limit 分页**——firing 是**无界** Log[每分钟的 cron 一天写 1,440 条],**不是**有界投影豁免那一类)= `Page<Firing>` = 顶层 `{data:[Firing], nextCursor?, hasMore}`。过滤**全 AND 组合、每项皆可选**:`?triggerId`(等值;**缺席 = 跨所有 trigger**——firing 是 (trigger × workflow × activation) 的 workspace 级日志行,故「近 24h 的所有 firing」是一等问题;嵌套 URL 上此参被路径 id 覆盖;**不校验存在性**,未知 id → 空页 200 而非 404)· `?status`(**封闭 7 值**,越集 422 `TRIGGER_FIRING_INVALID_STATUS` + details `allowed`,**绝不静默空页**;`unknown` 是入站兜底、**永不可作过滤发出**)· `?createdAfter`/`?createdBefore`(**RFC3339**,归一 UTC,`created_at` 上的**半开窗** `[after, before)`——相邻窗无缝拼接不重叠;非 RFC3339 → 422 `TRIGGER_FIRING_INVALID_FILTER` + details `param`/`got`/`want`;**倒置窗不报错、静默空页**)· `limit`(默认 50、**上限 200 静默钳制**;非数字或 <1 → 400 `INVALID_REQUEST`)。**行序 `created_at DESC, id DESC`(新→旧)**——故**撞帽的一页是「最新那一片」,窗口更老那端是「未知」而非「空」**:把一页当整窗画就是画出一个看起来完整、却藏着隐形空洞的时间轴,消费端必须改为**明说**。`missed` 行的 `flowrunId` **恒缺席**(从未建 run)、`activationId` **恒空串**(记账不是一次动作;键仍在场)。**时区**:`createdAt` 归一 UTC,而同轴的 `SchedulePoint.at` 带后端本地偏移——`fmtDateTime` 内建 `.toLocal()`、`foldEvents` 比的是绝对时刻,故同轴混两种偏移安全,**但绝不比字符串**。消费:Overview 调度轨的**过去半**(真开过的火=实心状态色点 / `missed`=灰 ✕)+「错过 N」KPI 牌的钻取目标(与牌**同一个绝对锚点**,见上条)。
- **TriggerSchedule / SchedulePoint**（scheduler 工单⑧,`GET /trigger-schedule?within=&limit=`,**有界 → N4 免游标**）= `{points:[{at, triggerId, triggerName, workflowIds}], truncated}`——四字段**全无 omitempty、恒在**;`points` 恒非 nil(空即 `[]`)、按 `at` 升序(同刻按 `triggerId` 定序,可依赖)。**只有正在监听且未暂停的 cron 贡献点**——暂停的、无 active workflow 引用的、以及 webhook/fsnotify/sensor(下次 fire 不可知)**一律缺席**,故消费端**泳道行集须取自 `GET /triggers`**(它带 `paused`)、点只是挂件:**从点反推泳道会让暂停的泳道静默消失,直接违反判决①**。`workflowIds` 取自**内存监听表**(与 `refCount` 同源),故点绝不承诺不会发生的运行。`truncated=true`=窗内还有更多(cap 跨 trigger 全局:并集排序后才截,故最早 N 个点是真正最早的 N 个)。**`within` 走 Go duration 文法**(`168h`;**与 flowrun-stats 的 `?since` 不同**——那边额外吃 `7d`,这里传 `7d` 是 422)。**时区注记**:`at` 带后端**本地偏移**(cron `Next()` 保留入参 location)而 flowrun 系戳一律归一 UTC → 同轴混两种偏移,一律 `.toLocal()` 后再比,绝不比字符串。消费:Overview `AnScheduleTrack` 未来点。
- **FlowrunMatrix / MatrixCol / MatrixRow / MatrixCell**（scheduler 工单⑩,`GET /flowrun-matrix?flowrunIds=<csv,去重后 ≤50>`,**有界批查 → N4 豁免**,主页重建 0717）= `{cols, rows, cells}`,三列表恒在(空而非 null)。**`flowrunIds` 必填**——按请求序去重、空串跳过,去重后空集 400 `INVALID_REQUEST`、>50 → 422 `FLOWRUN_MATRIX_TOO_MANY_IDS`(details `allowed`/`got`,逐字沿用 flowrun-stats ids 纪律);**未知/异 workspace id 静默缺席**(cols 自带键、缺席可发现;全未知=三空列表,孤儿 run 一等公民)。**哪些 run 在屏上归客户端**:矩阵窗按页级时间范围翻 `GET /flowruns`(`startedAfter/Before` + cursor,页尺 50=批帽,一页一批)、逐页批取并**归并**(列相接/行首见并集/格相接——`SchedulerMatrixWindowController`)。**col**=`{flowrunId, startedAt, status, elapsedMs?}`,恒正典新→旧(`started_at DESC, id DESC`,**与请求顺序无关**——乱序请求不许左右行轴;呈现层反转成时间轴旧在左、锚最新端);`elapsedMs` 是 **run** 墙钟,**在跑时键缺席**(绝不发会被读成「瞬时」的 0)——**直接判 null,别拿 status 反推**。**row**=`{nodeId, kind}`,序=**首次出现序**(**刻意不用图拓扑序**:每 run 钉死自己的 version,跨版本没有单一的图,硬解一个即对其余撒谎;而首次出现序在要紧处天然就是拓扑序)→ 读作最新 run 的拓扑、更老 run 独有节点追加在后;`kind` 取该 node **最新一次出现**(跨版本会漂移,**本端点是行轴 kind 的唯一诚实来源**,别去版本图里查)。**cell**=`{flowrunId, nodeId, status, iteration, iterations}`,**稀疏**——没跑到即**无格**(前端渲「未及」;**正因稀疏才以扁平格列表下发、每格自带复合键**,绝不假设 `cells.length == rows×cols`)。多迭代=一格聚合:`status` 取各轮**最坏**处置(`failed`>`parked`>`completed`,**不是最后一轮**——第 3 轮失败的 loop 就是在这次 run 里失败过,run 头也是 failed、格与它一致)、同档取最新;`iterations>1` 才渲「×N」。**刻意无逐格 `elapsedMs`**(节点行无 `ended_at`,凑出来的是谎;执行段真相在工单⑤ activity)——绝不拿格算时长。消费:运营主页页顶矩阵区 `AnRunMatrix`(点列/点格=导航进 run 旗舰,`?node=` 预选)。
- **RetentionConfig**（scheduler 工单⑬/判决④,`GET`+`PATCH /retention`,**机器级**——settings.json `retention` 段,与 limits/network 并列,**无 workspace 维度**）= `{runRetentionDays}`(`int`,**无 omitempty、恒具体值**)。**`0` = 永久保留**(清理绝不跑)。**GET 恒返具体值**——全新安装读回**服务端自持**的默认(90)、绝不 null → **客户端永不硬编默认**(故保留面板无 modified/onReset:「是否已修改」需要一个客户端默认来比对,而 `/retention/schema` 并不存在)。**PATCH=部分合并**(基底=当前值,故 `{}` 是忠实 no-op 而非「永久」;**与 network 的整体替换不同**)、返合并后的全量 → 拿返回值回写;落盘即**踢一趟清理**(收紧的线立刻生效,故面板**不需要**「重启生效」提示——别照抄 network 的 restartNote)。**唯一校验是物理的**:负数 400 `SETTINGS_RETENTION_INVALID`;**30/90/180/永久 值集是前端产品可供性、后端不强制**(传 60 照收——拒它是校验剧场,设计原则 #6)。**两个消费者一份真相**:设置存储面板编辑它(`SettingsRepository.getRetention`/`patchRetention`),scheduler 大表读它渲保留墓碑行(`SchedulerRepository.retention()`,只读)——**墓碑是呈现决策,后端零特殊字段**(list 端点不加 `retentionDays`),两 feature 各自解同一条线缆(features 互不依赖)。
- **Storage 磁盘回收**（T4/WRK-070,**机器级**——整个安装一个 `.db` 文件,无 workspace 维度;**无 freezed DTO**,轻量 Dart record 直解，同 `sandboxDiskUsage`）：`SettingsRepository.storageStat()`（`GET /storage-stat`）→ `({int dbBytes, int deadBytes})`（库逻辑大小 + 其中可回收死空间;存储面板显示「X MB,其中 Y MB 可回收」）· `SettingsRepository.compactStorage()`（`POST /storage:compact`,同步全量 `VACUUM`）→ `({int reclaimedBytes, bool migrated})`（还给 OS 的字节 + 是否顺带升级 mode=0 库）。**非危险动作**（VACUUM 不删任何行）→ 不设 `AnTypeToConfirm`,但按钮**忙态**（锁库几秒,「压缩中…」+ 转圈、期间禁用）+ 完成 toast「已回收 Y」+ `storageStatProvider` 失效重取。失败 → `ApiException('STORAGE_COMPACT_FAILED')` 原样上 toast（磁盘满、可重试）。
- **Bare 执行结果**（同步动词直返、**不裹信封**）：`FunctionRunResult`（`:run`）· `InvokeResult`（`:invoke`，带 token/step 计数）。
- **复合解码**（非标准 bare-entity）：`FlowrunComposite` = `{flowrun, nodes, nextCursor?, nodeSummary?}`——**一份解码吃两形**：REST GET /flowruns/{id} 经 `nextCursor` 分页节点；`get_flowrun`/`replay_flowrun` 工具结果经 `nodeSummary` 做 **F173 80 节点封顶**（`FlowrunNodeSummary`=`{totalNodes, shownNodes, byStatus:Map<String,int>, note}`，仅截断时在场；缺席＝`nodes` 即全量）。**真节点数取 `nodeSummary.totalNodes`、绝不数 `nodes.length`**（截断时恒 80）。
- **非 Quadrinity 支撑 DTO**（`control.dart`/`approval.dart`/`trigger.dart`，P1）：`ControlLogic`/`ControlVersion`（`inputs` + `branches` Branch[]`{port,when,emit?}`）· `ApprovalForm`/`ApprovalVersion`（`inputs` + `template` markdown + `allowReason`/`timeout`/`timeoutBehavior`）· **`TriggerEntity`（**无版本**配置信号源:`kind` `TriggerSource` 封闭枚举 + 自由 `config` map + `outputs` + 读派生 `refCount`/`listening`/`lastFiredAt`/`nextFireAt?` + **持久化 `paused`**[scheduler 工单⑦ 运行时止血开关,`:pause`/`:resume` 翻转;**paused=true 时线缆三键同动**——`listening=false` 且 `nextFireAt` 缺席,故「暂停即无下次」是契约不是渲染判断]）+ `Activation`（触发面审计:`fired`/`returnValue`/`payload`/`firingCount`）+ `Firing`（运行面收件箱:`status` `FiringStatus` **7 值**封闭枚举 + `flowrunId?`;**第 7 值 `missed`**=scheduler 工单⑨ misfire 记账——app 停机/睡眠期间到期、醒来记账而**不补跑**,其 `createdAt` 是**错过的调度刻度本身**［后端回拨过］故天然坐落在时间轴的诚实位置、`flowrunId` 恒空［从未建 run］;与 skipped/superseded/shed 同族=中性「未执行」处置,`AnStatus` 折 idle **灰不染红**）**,皆 **无 `tags`**。——**现作 entities rail 的支撑 kind**（control 第 5、approval 第 6、**trigger 第 7**；扩 `EntityKind`[`verb`→nullable + `executable` 位]、`ControlOverview`/`ApprovalOverview`/`TriggerOverview` 概览；支撑 kind＝无执行/run 终端，动词 CTA 由 `executable` 门控）。control 另由图编辑器经 `getControl` 喂边 branch-port 下拉（`controlPortsProvider`）+ 节点分支 peek。approval 运行时=flowrun parked 行（`:decide`）+ 跨 run 铃托盘收件箱（`listFlowrunInbox`）。**trigger 无版本、有两条观测面**——活动（`listActivations`,`?firedOnly`）+ 派发（`listFirings`,`?status`）作首级 tab、复用日志 tab 分页壳；`Fire` CTA 经 `fireTrigger`（`:fire` 合成 `{manual:true}` → 新 activation id）。

### 4.3 跨域（`common.dart`）

`ExecutionAggregates`（日志页 ok/failed 计数，随 `PageWithAggregate` 同行）· `CapabilityReport`（结构可运行性：`problems` 阻塞执行 / `warnings` 仅告知）。

### 4.4 消息块内容（`messages/block_content.dart`，run 轨迹 / Chat 共用）

agent `:invoke` 的 ReAct 轨迹经 **entities 流**（scope `agent:<id>`）以 messages-block 词汇推送（`text`/`reasoning`/`tool_call`/`tool_result`/`progress`，open→delta→close，E3 `parentId` 嵌套）；run 终端（STEP 5）用 `BlockTreeReducer`（`core/messages/`，**唯一框架无关纯模型层**，脱 widget 单测）折成嵌套树、用这批 typed content 渲染，未来 Chat（4.2）在 messages 流复用同一批 DTO（投影自 backend `messages.go`/`loop/{stream,tools}.go` + `chat/emit.go`）。

- **`BlockKind` 封闭枚举**（`text`/`reasoning`/`tool_call`/`tool_result`/`progress`/`compaction` 6 持久块型 + `message` 元包装 + `unknown` 兜底）—— 6 block 型是真封闭集（合 CLAUDE.md「仅 seal 真封闭集」）；线缆 `node.type` 仍是开放 String（`StreamNode.type`），`BlockKind` 只是消费方归类（`blockKindFromWire` 未知→`unknown`、不抛）。
- **typed content**：`TextContent`（text/reasoning，reasoning 带 `signature?`）· `ToolCallContent`（`name`/`arguments?`/`summary?`/`danger?`/`entityName?`；`danger` 开放 String 三级 safe/cautious/dangerous；`entityName` = 后端关帧经 touchpoint Namer 从 arg id 解析的**主目标实体显示名**，使卡头 chip 显名而非裸 id[Run Function «sync_inventory»]，无可命名目标时缺席、前端退回 id）· `ToolResultContent`（`content`；挂 tool_call 下 E3）· `MessageContent`（`role`/`subagent?` + 终态 `status`/`stopReason`/token 计数；仅 messages 流的 chat 包装，agent 的 entities 镜像无此包装、顶层块即根）。
- **REST 回合历史（`messages/chat_message.dart`，Chat transcript 水化）**：`ChatMessage`（`msg_`；`role`/`status`/`stopReason?`/`errorCode?`/`errorMessage?`/token 计数/`provider?`/`modelId?`/`subagentId?`[≠'' 不入顶层 transcript]/`attrs?`[user 回合冻结:`attachments` id 数组 + `mentions` 快照 `{type,id,name,content?}`——坏引用降级 `name:"(unavailable)"` 且无 `content` 键]/`blocks[]`）+ `ChatBlock`（`blk_`;`type` 开放 String/`seq`/`parentBlockId?`/`attrs?`[持久分型附加:tool 名/summary/danger/entityName 等——live 帧里内联在 content,水化两处都读]/`content`/`status`/`error?`/`createdAt?`[P1-e:后端一直序列化,块生锚点(危险工具/压缩标记)以此计时;live 帧 close 快照前无行时刻故可空]）。线缆序 keyset 新→旧,水化反转;投影自 backend `messages.go` json tag,与 SSE 载荷(`block_content.dart`)是同一真相的两面。`Conversation` 增 `modelOverride: ModelRef?`（PATCH 三态:ref=设/显式 null=清/缺键=不动）。
- **W6 导航契约（`messages/transcript_nav.dart`）**：`MessagesWindow`（`?around=` 窗 envelope 投影——`messages`[线缆键 `data`,newest-first]/`targetId`/`olderCursor`[''=已尽,喂回 `?cursor=`]/`newerCursor`[喂 `?cursor=&dir=newer`]/`hasOlder`/`hasNewer`;transcript 跳转径**整窗替换**[re-anchor],绝不缝进连续分页）+ `TranscriptAnchor`（`GET /{id}/anchors` 行——`kind` 开放 String[当前词表 user|tools|danger|compaction|abnormal|gate,unknown 兜底不渲不谎]/`messageId?`[''=无跳,gate 常态]/`blockId?`/`title?`/`count?`[tools 簇折叠数]/`at`）。repo 缝:`messagesAround`(经 `ApiClient.getEnvelope` 取**整** envelope——坐标顶层与 data 并列,`getData` 会丢)/`listMessagesNewer`(dir=newer)/`listAnchors`。

## 5. 契约开放性铁律（seal 谁、不 seal 谁）

**仅 seal 真封闭集**（NodeKind 5 + unknown；BlockKind 6 + `message` + unknown；**TriggerSource 4 源 `cron`/`webhook`/`fsnotify`/`sensor` + unknown**；**FiringStatus 7 `pending`/`claimed`/`started`/`skipped`/`superseded`/`shed`/`missed` + unknown**——皆 `@JsonKey(unknownEnumValue:)` 兜底,firing `?status` 过滤只发真七种[后端非法值 422 `TRIGGER_FIRING_INVALID_STATUS`,details 带 `allowed`]）。协议级**保持开放 + 字符串兜底**：错误码（~261，前端只精选常量）· `lifecycleState`/`concurrency`/`configState`/`runtimeState`/`envStatus`/`status` 等状态串（开放 String，不枚举）。理由：后端是唯一事实源，前端枚举状态串 = 给自己埋未来不兼容；开放 String + UI 层 `status_state` 折叠语义即可。

## 6. 纪律

- 改后端 DTO 字段/端点 → **同提交**改对应 Dart DTO + `entities_test.dart` golden（fromJson↔toJson key-equal）。
- codegen 产物（`*.freezed.dart`/`*.g.dart`）**入库**（源等价、deterministic，fresh checkout 直接 analyze）；`build.yaml` 把 freezed/json scope 限到 `contract/**` + `features/**/data/**`，`explicit_to_json: true`。
- 门禁 `make fe-verify`：codegen + `flutter analyze` 净 + `flutter test` 绿（含契约 golden）。
