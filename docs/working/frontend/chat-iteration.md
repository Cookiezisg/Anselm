---
id: WRK-077
type: working
status: draft
owner: "@weilin"
created: 2026-07-23
reviewed: 2026-07-23
review-due: 2026-10-21
audience: [human, ai]
---

# WRK-077 · Chat 迭代:驻地(可选工作目录)+ 会话操作补全

> **状态:规范已写就(0723),用户明令「先不施工」——今天把所有想做的聊完,最后统一开工。**
> 调研两路已完成(0723):①后端事实盘点(对话域/工具框架/确认闸/fork 物料,结论内嵌 §2);②主流产品对齐(ChatGPT/Claude.ai/Claude Code/Codex/Cursor/Windsurf,Codex 语义为驻地蓝本)。

---

## §0 一句话

两条线:**A. 会话操作补全**——复制 / 分叉(fork 成新对话)/ 原地重试+版本翻页 / 编辑重发 / 消息排队;**B. 驻地**——对话级可选工作目录,Codex 式「zoom in 不设墙」,面包屑驻地按钮三态,git 感知分期(分支显示 → 分支操作 → worktree)。

---

## §1 已拍板决策(0723 用户逐条定)

| # | 决策 | 内容 |
|---|---|---|
| 1 | **分支模型 = fork 成新对话** | 不做树内分支/版本切换器改造(messages 是 D1 append-only,树内分支要动 seq/三读形态/SSE/reducer 根基,否决)。fork = 前缀复制成新对话,原对话不动。 |
| 2 | **最后一轮特权律** | 重试/编辑重发只在**最后一轮**原地做(旧版不删、追加新版、指针记现行版);历史消息只能「从这里分叉」。 |
| 3 | **重试含成功回合** | 不限失败——最后一轮任何回复都可重试(可换模型),版本翻页 `‹ 2/2 ›` 永远可回看旧版。 |
| 4 | **导出不做** | 用户裁掉;分享链接(SaaS)不做。 |
| 5 | **驻地 = zoom-in 非监狱**(Codex Auto 语义) | 挂目录只是告诉 AI「我们 zoom in 到这里」:命令在此执行、相对路径以此为根、系统提示告知。**看外面随便**(PathGuard 黑名单照旧);**写外面强制人闸**(复用现有确认弹窗,不造 OS 沙箱)。 |
| 6 | **不挂 = 现状** | 不选目录一切照旧(九个宿主工具仍常驻,无焦点而已),不收走工具。 |
| 7 | **子代理继承**父对话驻地 | — |
| 8 | **分支信息收进驻地菜单** | 面包屑按钮只显 电脑图标 / 文件夹图标+目录名;git 分支、脏点在菜单里。 |
| 9 | **fork 标题**=「原标题 (fork)」 | 起步固定名,自动命名接管(接管触发条件施工时核对,见 §6)。 |
| 10 | **git 操作分期** | WD1 只读显示 → WD2 分支切换/新建 → WD3 worktree(「为此对话开一个 worktree」,把并行会话纪律产品化)。不做迷你 git 客户端,只做与「对话驻地」相关的动作。 |
| 11 | **排队** | 生成中 Enter 入队不报错,回合终态后按序自动发,`↑` 取回编辑,停止=真打断。纯前端。 |

---

## §2 集成契约

### 2.1 后端既有事实(调研结论,file:line 为证)

- **宿主工具已常驻全开**:`Read/Write/Edit`(filesystem)+ `Glob/Grep/LS`(search)+ `Bash/BashOutput/KillShell`(shell)是 Resident 工具,注入每个对话(`bootstrap/build_services.go:279-282`);文件工具只收**绝对路径**(`pkg/pathguard/pathguard.go:202`),Bash **不设 `cmd.Dir`**(`tool/shell/bash.go:312`)。两处**旧立法「桌面 agent 无工作目录」**(`tool/shell/shell.go:6-13`、`pkg/agentstate/agentstate.go` 包注释)——WD1 翻案,同提交重述注释。
- **确认闸零改动可用**:danger 三级自报 + 人闸(`loop/tools.go:167-207 dispatchWithGate`,内存 broker `app/humanloop/`,interaction ephemeral 帧)对任意工具通用;skill allowed-tools 预授权按 `Name()` 匹配。
- **messages/message_blocks 是 D1 Log 表**(append-only、无 deleted_at):原地删改违宪 → fork/版本指针都是**追加+指针**,零删除。
- **block.seq 每对话单调**(`store/messages/messages.go:478 nextSeq`),`parent_block_id` 承嵌套 → fork 复制必须 seq 重排 + 嵌套 remap。
- **附件内容寻址**(`att_` 行 + sha256 blob,`infra/fs/blob`,无 conversation_id)→ fork 引用共享零拷贝,GC 按 workspace 活跃 sha 保活,安全。
- **touchpoint/relation/通知/flowrun/todos 均不复制**(原对话的历史真相);人闸 always-allow 白名单按 convID 键,fork 天然不带走(同 Claude Code `--fork-session` 重授权语义)。
- **上下文装配已有排除机制**(`LoadThreadForLLM`:subagent_id 过滤 + summary 水位下推 SQL)→ 版本指针过滤是同族第三个条件,顺路。
- **对话串行队列**(`app/chat/chat.go` convQueue,一次一个 assistant 回合;生成中 Send → 409 `STREAM_IN_PROGRESS`)→ retry 重生成入同一队列;排队留在前端。
- **`aispawn`**(`app/aispawn/aispawn.go`)的 `CreateWithSystemPrompt` 造头 + `messages.CreateMessage` 灌行,fork 可复用,无需新基建。

### 2.2 新增契约草案(施工时逐字落 `references/backend/`,此处为拍板形)

| 契约 | 草案 | 宪法关涉 |
|---|---|---|
| `conversations.work_dir` 列 | TEXT,空=未挂;PATCH 面(与 title/model_override 同径);DTO 进前端契约 | D 系列登记 database.md;N3 wire `workDir` |
| `conversations.forked_from_conversation_id` / `forked_from_message_id` 列 | 血缘;fork 时另发一条 relation 边(fork→源)喂关系图 | D 系列登记 |
| `messages.superseded_by` 列 | 空=现行版;retry/编辑重发时旧行写新 msg id。LLM 装配过滤 `superseded_by=''`;REST 三读形态**返全部**(前端翻页需要旧版),新版消息 attrs 带 `retryOf` 供前端组版本组。指针实现允许施工时微调,**语义不变:零删除、旧版永可读** | D 系列登记;非逻辑删除(行仍返、UI 可翻看),合 D1 |
| `POST /conversations/{id}:fork {atMessageId}` | 前缀复制(**含** atMessageId):对话头(system_prompt/attached_documents/model_override/work_dir)+ 前缀窗内全部消息行(含 subagent 行,LLM 装配自然排除)+ blocks(seq 从 1 重排、parent remap、context_role 重置);summary:at 点在水位后 → summary+水位同抄,at 点在水位前 → 不带 summary、水位 0(summary 概括了超出前缀的内容,带走即撒谎);标题「原标题 (fork)」+ auto_titled=false;返 201 新 Conversation。**user 消息「分叉预填」变体是前端糖**:对 user 消息分叉 = 后端 fork 至它的前一条,前端把原句填进新对话 composer | N5 动作后缀;api.md + domains/conversation.md;testend |
| `POST /conversations/{id}:retry {content?, modelOverride?}` | 仅当末回合已终态,否则 409。无 `content` = 重生成:supersede 末 assistant,入队重跑(不写新 user 回合);有 `content` = 编辑重发:supersede 末 user+assistant 两条,落新 user 回合(保留原附件引用)+ 新 assistant 回合。SSE 走既有帧型(新回合正常 open/delta/close,message attrs 带 `retryOf`),**不加新流不加新帧型**(E1/E2) | N5;api.md;testend |
| `GET /conversations/{id}/workdir` | `{path, exists, isGitRepo, branch, dirty}`(WD2 加 `branches[]`,WD3 加 `worktrees[]`);现算派生投影,无游标(N4 有界投影同类) | api.md;N4 登记 |
| block 型 `marker` | CHECK 封闭集加一型(六→七):行内标记块,attrs `{kind:'workdir', from, to}`——驻地中途切换落一条 durable 标记,翻旧对话不迷路(现有 compaction 低语同类呈现)。将来可复用其他 kind | D 系列 CHECK 立法;events.md node.type 不变(marker 随消息读取,不新增 SSE 帧型,施工时核对呈现路径) |
| 系统提示注入 | 挂驻地的对话,每轮系统提示带「工作目录 X · 分支 Y」;subagent 继承(`subagent.go:181` fresh AgentState 处播种) | domains/chat.md |
| 越界写强制闸 | Write/Edit 目标 canonical 路径在驻地子树外 → 无视 LLM 自报 danger,强制走人闸。路径判定不手搓:Go ≥1.24 用 `os.Root`,否则 `EvalSymlinks`+前缀校验(OWASP 共识;Cursor denylist 被绕的教训 → 主防线是根内白区,PathGuard 黑名单继续兜底) | domains/tool 域文档 |

**零后端项**:复制消息(前端 markdown 拼装,工具卡不进剪贴板)· 排队(前端队列,回合终态后逐条 send)· 最近目录(前端机器级持久化轴)。

---

## §3 前端呈现规范

### 3.1 驻地按钮(面包屑,对话名前)

- **三态**:未挂=电脑图标(语义诚实:活动范围=整台机器)→ 点击弹小菜单「选择工作目录… / 最近目录」;已挂=文件夹图标+目录名(窄窗截断);生成中不禁用(切换下轮生效)。
- **驻地菜单**(三段式文法,右岛同语言):①身份头=完整路径 + 在 Finder 中显示 / 在终端打开;②驻地操作=切换工作目录… / 退出工作目录;③git 段(仅仓库)=当前分支+脏点(WD1)、切换/新建分支(WD2)、**为此对话开一个 worktree**(WD3:`git worktree add` 平行目录 + 驻地自动切过去)。
- **中途切换**:对话流落 `marker` 行内标记「📁 驻地 → X」。
- demo 模式配 fixture 假脸(app/demo 共壳律)。

### 3.2 消息动作排

浅灰小图标贴消息下沿;**最后一轮常显(浅灰)、历史 hover 现**;生成中的回合不显示(只有停止)。

| 消息 | 动作 |
|---|---|
| AI 回复·最后一轮 | 复制 · 重试(可换模型)· 从这里分叉 · 版本翻页 `‹ 2/2 ›` |
| AI 回复·历史 | 复制 · 从这里分叉 |
| 我的消息·最后一轮 | 复制 · 编辑重发(原地换整轮) |
| 我的消息·历史 | 复制 · 从这里分叉(原句预填进新对话 composer) |

- 分叉心智一句话:「时间在这里岔开」——AI 回复上=停在刚答完;user 消息上=停在说出之前+预填。
- 版本翻页:旧版永可回看;继续聊后翻页仍在,后续基于哪版有小标记(不撒谎)。
- 复制=该消息正文 markdown。

### 3.3 左岛与血缘

- rail ⋯ 菜单加「分叉对话」(=从最新处分叉)。
- 分叉对话头部一行极轻「分叉自 ×××」可点回源头(读 forked_from 列;relation 边喂关系图)。

### 3.4 排队

composer 生成中收 Enter → 入队;输入框上方队列 chip 行(点开改/删),`↑` 取回最后一条;停止按钮=打断(不清队列,清不清施工时给交互稿定)。

---

## §4 工单拆解(建造批次;每张:门禁全绿 + 文档 1:1 同步 + 真机截图验收)

| 工单 | 范围 | 后端 | 验收要点 |
|---|---|---|---|
| **CH-a 动作排+复制+排队** | 3.2 骨架(复制/分叉入口占位)+ 3.4 排队 | 零 | 五电池(空/超长/流中/队列极值/注入);排队与 409 的竞态测试 |
| **CH-b fork 全套** | `:fork` + 消息级/左岛入口 + 血缘行 + (fork) 标题 | `:fork` 端点 + 两列 + relation 边 + testend(前缀窗/seq 重排/嵌套 remap/summary 两分支/附件共享) | fork 深历史对话真机验;分叉预填变体 |
| **CH-c 重试+编辑重发** | 版本翻页 UI + 重试(换模型)+ 编辑重发 | `:retry` + `superseded_by` + 装配过滤 + testend(重生成/编辑重发/非终态 409/版本链) | 翻页回看旧版;继续聊后基于版标记 |
| **WD1 驻地地基** | 按钮三态 + 选/切/退 + 最近目录 + 菜单①②段 + git 只读段 + marker 标记 + demo fixture | `work_dir` 列/PATCH + ctx 播种(**翻案两处旧立法注释**)+ 三族工具定根(Bash cmd.Dir/相对路径/越界写强制闸)+ workdir 端点 v1 + 系统提示注入 + subagent 继承 + `marker` 型立法 + testend | 挂/不挂两态行为;越界写弹闸;相对路径工具卡显示 |
| **WD2 git 操作** | 菜单 git 段:切换/新建分支 | workdir 端点加 branches[] + 操作动作(shell out git,不重造) | 脏区切分支的护栏语义 |
| **WD3 worktree** | 「为此对话开一个 worktree」 | worktree add + 驻地切换一条龙 | 与 `make worktree` 纪律对齐的路径约定 |

**建议施工顺序**:**CR-1 → CR-2**(真机崩溃,插队最前,见 §5.5)→ CH-a → CH-b → CH-c → WD1 → WD2 → WD3(待用户最终确认,§6)。

**文档同步面总表**(#9):database.md(四处列/CHECK)· api.md(两 :action + workdir 端点)· domains/{conversation,chat}.md · events.md(marker 呈现路径)· frontend contract.md(DTO)· features/chat.md(动作排/驻地按钮形态)· CLAUDE.md chat 状态节(战役收口整体重述)。

---

## §5 明确不做 / 暂缓(记档)

树内分支版本切换器(违宪+伤筋动骨,fork 覆盖)· 整会话导出 / 分享链接(用户裁掉;不做 SaaS)· 手动 compact(后端已全自动)· OS 级沙箱(Seatbelt/Landlock——人闸+根内白区已够本地单用户,记档远期)· 代码 checkpoint 回退(Claude Code /rewind 双轴;等驻地有写文件行为量后再议)。

## §5.5 CR 批 · 真机崩溃根治(0723 用户真机日志,插队最前)

> **用户 0723 真机跑 app 连环报错并 `Lost connection to device`(真崩)。** 诊断已闭合:一个根因、抄在 9 处。
> 崩溃优先于任何 feature——CR 批排在 CH/WD 之前。

### 症状链(五条错误全部由同一根因解释)

1. `Build scheduled during frame`(setState 来自 layout/paint 回调)
2. `A _RenderLayoutBuilder was mutated in _RenderSingleChildViewport.performLayout`
3. `'debugNeedsLayout': is not true`
4. `InheritedElement`:`'_dependents.isEmpty': is not true`
5. `framework.dart:6417`「check that it really is our descendant」→ **crash**

### 结构性总根因(0723 第二份真机栈确证):**整个 app 建在 `LayoutBuilder` 里**

`AnShell.build`(`core/ui/an_shell.dart:208-210`)= `Padding` → **`LayoutBuilder`** → 三岛全部内容(左岛 `_RailStack` / 海洋 `_OceanStack`,两者都是 `AnLazyIndexedStack`)。`LayoutBuilder` 的 builder **在布局阶段执行**,于是:

> **任何海洋 / rail 的首次挂载,以及岛宽变化引发的重建,全都发生在 layout 期间。**

第二份栈逐帧坐实(自下而上):`flushLayout` → … → `RenderPadding.performLayout`(壳的 shellPad)→ `_RenderLayoutBuilder.performLayout` → `buildScope` → inflate 一整棵子树(100+ mounting 帧)→ `EntityRail.build` → `ref.watch(railModelProvider)` → 首建 provider 图 → `entityRepositoryProvider` 的 `ref.watch(apiClientProvider)` 触发脏祖先 flush → 该 flush 回头 `_invalidateSelf` → Riverpod `scheduleProviderRefresh` → `UncontrolledProviderScope.setState()` → **「setState called during build」**。

**与第一份日志的关系:同一个结构病、两个不同触发**——①滚动监听器在 layout 期改全局 provider(下节);②子树在 layout 期首挂,provider 图初始化时自失效。**只治①治不干净**,故 CR-1 升格:

- **CR-1a 结构治本(优先)**:壳只需要**宽度**来算岛宽与 S11 冻结闸——改用 `MediaQuery.sizeOf(context).width` 减去已知 `shellPad`(壳是满窗根,窗宽即权威),**删掉这个 LayoutBuilder**,让三岛内容回到正常 build 阶段。施工前核对壳确实满窗、以及 S11 冻结闸所需量是否全可由窗宽推出。
- **CR-1b 触发面清理**:即下节九处滚动监听器。
- **副作用红利**:今天每次岛屿拖拽/开合都在 layout 里重建全部内容,治本后这条热路径同时变便宜。

### 触发面(CR-1b):滚动监听器里同步触发重建

`ScrollController` 的 listener **在布局期也会触发**(viewport `applyContentDimensions` 校正 offset 时同步 notify;`jumpTo` 亦然)。我们在 listener 里**同步改全局 provider / setState**,于是 markNeedsBuild 落在 layout 阶段 → 正在布局的 `SingleChildScrollView`(`AnPage`/`AnInspector` 都是)其后代 `LayoutBuilder` 被弄脏 → 框架拒绝(#2)→ 布局不变量破(#3)→ 帧中途拆建子树使 `InheritedElement` 依赖账本错位(#4/#5)→ 崩。

**同一反模式的 9 处**(全部 `_scroll.addListener(_onScroll)`,`_onScroll` 内同步产生重建):

| 文件 | 行 | 副作用 |
|---|---|---|
| `features/settings/ui/settings_ocean.dart` | 53 | `setCollapsed` 全局 provider |
| `features/scheduler/ui/scheduler_home.dart` | 79 | 同上 |
| `features/scheduler/ui/scheduler_run.dart` | 89 | 同上 |
| `features/scheduler/ui/scheduler_overview.dart` | 79 | 同上 |
| `features/entities/ui/entity_ocean.dart` | 70 | 同上 |
| `features/entities/ui/overview/entities_overview.dart` | 54 | 同上 |
| `features/chat/ui/chat_transcript.dart` | 225 | `loadOlder()` 改 provider |
| `features/entities/ui/run/run_terminal.dart` | 71 | `setState` |
| `core/ui/an_term_viewport.dart` | 96 | `setState` |

**放大器**:`entity_ocean.dart:91` / `scheduler_home.dart:102` / `settings_ocean.dart:122` 在 `ref.listen`(选区变化)里同步 `_scroll.jumpTo(0)`——`jumpTo` 立即 notify → 直落上表回调。**最可疑复现路径:实体/调度/设置海洋滚下去后切换选区。**

**做法**:①结构性——头折叠改**局部 `ValueNotifier<bool>`** + 头部就地 `ValueListenableBuilder` 消费,滚动永不弄脏壳的 build scope(顺带去掉每帧滚动重建全壳的开销);②兜底律——滚动监听器内一切外溢副作用按 `SchedulerBinding.schedulerPhase` 判相位,帧在飞则 `addPostFrameCallback` 延后;③`jumpTo` 同理延后;④核对 `setCollapsed` 是否去重(现每滚动帧都调)。
**验收**:六海洋滚动+切选区无异常;`flutter test` 加一条「滚动期内容尺寸突变不产生 layout 期 markNeedsBuild」的守卫测试。

### CR-2:错误钩子在连环崩时丢失定位信息

Flutter 只对**一帧内第一条**错误打完整 dump(含肇事 widget + 堆栈),其后全折叠成 `Another exception was thrown: …`——本次日志正因此无法直接指认现场。`core/error/error_boundary.dart:18` 未调 `FlutterError.resetErrorCount()`。
**做法**:onError 内 `resetErrorCount()`(dev/debug 档),让每条都出完整 dump;顺带评估把 dump 落文件(与 WRK-042 崩溃日志设施对齐,不重复造)。

### 已证伪(记档,免得重查)

`AnComposer._editKey` 跨 pill↔card 两棵子树的 GlobalKey 搬家发生在 `LayoutBuilder` 内(=布局期 reparent),形似 #4/#5 的成因,**曾为头号嫌疑;临时测试实打实打字触发形变往返,未复现任何断言 → 证伪**。但记一笔:`test/core/ui/` 下**无 `an_composer_test.dart`**,该原语缺原语级测试,CR 批顺手补(形变往返 + 焦点/光标不丢)。

## §5.7 CR-3 · Scheduler 右岛 Output 树「展不开」(0723 用户真机)

> 用户报「Scheduler 执行子页面右岛 Output 这个树无法展开」。**与上面的崩溃无关**——展开态是 `AnJsonTree` 的**本地 State**(`TreeSliverController`),不经 provider,那条 Riverpod 异常影响不到它。这是一个独立的真 bug。

**根因**:宿主给树的**视口高按「折叠时的顶层键数」算死,展开后不生长**。
`features/scheduler/ui/scheduler_run_inspector.dart:499-508`:

```
height: (node.result.length * AnSize.row).clamp(AnSize.row, AnSize.jsonViewport)
```

`node.result.length` = **顶层键数**(截图里 `{length, sorted}` = 2)→ 高 = 2×32 = **64px**。树本身是虚拟化 `TreeSliver`(必须由宿主给定高、不能 shrinkWrap),`openDepth: 1`。于是点开 `sorted [8]`:**树确实展开了**,8 个子行进了内容区——但视口仍是 64px、且 `sorted` 本就是第 2 行(最后一个可见行),新行全在折线以下,框内滚动又没有可见示能 → 肉眼所见就是「点了没反应」。

**做法(施工时定稿)**:高度改为跟随**当前实际可见行数**(TreeSliver 的活节点数),仍以 `AnSize.jsonViewport` 封顶;超顶时给出明确的可滚示能(现有 `AnFadeCollapse`/滚动渐隐族已有件,复用不手搓)。核对 chat 右岛与实体调试台是否有同款「按折叠态算死高」的写法,一并清。

**顺带一个待验的隐患**:`an_json_tree.dart:93` 的 `didUpdateWidget` 用 `old.data != widget.data` 判重建,而 Dart 里 Map/List 的 `!=` 是**按实例身份**——上游只要重新解析出一个新 Map(SSE tick / 轮询 / DTO 重建),树就整棵重建、展开态清零。当前 run 已终态所以未必踩到,**活运行卷下很可能踩**;施工时构造活 run 验证,真踩就改成按内容判等或按节点 id 保留展开集。

## §5.6 SK 批 · 设置「模型与密钥」按类分栏(0723 用户提)

> 用户原话:「模型 key 的配置和搜索 key 的配置应该分开吧,现在 +API 都混在一起了。」**成立,且是纯前端**——后端早已分好类,是 UI 把它拍平了。

**物理事实**:后端 provider 目录 `backend/internal/app/apikey/providers.go:53` 每家都带 `Category ∈ {llm, search}`——**13 家 LLM**(openai/anthropic/google/deepseek/openrouter/qwen/zhipu/moonshot/doubao/ollama/custom + managed 的 anselm 免费档 + dev-only mock)与 **4 家搜索**(brave/serper/tavily/bocha);Dart DTO 已逐字镜像(`core/contract/api_key.dart:42`)。**零后端改动。**

**症结**:`models_keys_panel.dart` 三处该用 category 的地方只用了一处——
| 位置 | 现状 |
|---|---|
| 区②密钥列表(:78) | **一个扁平列表**,只按 managed 排序;Brave 搜索 key 夹在 OpenAI 与 DeepSeek 之间,毫无区分 |
| 添加流程 stage 0 logo 网格(:473) | **一个 `Wrap` 铺全部 16 家**,模型厂与搜索厂混在一起 ← 用户指的就是这里 |
| 区④搜索区(:1134) | 唯一用了 `category == 'search'` 的地方,只为填「默认搜索 key」下拉 |

**做法**:
1. 密钥区拆两段 `AnSection`:**模型密钥**(managed 免费档行仍锁顶)/ **搜索密钥**,各带自己的 `+ 添加`。
2. 添加流程带类别:`settingsDetailProvider.push(String kind, {String? id})` 加 `category` 字段(**不**把语义编进 kind 字符串),stage 0 的 logo 网格据此只渲同类厂家。
3. **区④并入搜索密钥区**(面板四区→三区):「默认搜索 key」与它管的那些 key 挨着,不再孤悬面板底部。
4. **诚实性补丁**:默认搜索下拉只收 `testStatus == 'ok'` 的 key——搜索区内对 pending/error 行明说「探测未过,不会进默认」,否则用户刚加完 key 却在下拉里找不到、且无从得知原因。
5. 顺手:`models_keys_panel.dart` 已 1193 行,分栏是拆文件的自然时机(可选,不强求)。

**验收**:两区各自增删改探测;添加流程只见同类厂家;搜索 key 探测失败时区内有解释;i18n 新键;`make -C frontend quick` 绿 + 真机截图。

## §5.8 ES 批 · 实体页空态墓碑退役(0723 用户提:「函数如果没有依赖的话会有个墓碑」)

**现状**:`detail_sections.dart:67` 的 `insetEmpty(title)` = `AnState(kind: empty, size: inset)`——一个带 **inbox 图标 + 16 内距**的方块。用户点名的那处(`function_overview.dart:133`)传的 title 是 `d.val.none` = **`'—'`**,于是渲出来是「**一个空收件箱图标 + 一个破折号**」占掉约 100px,而它所在的「环境」卡里其余五行全是 32px 的 KV 行(`状态 ready` / `Python 3.12` / `env id …`)。**图标带着"空收件箱"的重语义,文字什么也没说,还比邻居高三倍**——与项目自己立的「退役墓碑 / 空字段引导律」(新人之旅第一、二站)正面冲突。

**全量 13 处,分两类**:

**A 类(7 处)= 卡内某字段无值** → 应降为**同卡一条 KV 行 + 破折号**,与邻行同文法(`依赖 —`,一行 32px):
`function_overview:133` 依赖(用户点名)· `handler_overview:75` 初始参数 · `agent_overview:66/84/91` 工具/技能/知识 · `control_overview:40` 分支 · `workflow_overview:73`(标签施工时确认)。
**其中 `agent_overview:108` 是错得更离谱的一个**:它的 title 是 `d.val.modelDefault` = **「工作区默认」——根本不是空**,而是"继承了默认值",却渲成墓碑。必须改为 KV 行(可带一个弱「继承」标记)。

**B 类(6 处)= 整个实体无活动版本**(`insetEmpty(d.state.noActiveVersion)`,六实体各一)→ 这是"整页没内容"、不是字段空,按新人之旅第二站的**空字段引导律**该给**引导 + 动作**(「这个函数还没有活动版本」+ 创建入口),而非墓碑。**逐实体文案与动作待定,列 open question。**

**根治红利**:A、B 两类都改完后 `insetEmpty` **零使用者 → 删掉**(「同轨」战役点名过的「原语只生不收」之罪,顺手清)。

**验收**:六实体详情页各自的空字段真机核对(截图);无墓碑残留;`insetEmpty` 已删;i18n 新键;`make -C frontend quick` 绿。

## §5.9 RI 批 · 右岛开合闪烁+卡顿(0723 用户提:「左岛丝滑、海洋平滑,右岛闪+卡」)

**用户观感是对的,而且成因是结构不对称——左岛有的两样东西,右岛都没有。**

### 病灶①(主因):开合那一帧,整棵 inspector 被**重新挂载**

`core/ui/an_shell.dart:763-772`:
```dart
final island = AnIsland(
  child: widget.open
      ? widget.child
      : ExcludeFocus(child: ExcludeSemantics(child: IgnorePointer(child: widget.child))),
);
```
`open` 一翻转,`AnIsland` 那个 slot 的 widget **runtimeType 就变了**(`AnInspector` ↔ `ExcludeFocus`)→ `Widget.canUpdate` 判否 → **旧 element 整棵卸载、新的从零 inflate**。开、关**两个方向都重挂**。于是:动画刚起步的那一帧,一棵重子树被拆掉重建,其内部 provider 重新订阅/取数 → **骨架闪一下**(闪烁)+ 一帧内 inflate 上百个 element(卡顿)。**左岛(:636-676)对 `widget.child` 没有任何条件包装**,所以纯粹是个宽度动画——丝滑。

**做法(零成本)**:这三个 widget 本来就都带布尔参数——`ExcludeFocus(excluding:)` / `ExcludeSemantics(excluding:)` / `IgnorePointer(ignoring:)`。改成**恒定挂三层、只翻布尔**:类型与位置不变 → 零重挂,语义完全等价。

### 病灶②:右岛从未拿到左岛那套保活栈(S3 只做了左岛)

`app/app_shell.dart:342-350` 的 inspector 内容是**一条四路三元链**(`LibraryInspector` / `StagePanel` / `SchedulerRunInspector` / `RunTerminal`)——**切海洋即换类型即拆树重建**。而左岛早在 S3 就收进了 `_RailStack`(`AnLazyIndexedStack`,各 rail 首访才建、建后常驻折叠、切海洋零重建零骨架)。**右岛缺的正是这个孪生件。**

**做法**:右岛内容改走 `AnLazyIndexedStack`(四槽,与 `_OceanStack`/`_RailStack` 同槽序),让切海洋不再拆 inspector。

### 病灶③:全收起时销毁子树 + CR-1a 的 layout 期挂载

`t == 0 → const SizedBox.shrink()`(两岛皆然)会销毁子树,重开即从零重建;右岛**开合极频繁**(每次选中/取消、侧幕自动揭示),左岛几乎不收,所以只有右岛痛。叠加 **CR-1a**(整个 app 建在壳的 `LayoutBuilder` 里 → 这些重建全发生在 layout 期),卡顿被进一步放大。

**做法**:①②修完后重估——若仍有可感成本,再议「关闭时保留零宽而不销毁」(需权衡四个 inspector 常驻的订阅成本)。CR-1a 治本后本项大概率自动消解,故**排在 CR-1 之后**。

### 病灶④(0723 真机截帧实证):**S11 冻结闸靠"套/摘包装"实现 → 海洋子树被重建两次,阅读位置整个飞掉**

用户报「右岛开合时中间海洋突然跳动两下,非常明显」。**AI 已在用户机器上截帧确证**(窄窗、海洋宽度正在冻结闸触发区):

| 动作 | 帧 | 所见 |
|---|---|---|
| **关闭右岛** | 点击前 | 停在对话末尾(「三件事全部搞定」+ composer) |
| | 动画中 | **画面跳到对话很靠前处**(「Hello! I'm Anselm…」),海洋已按终态宽排版、被滑出的岛裁边 |
| | 落定后 | **又跳回末尾** |
| **开启右岛** | 动画中 | 正文区**几乎全白**,右缘可见岛行半渲染碎片 |
| | 落定后 | 恢复正常 |

**根因**(`core/ui/an_shell.dart:256-273`):
```dart
if (freeze) { oceanHost = ClipRect(child: OverflowBox(..., child: oceanHost)); }
```
**与病灶①同一种病**:包装层一加一减 → 该 slot 的 widget runtimeType 变化 → `Widget.canUpdate` 判否 → **整棵海洋子树卸载重建**。闸开一次、闸闭一次 = **重建两次 = 跳两下**。而 chat transcript 是**变高条目 + 像素滚动偏移**,重建并按新宽重排后,同一偏移量指向的已是完全不同的消息 → 阅读位置飞掉(帧证如上)。

**加重项**:`_setAnimating`(:184-190)走 `addPostFrameCallback`,**闸永远晚一帧开、晚一帧关**。原注释断言「末帧解冻时 Expanded 宽=钉宽,零跳变」——该前提被这一帧延迟破坏,首帧未冻、末帧已解,两端都露。

**用户 0723 追加观察 = 决定性佐证:「只有窗口化模式有,全屏没有」。**
闸的条件是 `targetOceanW < _reflowFloor || prevOceanW < _reflowFloor`,而 `_reflowFloor = AnSize.content(720) + AnInset.pageX(24)×2 =` **768**。海洋宽 = 窗宽 − shellPad×2(16) − (左岛 320 + gap 8) − (右岛 320 + gap 8);默认宽下 **窗宽 ≳ 1360 时海洋 > 768 → 闸根本不开 → 不跳**;窗口化(用户截图那种窄窗)海洋仅 ~460 → **闸必开 → 跳两下**。**现象与阈值逐字吻合,病灶④ 确证。**

**而这正是最刺的地方**:S11 的冻结闸是**专为窄窗开合更顺滑**而建的,如今它是**窄窗下抖动的唯一成因**——修补物本身成了病灶。

> **⚠️ 验收陷阱(务必写进验收步骤)**:此 bug **全屏下不复现**。若在全屏验收会看到"一切正常"并误判已修。**验收必须在窗口化、且窗宽 < ~1360(海洋 < 768)的条件下做**,左右岛开合各验一遍。

**做法**:
1. **包装层恒挂、只改参数**(与病灶①同一味药):`ClipRect`+`OverflowBox` 始终在树上,非冻结时取自然宽/不裁;或自造一个类型稳定的 `_FreezeBox`,冻结与否只是参数。类型不变 → 零重建。
2. **`freeze` 同帧同步算出**:把两个岛的 `AnimationController` 提到 `AnShell` 持有,`freeze` 在同一次 build 里派生,**删掉 post-frame + setState 这条兜圈子的路**(它本身也是 CR-1 那类"帧内调度"的一员)。
3. **跨重排保住锚点**:即便零重建,宽度变化仍会 re-shape 文本、改变内容总高;让冻结进/出时 transcript 按**锚点消息**重新定位(W6 的 re-anchor 机制现成,不手搓)。
4. 与 **CR-1a** 合并考虑:壳的 LayoutBuilder 拿掉后,这段几何计算本就要重写,两件事在同一个文件、同一次施工里一起做最省。

**验收**:右岛开/关/切海洋三动作真机逐帧核对(无骨架闪、无掉帧、**阅读位置纹丝不动**);左岛开合同样核对;性能预算套件加一条右岛开合场景;`make -C frontend quick` 绿。

## §5.10 TS 批 · 全局文本选择(0723 用户提:「Claude Code 里能划选复制,我们完全没有」)

> 调研已完成(联网,Flutter 3.44 时点,附出处)。**结论:桌面端不需要「进入选择模式」那类移动端折中——桌面上「点击」与「拖拽」天然可分。**但我们有一条**结构性堵死**必须先拆。

### 前置:两条指向本仓库的红线

**红线①(致命,一行):`AnScrollBehavior` 把鼠标塞进了 `dragDevices`。**
`core/ui/an_scroll_behavior.dart:27-33` 覆写 `dragDevices` 加入 `PointerDeviceKind.mouse`(注释写「开鼠标拖滚」)。Flutter 官方 breaking-change 文档对此明文:默认集合**故意不含 mouse**,正是为了让滚动容器里的文字可选;加入 mouse「will make it difficult or impossible to select text in scrollable containers and is **not recommended**」。
**⇒ 只要这行还在,任何 SelectionArea 在 23 处滚动容器里都形同虚设**——鼠标拖拽会去滚动而非划选。**必须先删 mouse**(触控板/触摸保留)。这也解释了为什么当初 run_terminal 那处 SelectionArea 写对了却没人觉得"能用"。

**红线②:`SelectionArea` 必须是可点击 widget 的祖先,反过来 onTap 永不触发。**
Flutter 团队在 issue #141151 明确:手势竞技场里**更深者赢**,`SelectionArea` 若在内层会赢走 tap。我们的 `AnRow` 整行可点(`AnInteractive`),故拓扑只有一种合法解:`SelectionArea(child: 可点击行)`。

**已就绪的一项**:选中高亮色**已经设过**(`core/design/theme.dart:59-61` `textSelectionTheme.selectionColor: c.selection`),不必再补(否则是默认 50% 灰)。

### 拓扑(写死)

`SelectionArea` **只出现两处**:**中心海洋内容根** + **右岛内容根**。理由是硬的,非审美:
- `Cmd+A` 的语义 = 全选**本 region**。全局一个 region 会把 rail 菜单文字、按钮文案、面包屑一起复制进剪贴板。
- 父子 region 选区天然互不越界,不会出现「从右岛拖到中心正文」这种无意义连选。
- 注册的 Selectable 越少,拖拽逐帧分发与增删排序越便宜。
- 失焦即清选区——多 region 才有「点右岛,中心选区消失」这种直觉行为。

左岛 rail、顶带、岛间 grip **一律在 SelectionArea 之外**(grip 尤其:放外面连手势竞技场都不用进)。
**不得**放在 `MaterialApp.builder` 之上——`SelectableRegion` 断言要求 `Overlay` 祖先。

### 排除清单(做进 UI kit 原语内部,不靠调用方自觉)

`SelectionContainer.disabled` 一石二鸟:子树既不可选、也不挂 I-beam 光标(`Text` 检测到 registrar 为 null 即退回裸 `RichText`)。清单:
- `An*` 按钮 / chip / tab / tooltip / badge / 快捷键提示
- 左岛 rail 全部行(导航型,同 VS Code 侧栏 / Finder 列表惯例)
- 顶带即时消息舞台、通知铃托盘行
- 时间戳 / 计数 / 状态灯等装饰性元数据(进剪贴板只会污染)
- composer / 搜索框 / 一切 `EditableText`
- **`AnCodeEditor`(已自带 `SelectableText`)与 super_editor**——**用 `disabled` 而非嵌套 region**:嵌套只隔离选区、不解决手势竞争,super_editor 有自己整套 `DocumentSelection`,两套系统会同抢 pan。

### 必补的四件事

1. **焦点**:行的 `onTap` 赢走 tap 后,region 的 `_startNewMouseSelectionGesture` 不触发 → **`Cmd+A`/`Cmd+C` 静默失效**。须在行 onTap 里显式 `requestFocus` region 的 focusNode(壳层持有)。
2. **光标**:必须整行可点又可选处,用 `DefaultSelectionStyle(mouseCursor: SystemMouseCursors.click)` 修 I-beam;纯导航行直接 `disabled`。
3. **「复制全文」不能靠选区**:懒加载列表里 `Cmd+A` **只覆盖已构建项**(框架级限制,issue #153478)。故 CH-a 的「复制单条消息」与将来的「复制整段」**必须走数据源**(从 model 取文本),这与 §4 CH-a 是同一件事、合并施工。
4. **流式与选择互斥**:用 `SelectableRegionSelectionStatusScope`(Flutter 3.29+),状态为 `changing` 时**暂停 transcript 自动贴底与非必要重建**——否则 SSE 流式更新会把用户正在拖的选区打断。**这条对我们价值最大。**

### 禁止事项

- **禁** `InkWell(child: SelectionArea(...))`(红线②)——加 review 规则/守卫测试。
- **禁** 在 SelectionArea 内的行上用 `onDoubleTap`——桌面双击已被「选词」占用(三击=选段)。
- **禁** 往 `dragDevices` 加 mouse(红线①)——加守卫测试钉死。
- **不抄**「长按/修饰键进入选择模式」——那是移动端补丁(Zulip 官方客户端为此卡了三年半,卡点是长按被 action sheet 占用);桌面无此困境。

### 版本风险(需拍板)

`mise.toml` 钉 **Flutter 3.41.9**;而 **3.44** 才修掉 `Fix line breaks being lost when copying after selection gesture in SelectableRegion`——**即 3.41.9 上跨行复制会把换行粘成一行**。选项:①升到 3.44(顺带拿到 3.41→3.44 的其他选择修复)②接受该缺陷 ③自造复制命令绕开(第 3 条本就要做,可覆盖大部分场景)。**列 open question。**

### 其他注意

- **`RichText` 静默不可选**:必须手传 `selectionRegistrar: SelectionContainer.maybeOf(context)` + `selectionColor`(缺一即断言)。施工时核对 `AnMarkdown`/`AnStreamingMarkdown`/高亮器是否走裸 `RichText`。
- **右键菜单**:默认桌面已只有 Copy + Select all,且划选后**不弹 toolbar**(桌面惯例,框架已正确)。要精简成只留复制,用 `state.contextMenuButtonItems.where(type == copy)` **过滤框架给的项**(自带正确 onPressed + i18n),空列表返回 `SizedBox.shrink()`;追加自定义项(如"复制为 Markdown")须先 `ContextMenuController.removeAny()`。
- **web demo**:`kIsWeb` 下需 `BrowserContextMenu.disableContextMenu()`,否则浏览器原生菜单盖住。

**验收**:①删 mouse 后 23 处滚动容器手感回归(触控板滚动不受影响)②中心/右岛各自划选+`Cmd+A`+`Cmd+C`③可点击行 onTap 仍触发、光标正确④流式中拖选不被打断⑤守卫测试:`dragDevices` 无 mouse、chrome 原语子树 registrar 为 null、`WidgetTester.dragFrom` 跨多个 Text 划选断言拼接文本、拖拽起点落在 padding/disabled/空白三例(历史断言点)。

## §5.11 VT 批 · 实体版本页改全宽手风琴(0723 用户提方案)

**问题**:`version_tab.dart:68-79` 是 `Row(Expanded(flex:2, 列表) | s16 | Expanded(flex:3, AnVersionDiff))`——在本就不宽的内容列里再对切一刀,diff 只剩 ~60% 宽,**代码横向被砍**(用户截图:`min(times or 1, 10) * random.r` 后半截没了)。

**用户方案(0723 原话复述)**:①学 Scheduler 运行旗舰的语法 ②版本一条一行、占满整宽、信息给足 ③点击=同样的灰色选中块,**小点点变箭头**,可展开 ④在被选中行**下面**就地展开代码卡、走标准动效 ⑤卡片**只显 diff 的行**、不是全文 ⑥再给一个按钮可「展开全部」→ 卡片变完整代码。

**Scheduler 运行旗舰的可学之处**(`scheduler_run.dart:29-47` 自述):**整页纵向堆叠的全宽区 × 一个共享选区 × 深证据一键进右岛,从不左右对切**。版本页违反的正是这条。

### 现成件(直接组装,勿重造)

| 要的效果 | 已有原语 |
|---|---|
| 点变箭头 / 选中灰块 / hover 揭示 | **`AnRow(collapsible: true)`**——文档明写「collapsible 行 hover 换 chevron、open 转 90°」,一个参数的事 |
| 行内展开 + 标准动效 + 展开态粘性 | **侧幕的粘性手风琴**文法(G7/G12 刚立法:展开集外置于 widget、行身份单源),直接搬 |
| 「展开全部 (N 行)」按钮 | **`AnFadeCollapse`**(`expandLabel: d.codeToggle.expand(n:)`),`function_overview.dart:75-89` 已在用 |
| diff 渲染 + bar(copy/wrap/+N −N) | **`AnVersionDiff`** |

### 真正要新建的三件

1. **`AnVersionDiff` 的「只显变更块」模式(主要工作量)**:今天它渲**整段文本的完整 unified diff**,无 hunk 概念。要做:变更行 + N 行上下文 + 中间「… 省略 N 行」分隔(可点展开该段)。上下文行数取值施工时定(业界常用 3)。
2. **虚拟化**:`AnVersionDiff` 自述「**no virtualization + per-row IntrinsicWidth —— targets SHORT single fields**」;而本例 +102 行、「展开全部」即整个文件。S13 给 `AnCodeEditor` 做过虚拟化,diff **没有**——展开全部会踩墙。
3. **横向可读性**:变全宽只解决一半,长行仍横向溢出。diff bar 本就有 wrap 开关——**本场景默认开 wrap**(与全宽配合才真读得完)。

### 已拍板(0723 用户)

- **绿点被 chevron 抢就抢——尊重原语**,不为它跟 `AnRow` 较劲。活动版本标记自然走 trail(chip),lead 位归 chevron。
- **行上信息量**:版本号 + 时间 + 变更摘要 + **+N −N 计数** + 活动版本 chip。
- **行尾加 ⋯ 菜单**(hover 揭示,与会话 rail 的 ⋯ 同一文法):收纳「设为活跃版本」「展开 diff」等每版本动作——把今天孤零零挂在选中行 trailing 的按钮收编进统一出口。

### ⋯ 菜单的动作:两条已有、一条要立法

| 动作 | 后端 | 处置 |
|---|---|---|
| **设为活跃版本** | ✅ **已有**——`POST {id}:revert`(`api.md:144`,前端 `entity_repository.dart:219` 已封装,`version_list_provider.dart:74 setActive` 已在用) | 从 `version_tab.dart:126-146` 的 trailing 按钮**搬进 ⋯ 菜单**,零后端改动 |
| **展开 diff / 展开全部** | 纯前端 | 与行内展开同一状态,菜单项只是第二入口 |
| **删除版本** | ❌ **后端完全没有**(api.md 版本域只有 GET;database.md 无删除路径) | **需要一次宪法裁决,见下** |

**「删除版本」的宪法问题(必须用户拍板,AI 不擅自决定)**:
1. **D1 归属存疑**:版本表是实体的**变更史**,性质接近「Log 表」(D1:严禁逻辑删除,物理删只有两个立法过的例外)。若要删,须先判定它是业务表(软删)还是 Log 表(则需在 `database.md` 立第三个物理删例外)。
2. **删了会断链**:v3 的 diff 是**对 v2 算**的;删掉 v2 后 v3 的 diff 失去参照。是改为对 v1 算(伪造历史)、还是标注「参照版本已删」(诚实但难看)?
3. **`:revert` 目标消失**:活动指针与「回滚到 vN」都依赖版本在场。
4. **用户真实痛点存疑**:本批起因是「看不完整」,不是「版本太多要清理」。

**AI 建议**:**本批不做删除版本**,先落「设为活跃 + 展开 diff」两项(零后端);删除单列为一次独立的后端裁决(要做的话,倾向软删 + 保留 diff 链参照 + 活动版本禁删)。**待用户拍板。**

### 性能墙的解法(用户 0723 明令「你就解决这个问题」)

**先厘清一个易错前提**:S13 给 `AnCodeEditor` 的解法**不是虚拟化,是硬顶截断**——`AnCap.codeLines = 3000` 之上渲头部 + 诚实截断注记(`an_code_editor.dart:352-368`)。原因是它整段代码是**一个 `RenderParagraph`**,Flutter 层面无法虚拟化。

**但 `AnVersionDiff` 结构不同,它真的可以虚拟化**:它是 `for (final r in rows) _row(...)` —— **每行一个 widget**(`an_version_diff.dart:159-163`),不是单个 RenderParagraph。三步:

1. **纵向虚拟化**:行列表改 sliver。非 wrap 态每行等高 → 用 `SliverFixedExtentList`(最便宜的一档);wrap 态行高不定 → `SliverList`。附带红利:`highlightCode` 从「全量高亮」变成**只高亮可见行**。
2. **干掉 per-row `IntrinsicWidth`**(`:182`):它是为了让所有行共享最宽宽度以便整体横滚,但**逐行两遍布局**、且与虚拟化天然冲突(builder 不知道未建行的宽度)。代码是**等宽字体** → 最宽宽度 = 最长行字符数 × 字符宽,用现成的 `core/ui/text_measure.dart` 一次算出,喂给所有行。**不手搓、不逐行测量。**
3. **diff 算法的天花板**:`lineDiff` 是 **LCS,有 DP 矩阵**(`code_diff.dart:52-58`),已有 `lineDiffMaxCells` 单元格上限兜底(超限降级)。虚拟化只解决渲染、**解决不了 O(m×n) 的计算**——须实测大文件下的降级点是否合理,必要时议 Myers。**先测再改,不预先优化。**

**验收补充**:3000 行文件「展开全部」滚动的 frame timing 入性能预算套件;wrap 开/关两态各测一遍;超长单行(无空格 5000 字符)不卡死。

**验收**:窄窗下代码不再横向被砍;逐行展开/收起动效与侧幕一致;展开集跨滚动虚拟化保持(粘性);「展开全部」后长文件不掉帧(带 profile);五电池(空/单版本/超长行/百版本/极端 diff);真机截图。

## §5.12 EA 批 · 实体 rail 每行 ⋯ 动作菜单(0723 用户提)

> 用户:「实体这些,每个实体右侧要加 ⋯ 功能,就像其他的一样,里面放对应的很多快捷功能。例如删除、激活什么的,**根据每个自己来定**。」

**现状**:`entity_rail.dart` 每行**零动作**(第 120 行那个 `_menu` 是 rail 自己的排序/显示菜单,不是行菜单)。而会话 rail 早有成熟的行内 ⋯ 文法(`conversation_rail.dart:161-190`:重命名/置顶/归档/删除,hover 揭示,delete 为 danger 项)——**直接复用,不重造**。

### 发现:后端能力早已齐备,前端从未接线

后端逐 kind 的动作端点(`api.md`)与前端 `entity_repository.dart` 的封装面一对照,缺口很大:

| 实体 | 后端已有动作 | 前端封装 |
|---|---|---|
| 函数 | `:run` `:revert` `:edit` `:iterate` · DELETE | run ✅ revert ✅ · **iterate ❌ delete ❌** |
| 处理器 | `:call` **`:restart`** `:revert` `:edit` `:iterate` · DELETE | call ✅ revert ✅ · **restart ❌ iterate ❌ delete ❌** |
| 智能体 | `:invoke` `:revert` `:edit` `:iterate` · DELETE | invoke ✅ revert ✅ · **iterate ❌ delete ❌** |
| 工作流 | `:trigger` **`:activate`/`:deactivate`** `:edit` `:revert` `:iterate` · DELETE | trigger ✅ revert ✅ kill ✅ · **activate ❌ iterate ❌ delete ❌** |
| 控制 / 审批 | `:edit` `:revert` `:iterate` · DELETE | revert ✅ · **iterate ❌ delete ❌** |
| 触发器 | **`:pause`/`:resume`** `:iterate` · PATCH/DELETE | **全 ❌** |

**「删除实体」在前端根本没有封装**(全 kind),`:restart`/`:activate`/`:pause`/`:resume` 亦然。本批把这些接线——**纯前端 + repository 封装,零后端改动**。

**顺带解掉一个长期悬案**:`:iterate`(开 AI 编辑对话)的**前端入口**在 hub §3.1 挂了很久的「待用户拍板」——**⋯ 菜单就是它天然的家**。本批一并落地。

### 逐 kind 菜单(草案,施工时定稿)

**共有三项**:打开(导航)· **AI 编辑对话**(`:iterate`)· **删除**(danger,需确认)。**各自特有**:

| 实体 | 特有项 |
|---|---|
| 函数 | 运行…(去详情调试台) |
| 处理器 | 调用方法…(去调试台)· **重启实例**(`:restart`) |
| 智能体 | 调用…(去调试台) |
| 工作流 | 立即运行(`:trigger`)· **上线 / 下线**(`:activate`/`:deactivate`,按当前 lifecycle 二选一)· 打开编辑器 |
| 控制 / 审批 | — |
| 触发器 | **暂停 / 恢复**(`:pause`/`:resume`,按 `paused` 二选一) |

**一条诚实律**:**需要输入参数的执行动作不在菜单里直接跑**(`:run`/`:call`/`:invoke` 都要 args)——菜单项负责**导航到详情页的调试台**,绝不盲跑。无参动作(restart/activate/deactivate/pause/resume/delete/iterate)才就地执行。

### 施工要点

- 复用 `conversation_rail.dart` 的 ⋯ 文法(hover 揭示 + `AnMenuItem` + danger 项 + 乐观更新不等 SSE 回声)。
- **删除的引用守卫**:实体间有 relation 边(如函数被工作流引用)。后端删除时是否挡、返什么码——**施工前读码核实**,并如实呈现(参照 api-key 的 `API_KEY_IN_USE` 先例),绝不静默失败。
- lead 位状态点(蓝=运行中 / 绿=上线 / 灰=下线)**不动**——rail 行非 collapsible,与 VT 批的 chevron 之争无关。
- 触发器行的 `paused` 已在后端 list 返回,菜单据它渲「暂停」或「恢复」二选一,不并列。

**验收**:七种 kind 各自菜单真机核对;删除走确认 + 引用冲突诚实报错;工作流上线/下线与 rail 状态点联动;`:iterate` 开出对话并导航;i18n 新键;五电池;`make -C frontend quick` 绿。

## §5.13 LI 批 · Library「新建页面」旁的下载钮不可解(0723 用户提)

> 用户:「Library 里,新建页面为什么有一个下载的按钮,打开是这个?这是什么东西?」

**它是什么**(功能本身是完整的、不是遗留垃圾):**从来源安装 Skill**(WRK-076 F2)。粘一个 **GitHub 仓库简写 `owner/repo[@ref][#subdir]` / github.com URL / 任意 http(s) tarball 地址** → `POST /skills:inspect-source` 解析出仓库里的 skill 候选 → 每个候选**把 `allowed-tools` 前置亮出来**(信任门从挑选步就开始)→ 勾选 → `POST /skills:install` 落盘(带 provenance sidecar:来源 / 装机时间 / 文件 sha256 基线 / `toolsApproved=false` 起步)。

**为什么用户看不懂——三条,都成立**:

1. **入口挂错地方**:按钮在 `library_rail.dart:96-103` 的 **`newRowActions`**,即**「新建页面」那一行的行尾**。可「新建页面」= 造一个空白本地页,「从来源安装」= **从互联网拉第三方内容落进你的 skills 目录**——两件事毫无关系,却共用一行,用户自然读成"新建页面的附属功能"。
2. **裸图标零可见提示**:`AnButton.iconOnly(AnIcons.download, semanticLabel: ...)`;而 `an_button.dart:120-126` 只把 `semanticLabel` 喂给 `Semantics`,**不渲任何 tooltip**。**用眼睛的人得不到一丝线索**——用户就是这么被迫来问的。
3. **对话框首屏不自我解释**:`skill_install_dialog.dart:117-137` = 标题 + 输入框 + 「解析来源」按钮,**没有一句话说它会做什么、从哪拿、装到哪**。唯一的安全提示 `skillInstallPreauthNote`(「安装后这些工具将请求免确认预授权」)要**等勾选候选之后才出现**——最该前置的话被放到了最后。

**做法**:
- **入口迁到「技能」类型头**——**已由用户 0723 拍板并入 §5.14 的 rail 重构**:顶部不再有「新建页面」行,创建动作下沉到类型头——**文档头 = `+`,技能头 = 这个下载钮**。它是 skill 专属动作,长在 skill 的地盘上才讲得通。
- 补可见提示(kit 已有 `AnTooltip`)。
- 首屏加一句说明 + 把「这会从互联网下载并落盘」与预授权含义**前置**到解析之前。
- 核实 `AnInput.placeholder`(→`hintText`,文案已有:「GitHub 仓库(owner/repo 或 URL)或 tarball 地址」)在真机是否**足够可见**(截图里看不出来;对比度/字号,非确证 bug)。

**顺带一个面上的发现(值得单独衡量)**:全库 **`AnButton.iconOnly` 87 处**,而 `AnTooltip` 的使用点仅 **28 处**——`AnButton` 自身不带 tooltip,意味着**大量纯图标按钮对鼠标用户零提示**。建议本批顺手做一次普查,并考虑**让 `AnButton.iconOnly` 在有 `semanticLabel` 时自动挂 tooltip**(一处地基改动覆盖全部 87 处,胜过逐处包裹——原则 #8「业务层手搓的样板本应由地基提供时强化地基」)。

**验收**:入口在技能组头/⋯ 菜单可发现;hover 有文字提示;首屏读得懂;iconOnly 普查结论入档;`make -C frontend quick` 绿。

## §5.14 LR 批 · 左岛 rail 创建动作下沉 + 搜索文案标准化(0723 用户拍板)

### ① Library rail 重构

**用户拍板**:顶部**只留搜索**,去掉「新建页面」行;创建动作**下沉到类型头**——
- **「文档」头右侧 `+`** → 新建页面
- **「技能」头右侧 = 那个下载钮**(从来源安装 Skill,即 §5.13 的入口迁移)

**物理事实与改动面**:
- 「文档 / 技能」在侧栏模型里是 **typeHead**(`sidebar_flatten.dart` 的 `SidebarNodeKind.typeHead`;group 已是透明容器、0719 起不带头)。
- `_typeHead()`(`an_sidebar_list.dart:486-504`)建的 `AnRow` **没有 `actions:` 槽**——今天只有内置 New 行(`newRowActions`)与逐行(`rowActionsBuilder`)有动作槽。**需给 kit 加 `typeHeadActionsBuilder`**(按 type id 取,镜像已有的 `rowActionsBuilder` 写法),动作走 AnRow 既有的 trail hover 揭示文法。**一处地基改动,四海洋 rail 通用。**
- 内置 New 行:`onNew` 虽可空,但 `_newRow()` 的渲染条件需核实——要支持**「无 New 行」形态**(Library 用),不能只是渲一个不可点的空行。
- 其余三海洋 rail 的 New 行**不动**(本批只改 Library;entities 的类型头将来若要「新建函数」等,地基已就位)。

### ② 搜索文案标准化

**盘点结论:标准其实早已存在,9 处里 7 处已合规**——**「搜索<对象>…」**,省略号用真省略号字符 `…`(U+2026),不是三个点。合规者:`搜索对话…` / `搜索通知…` / `搜索实体…` / `搜索设置…` / `搜索记忆…` / `搜索市场…` / `搜索工具 / 函数 / MCP…`。

**违反的恰好 2 处**(即用户点名的两处):

| 键 | 中文现状 | 英文现状 | 改为 |
|---|---|---|---|
| `library.filter` | `搜索页面` | `Search Page` | `搜索页面…` / `Search pages…` |
| `scheduler.filterPlaceholder` | `搜索…` | `Search…` | `搜索工作流…` / `Search workflows…` |

英文 `Search Page` 另有两处失格:**大写 P**(其余全 sentence case)+ **单数**(其余全复数),一并修。

**根治动作**:把这条标准**写进 design-system 的文案节**(或 GOVERNANCE 文案条),并加一条**机械守卫**——扫 i18n 里 filter/search 类占位键是否形如「搜索<对象>…」/「Search <objects>…」,不合规即红。否则下一个新面板照样会写成「搜索…」。

**验收**:Library rail 顶部只有搜索;两个类型头各自的动作 hover 可见、可点、有 tooltip(接 §5.13);无 New 行形态不留空行;两处文案中英皆改;守卫测试就位;`make -C frontend quick` 绿 + 真机截图。

## §6 open questions(施工前清)

1. ~~施工顺序~~ → **已拍板(0723,用户「都听你的」)**:**①Flutter 升 3.44**(独立一步:改钉值 → `make setup` → 根 `make verify` → 真机冒烟,确认无回归)→ **②CR-1a**(拆壳的 LayoutBuilder;RI 大半 + 海洋跳动 + 偶发崩溃皆挂其下,先拆再量剩余)→ ③CR-1b/CR-2/CR-3 → ④RI(治本后重估余量)→ ⑤TS → ⑥CH-a/b/c → ⑦VT → ⑧EA → ⑨SK → ⑩ES → ⑪WD1/2/3。**理由**:①② 会动到后续多批共用的同一批文件,先做省重复返工;功能批按「见效快→依赖重」排。
2. auto-title 对 fork 对话的接管触发条件(现逻辑是否只看首回合)——施工 CH-b 时读码核对。
3. Go 版本(mise 钉值)≥1.24 则 `os.Root`,否则 EvalSymlinks+前缀——施工 WD1 时核对。
4. 排队时按停止:清不清队列——CH-a 交互稿时定。
5. ~~ES 批 B 类引导文案~~ → **已拍板(0723):一套通用「创建首个版本」**(不逐实体分化)。
6. ~~TS 批 Flutter 版本~~ → **已拍板(0723):升级到 3.44**(`mise.toml` 改钉值),顺带拿到 3.41→3.44 的其余选择相关修复。升级本身独立成一步先做:改钉值 → `make setup` → 根 `make verify` 全绿 → 真机冒烟,确认无回归再进 TS 主体。
8. ~~VT 批「删除版本」是否做~~ → **已拍板(0723):不做。** ⋯ 菜单本批只落「设为活跃版本」(搬 `:revert` 现成件)+「展开 diff」两项,零后端改动。删除版本的三个真问题(D1 归属 / diff 链断裂 / `:revert` 目标消失)未解,**不留半成品、不预埋端点**;将来真要做,单独走一次后端裁决。
7. ~~TS 批「鼠标拖滚」取舍~~ → **已拍板(0723):删掉 `PointerDeviceKind.mouse`**。滚轮/触控板/滚动条/触屏全不受影响,失去的只是"按住左键拖内容"这个**手机习惯**、换回全 app 文字可选。这不是权衡而是**纠错**——Flutter 桌面默认本就不含 mouse 且是刻意设计(官方文档明述理由即"让滚动容器里的文字可选"),当初覆写的注释「the base desktop set omits mouse」把这份刻意读成了疏漏。**同提交把该注释重写成当前事实,别再留误导下一个人的话。**
