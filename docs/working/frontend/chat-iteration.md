---
id: WRK-077
type: working
status: active
owner: "@weilin"
created: 2026-07-23
reviewed: 2026-07-25
review-due: 2026-10-21
audience: [human, ai]
landed-into:
  - CLAUDE.md
  - docs/references/backend/api.md
  - docs/references/backend/database.md
  - docs/references/backend/error-codes.md
  - docs/references/backend/domains/conversation.md
  - docs/references/backend/domains/chat.md
  - docs/references/backend/domains/messages.md
  - docs/references/backend/domains/relation.md
  - docs/references/backend/foundation/loop.md
  - docs/references/backend/foundation/platform-pkgs.md
  - docs/references/frontend/contract.md
  - docs/references/frontend/design-system.md
  - docs/references/frontend/features/entities.md
---

> **施工状态(0725)**:§7 施工序 **⓪→⑯ 全部代码收口**,17 步各自一提交、门禁全绿、文档同提交 1:1 同步。
> **本册尚未归档**,因为**真机验收未做**——它需要 GUI 与完整原生工具链,由用户自己驱动 app 完成。待验清单集中在
> `docs/working/multimodal-agent/ACCEPTANCE-GUIDE.md`;各批记录里凡写「未做/留真机」的都在其中。
> 归档条件:真机验收过一遍且无新工单 → `status: landed` + 移 `docs/archive/`。

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
| ~~`messages.superseded_by` 列~~ **已落地 0725**(记录见下 CH-c) | 空=现行版;retry/编辑重发时旧行写新 msg id。LLM 装配过滤 `superseded_by=''`;REST 三读形态**返全部**(前端翻页需要旧版),新版消息 attrs 带 `retryOf` 供前端组版本组。指针实现允许施工时微调,**语义不变:零删除、旧版永可读** | D 系列登记;非逻辑删除(行仍返、UI 可翻看),合 D1 |
| ~~`POST /conversations/{id}:fork {atMessageId}`~~ **已落地 0725,两处偏离草案见下** | 前缀复制(**含** atMessageId):对话头(system_prompt/attached_documents/model_override/work_dir)+ 前缀窗内全部消息行(含 subagent 行,LLM 装配自然排除)+ blocks(seq 从 1 重排、parent remap、context_role 重置);summary:at 点在水位后 → summary+水位同抄,at 点在水位前 → 不带 summary、水位 0(summary 概括了超出前缀的内容,带走即撒谎);标题「原标题 (fork)」+ auto_titled=false;返 201 新 Conversation。**user 消息「分叉预填」变体是前端糖**:对 user 消息分叉 = 后端 fork 至它的前一条,前端把原句填进新对话 composer | N5 动作后缀;api.md + domains/conversation.md;testend |
| ~~`POST /conversations/{id}:retry {content?, modelOverride?}`~~ **已落地 0725**(记录见下 CH-c) | 仅当末回合已终态,否则 409。无 `content` = 重生成:supersede 末 assistant,入队重跑(不写新 user 回合);有 `content` = 编辑重发:supersede 末 user+assistant 两条,落新 user 回合(保留原附件引用)+ 新 assistant 回合。SSE 走既有帧型(新回合正常 open/delta/close,message attrs 带 `retryOf`),**不加新流不加新帧型**(E1/E2) | N5;api.md;testend |
| ~~`GET /conversations/{id}/workdir`~~ **已落地 0725**(WD1 五字段 + WD2 `branches[]` + WD3 `worktrees[]`,记录见下 WD1 / WD2+WD3 条) | `{path, exists, isGitRepo, branch, dirty, branches[], worktrees[]}`;现算派生投影,无游标(N4 有界投影同类——两个内嵌列表仍属「零参数」形,因为端点依旧不收任何参数) | api.md;N4 登记 |
| block 型 `marker` | CHECK 封闭集加一型(六→七):行内标记块,attrs `{kind:'workdir', from, to}`——驻地中途切换落一条 durable 标记,翻旧对话不迷路(现有 compaction 低语同类呈现)。将来可复用其他 kind | D 系列 CHECK 立法;events.md node.type 不变(marker 随消息读取,不新增 SSE 帧型,施工时核对呈现路径) |
| 系统提示注入 | 挂驻地的对话,每轮系统提示带「工作目录 X · 分支 Y」;subagent 继承(`subagent.go:181` fresh AgentState 处播种) | domains/chat.md |
| 越界写强制闸 | Write/Edit 目标 canonical 路径在驻地子树外 → 无视 LLM 自报 danger,强制走人闸。路径判定不手搓:Go ≥1.24 用 `os.Root`,否则 `EvalSymlinks`+前缀校验(OWASP 共识;Cursor denylist 被绕的教训 → 主防线是根内白区,PathGuard 黑名单继续兜底) | domains/tool 域文档 |

**CH-b 施工记录(0725,施工序⑧ 前半)——两处契约草案与后端现实冲突,已裁决:**

**冲突①:relation 边的动词与方向。** 草案写「另发一条 relation 边(fork→源)」。后端现实是边 kind 为 **CHECK 强制的 4 动词封闭集**(`create/edit/equip/link`,`relations` 表 `CREATE TABLE` 内)。铸第 5 个动词 `fork` 是 ~22 文件改动(整表 `MigrateRebuild` + 3 索引重建 + 前端两个精确集断言硬红 + 推翻 `entitykind.go` 里「四个动词即覆盖全部关系」的立法注释)——那是一次独立的架构决定,不该夹在 CH-b 里。**裁决:用已立法的 `create`**(「源线程产出了本线程的第一版」字面为真;图上渲成「创建」,对 fork 也读得通),并把方向**反转为 源 → 分叉**。
> **方向反转还排掉一个真陷阱**(主会话已核实):`SyncOutgoing` 是 replace-all diff-sync,按**源**的出向侧写会抹掉该对话曾建过的**所有** function/handler/agent 的 `create` 边;改按**分叉的入向侧** `SyncIncoming`,而一个分叉永远只有一个父,故 replace-all 恰好精确、重复 fork 幂等。权威血缘本就在两列里,边只为喂图。

**冲突②:本批零新错误码。** 未知 `atMessageId` 复用 `MESSAGE_NOT_FOUND`(message id 是坐标,与 `?around=` 同一身份锚点 404)、未知对话复用 `CONVERSATION_NOT_FOUND`;其余情形**无物理失败**(空 body 是合法的「从最新处」、无消息的源是合法的纯配置副本、源在生成中也不冲突)。为凑一条码造校验剧场违反设计原则 #6,故 `error-codes.md` **未改**(改了会触发门禁的幽灵登记红)。

**另两处**:`atMessageId` 做成**可选**(缺省=从最新处——左岛 rail 行手上没有 message id,让它先取一个只为说出线程自己的末端是一趟白跑的往返);`work_dir` **未复制**,该列在 `conversations` 表尚不存在(属 WD1 批,按草案指示未加列)。

**未复用 `CreateWithSystemPrompt`**:它只造 title + systemPrompt,而分叉头还要 attachedDocuments / modelOverride / summary / 水位 / 血缘五项,走它是三趟往返 + 一个仍缺的 setter。

**summary 两分支的要害是水位要重定基**,不是照抄:分叉把 block 从 1 重排,逐字带走源的水位数字会藏错行。判定在 `app/chat/fork.go` 的 `forkSummary()`。

**testend 五项(主会话自跑复现全绿)**:前缀窗(含切点/到此为止/空 body/双 404 且不留孤儿头/源不动)· seq 重排 + 嵌套 remap(**先断言夹具够硬**——源里嵌套块 `MIN(seq)≠1`,否则「忘了重排」测不出来)· summary 两分支(切最新处→摘要随行且水位 ≤ 分叉自身 block 数=证明是重定基;切首条→两半都不带,并用 promptdump 证明下轮没喂给模型)· 附件共享(线缆同 `att_` id + 表行数不变 + 内容仍可取)。

**顺带记一条 testend 抖动**(非本批引入):主会话自跑全量 testend 时 `TestMCP_ScriptedServerLifecycle` 报 `progress notification must land in call logs, got ""`;**单独跑 6 秒即过**——是 `-parallel 16` 负载下的时序抖动,与对话 fork 零接触面。留档以免下次有人把它当回归查。

**前端三入口**:①消息级——`turn_actions.dart` 那个原本禁用的占位接通(按角色分「从这里分叉」/「在这条消息之前分叉」);②左岛——会话 rail 的 ⋯ 加「分叉对话」(从最新处);③血缘行——`chat_head.dart` 的 `_ForkLineage` **骑在头部行内、不另起一行**(头部是定高带,叠一行会改所有海洋的带高契约),且**恒为**该行 child(普通线程收成零宽盒),故模型菜单槽位下标从不移动。

**user 预填变体**:切点在**点击时**据活回合列表求得(不作 prop 传——落定行按 id 记忆化,prop 会冻结在首次构建那刻,深跳窗前追加历史会让它过期);原句经**既有** `ChatDrafts` 接缝写进**新**线程的草稿键,`ChatComposer.initState` 抵达时读走。前面什么都没有的 user 回合 → 导航 landing + 写 landing 草稿键(什么都没说过的线程**就是** landing,铸一个空孪生是更差的答案)。

**一处主动修正**:血缘行原想复用 `conversationHeaderProvider(srcId)`,但它无 `retry:` 覆盖 → 源被删后会指数退避**永远轮询 404**。改用吞错返 null、永不重试的 `forkSourceProvider`——分叉刻意活得比父长,「读不到源」是正常稳态。


**CH-c 施工记录(0725,施工序⑧ 后半)——契约逐字落地,四处裁决入档:**

**后端**:新列 `messages.superseded_by`(`ALTER TABLE … ADD COLUMN`、不并进 `CREATE`,照 conversations 分叉血缘两列的先例;**刻意无索引**——唯一读它的谓词搭在既有 `conversation_id` 扫描上、结果集就是一条线程)。装配过滤是 `store/messages/messages.go` 的 `LoadThreadForLLM` 里 `WhereEq("subagent_id","")` **紧接的下一行** `WhereEq("superseded_by","")`——正是工单点名的「第三个同族条件」。唯一写者 `MarkSuperseded` = 单列部分 `Updates`,不碰 content/status/created_at。`:retry` 两分支在 `app/chat/retry.go`;**写序刻意是「先落新行、后 supersede 旧行」**(两步之间失败留下一个**看得见的重复问句**、自我修正;反序失败会从模型视图里删掉一次交流、且什么都不留下)。

**409 判定读的是两处状态**,因为它们答两个不同问题:内存 `IsGenerating()`(此刻是否有回合在跑或在排队槽里)+ **`LoadThread` 末行的 `Status`** 是否属三终态(硬崩溃留下的 `pending`/`streaming` 行不是可叠着重试的东西)。两者都弹既有 `STREAM_IN_PROGRESS`——**本批零新错误码**(一条非终态的尾巴**就是**一个仍在跑的回合;无回合可重试复用 `MESSAGE_NOT_FOUND`,与 `?around=`/`:fork` 同一身份锚点)。故 `error-codes.md` **未改**(改了会触发门禁的幽灵登记红,同 CH-b)。

**裁决①:`modelOverride` 是逐回合、不回写对话头。** 契约只说「可选 = 换模型重试」。它随 `task` 走、在 `processTask` 里胜过 `conv.ModelOverride`:「用别的模型再答一遍」是对**一个回答**的表态,而改线程默认本就有它自己的 `PATCH`。行的 `provider`/`model_id` 溯源随即记下究竟哪个模型产出了这个版本,故版本翻页无需猜。

**裁决②:编辑重发只带原附件、不带 @ 提及快照。** 契约逐字只点名「保留原附件引用」。提及是冻结的**内容**而非引用,而编辑后的文本完全可能已删掉那个 `@`——带走它等于把消息已经不再说的话喂给模型。retry body 也没有 `mentions` 键(契约是 `{content?, modelOverride?}`),故重新解析同样不在桌面上:**一条编辑过的句子就是不提及任何东西**,直到再走一次 Send。若日后要支持,需给 body 加 `mentions`、与 Send 同源。

**裁决③:装配过滤必须补两处同族点,否则有个单向阀式的洞。** ①**contextmgr 的压缩读**——`LoadThreadForLLM` 把被重试掉的回答挡在历史外,可一旦它被折进 `conversation.summary`,内容就**回流**进此后每一次 prompt,而摘要不是后面某个过滤器能收回的话(顺带让 `protectedFrom` 数真回合、不数版本);②**`buildAnchors` 跳过被取代的回合**——transcript 把旧版折进版本组、只渲一行,给某个版本建锚点要么让节选重复(「你说了两遍」)、要么给出一个跳向屏上不存在的气泡的跳转。`SumTokens`(usage)**刻意不过滤**:那些 token 是真花掉的。

**裁决④:`retryOf` 上 SSE,因为旁观客户端别无他法。** 它搭在**既有** `message` 节点的 content 上(assistant 侧 `messageOpenContent.retryOf` / user 回声侧 `messageUserContent.retryOf`,同一个 `retryOfOf(m)` 从 Attrs 读),**不加新流不加新帧型**(E1/E2)。一个**不是发起方**的客户端没有别的办法知道「正在到来的回合是**取代**屏上已有那条、而不是接在它后面」。

**两个必修的隐蔽点**(不修就静默错):①**`WriteFinalize` 整体重写 Attrs**,故 `retryOf` 必须由 `task.retryOf` 在 `processTask` 重新种到 host 的 message 上;`failTurn` 同理改收整个 `task`——一次模型解析失败的重试若丢了指针,那个失败版本会渲成**多出来的一轮**,而用坏模型重试正是读者最需要翻回去的时刻。②**`Fork` 必须把 message id 也预铸并 remap 两个版本指针**:保留源 id 会让分叉的链指进源线程,而**丢掉** `superseded_by` 更糟——它把每条被复制的行重置成「现行」,于是模型拿到同一个问题的**两个**回答(被前缀窗切掉的取代者留下零值,这恰好正确;目标落窗外的 `retryOf` 丢弃而非悬空)。

**testend 五项**(`scenarios/chat_retry_test.go`,主会话自跑全绿):重生成 · 编辑重发 · 非终态 409(且**拒绝必须真的是拒绝**——零行写入、零 supersede 指针;cancel 后同一重试即被接受)· 版本链(三版在线缆上双向可走,**第二次重试必须接在最新版上**——否则链分叉、「基于哪一版」就有两个答案;顺带断言场次条不给被取代的版本建锚点)· **LLM 装配只看到现行版**(promptdump 取**重试之后**那个回合的请求——重试自己的请求早于它自己的内容、什么都证明不了)。

**前端**:`supersededBy` 进 DTO(线缆忠实镜像),但**组版本走 `attrs.retryOf` 这条向后指针链、刻意不走 `supersededBy`**——一份在自己被 supersede **之前**就加载过的旧版副本,它的 `supersededBy` 在本进程里仍读作空(过期),而向后指针链永不过期。纯模型件 `ConversationTranscript.groupVersions` 把链折成 `TurnVersions`(`current` = 链的**最后一环** = 线程后续所基于的那一版);不变量「**每个输入回合恰好出现在一个组里**」由单测钉住,两处降级(前驱未加载→单成员组、指针成环→终止)刻意。

**三处 UI 落点**:①**重试** = 末条 assistant 回合的动作排,做成 `AnMenu`(首行朴素重试,下面一段「换个模型重试」)——**复用 `chatModelMenu`**、给它加了 `leadingEntries` + `includeAuto` 两个可选参;`includeAuto:false` 是诚实所需:逐回合模型**无法清除**线程 override,缺席意为「用线程的」而非「用 workspace 默认」,带着 Auto 行复用会让它对「点它会发生什么」撒谎。②**编辑重发** = 末条 user 回合,`ChatTurn` 保持挂载、只换它的**子**(`UserTurnContent` ↔ `AnInput(multiline)` + 取消/重发),动作排用 `Offstage(offstage:)` 翻参数而非条件包装。③**版本翻页** `‹ 2/2 ›` 在动作排尾,`versionCount ≤ 1` 时整个不渲(一个版本没有可翻的)。

**「后续基于哪一版」的标记** = 显示的版本**不是链的最后一环**时才出现(看现行版时没有什么要声明、故注记缺席;一往回翻就出现并说明)。它在现行版上**占零宽、而非被条件包装**,故翻页绝不重挂翻页器自身。

**两条必须写明的缓存律**(都是 §3.2 记过的那类冻结陷阱的新面孔):①**版本坐标进缓存键**(`turn.id#2/3`)——`2/3` 是这一行渲染内容的一部分,后续某页带进第 4 个版本时,被缓存的行会永远宣称 `2/3`;②**带尾巴动作的行不进缓存**——末条 **user** 回合已落定、又不是末轮,故它**本会**被缓存,于是「编辑重发」会冻在它身上、继续提议替换一个已不是末轮的回合。而 `tailActionable` 里那个 `!hasInFlight` **承重两次**:它诚实(生成中末回合不是可替换的回合、后端会 409),且它是让末条 user 行在回复流式期间**仍可缓存**的原因——没有它,那行会随每个 delta 重建、破掉 BuildSpy 流式性能不变量(实测:正是这条把该门禁弄红了一次)。

**一处主动降级:重试菜单不打勾、不显当前模型名。** 那要多订一次 `conversationHeaderProvider`——正是 CH-b 查明「无 `retry:` 覆盖、失败的读会指数退避永远轮询」的那个 provider。它换来的只是某个模型名旁边一个勾;而菜单首行本就写着「重试」、意为「用这条线程现有的设置」,两种情形下都诚实。

**一条既有测试的改动**:`chat_transcript_test` 的两个宿主加 `modelCapabilitiesProvider` override(新增 `_caps` 常量两项)。理由:动作排现在真的读能力目录,不 override 就打到真 api client、失败,而 Riverpod 默认退避会在树销毁**之后**留下 pending timer——测试 binding 理应判红。与其余每个挂载模型选择器的套件同法(`chat_head_test`/`chat_composer_test`)。另删 i18n 键 `chat.actions.retryComing`(占位 tooltip「CH-c 批将至」现在会撒谎)。

**新增 i18n 键**(en/zh 各 8):`chat.actions.{retry, retryWithModel, retryBusy, editResend, editResendSubmit, versionPrev, versionNext, versionBasedOn}`。

**已知未做**:跨组联动——若读者先把某条 assistant 回答翻到旧版、**再**编辑重发那条 user 问句,该 assistant 组会在新回答流式期间显示新版(「正在生成的那一版恒是你看到的那一版」这条覆盖律),流完后回到读者放它的地方、并带上「后续基于第 N 版」注记。那不是谎、是读者刻意翻过去的位置,故不加跨组耦合去追。



**WD1 施工记录（0725，施工序⑭）——驻地地基，三处与简报措辞的偏离 + 一处主动加固，逐条裁决入档：**

**后端·新列与 CHECK 立法**：`conversations.work_dir` 走 `ALTER TABLE … ADD COLUMN`（**第三次**用这条结果幂等径，照分叉血缘两列的先例；`TEXT NOT NULL DEFAULT ''`，**本批刻意无索引**——唯一读者是当前线程自己的头行，而 WD1.5 要按本列**分组**出 rail，`(workspace_id, work_dir)` 索引到**那时**才挣得回它的钱）。`message_blocks.type` 的 CHECK **六 → 七**加 `'marker'`，SQLite 无法 ALTER CHECK 故走 `db.MigrateRebuild`（**第三例**，前两例是 `trigger_firings.status += 'missed'` 与 `flowrun_nodes.status += 'cancelled'`）。**本表重建有两处特别**：①它装的是**用户说过的话**，拷错不是 bug、是数据丢失；②`superseded_by` 那句 ALTER 落在 **`messages`**、不在 `message_blocks` 上，故本表现行形状**就是**它的 `CREATE`（13 列全内联、无 ALTER 补的列要记）。守卫照 `trigger/rebuild_test.go` 写成**等价性**门禁而非举例：「老安装」夹具从**现行** Schema **派生**（只把 `,'marker'` 拿掉）、随后逐 PRAGMA 断言「升级后的表 == 全新安装的表」，故往 `CREATE` 加一列却忘了重建会在此挂掉——而不是从一个真实数据库里静默删掉那一列。

**后端·ctx 播种走哪条路**：**`reqctx`，不是 `AgentState`**。判据两条，第二条是决定性的：①它是从对话行读来的**逐回合不可变配置**、不是工具改了再读回的可变状态；②**subagent 继承因此免费**——`subagent.Spawn` 的子 ctx 由父回合 ctx 派生，驻地原封不动带过去、**零管线代码**；而子运行**刻意**拿一个全新 `AgentState`（不污染父 `SeenFiles`），若驻地存在那儿会被**静默丢掉**，于是父线程 zoom 在某处、subagent 却开始把相对路径解析到虚空。播种点是 `runner.go processTask` 在**读头行之后**、`loop.Run` **之前**（顺序承重：那一列是真相源，且「中途切换在**下一**回合生效」正是按钮对用户的承诺，故按钮在生成中**不禁用**）。

**后端·三族工具各自改在哪一行**：①**文件工具**——`fspath` 是路径规则的唯一物理执行点，故改的是**它**（新增 `ExpandIn(root, p)`：root 为空时**逐字等于**旧 `Expand`），六个吃路径的工具各改一行调用：`filesystem/{read.go:130, write.go:99, edit.go:117}` + `search/{grep.go:193, glob.go:125, ls.go:106}`。**搜索三件套一并改是刻意的**——让 `Read("src/x.go")` 成立而 `Grep(path:"src")` 不成立，是同一条规则的两种答案；工单只点名 Read/Write/Edit，此处如实记为**一处主动扩大**。②**Bash**——`buildShellCmd` 加 `cmd.Dir = workDir`（`shell/bash.go`，此前该函数注释明写「No Dir is set (no cwd)」）；`workDir` **显式**传参而非在函数里读 ctx，因为后台路径刻意用 `context.Background()`（驻地必须像那个进程一样活过启动它的回合，读一个已死的 ctx 会静默得到 `""`）。③**越界写闸**——`loop/tools.go dispatchWithGate` 的门条件从「自报 dangerous」变成「自报 dangerous **或** `writesOutsideWorkDir`」。

**后端·路径判定最终走 `os.Root`，Go 钉值 `1.25`**（`mise.toml`，`go version` 实测 go1.25.11 darwin/arm64）。**但没有照指示直接用**——先写探针实测了 `os.Root` 的语义，因为若它像 chroot 那样把**绝对**符号链接目标重写到根内解析，它的判词就会与 `os.WriteFile` 真正会跟随的目标分道扬镳、**低报**逃逸。实测（darwin/go1.25）：绝对、相对**与目录**三种指向根外的链接，`Root.Stat` 全报 `path escapes from parent`，即它与真 syscall 一致，可以承重。最终实现是**两段**：先 `filepath.Rel` 挡**兄弟目录**（`/root-evil` vs `/root`——`os.Root` 对它压根无话可说，因为它不在根里；而这正是朴素 `strings.HasPrefix` 会答错的那一格），再自顶向下逐组件 `Root.Stat`（**Stat 而非 Lstat**：Write/Edit 会**跟随**末段链接，故指向根外的末段是真逃逸），首个 `ErrNotExist` 即止步（不存在之物之下不可能有链接——这让「全新 Write 的目标还不存在」这一格变得**精确**而非近似）。**fail-closed**：解不开的根、逃逸、权限错一律答「在外面」→ 宁可**多**弹一次人闸。**一处如实记档的保守边界**：`filepath.Rel` 那一步对大小写敏感，故在大小写不敏感的文件系统（macOS/Windows）上，驻地 `/root` 而目标拼作 `/Root/x` 会**多设一次闸**；根给的是 symlink 而目标给真实路径同理。两者各多付一次确认，**都绝不可能让一次外部写悄悄通过**——这个不对称是刻意的，且有对抗测试钉住它保守、永不宽松。

**后端·翻案两处旧立法注释（重述后原文）**：
- `tool/shell/shell.go` 包注释，原「**Two deliberate constraints: NO cwd.** The desktop agent has no project root or "current directory"; Bash never remembers a working directory.（两处刻意约束：① 无 cwd——桌面 agent 无项目根/当前目录……cwd 概念全局废弃）」→ 现「**Two facts about where commands run: The cwd is the CONVERSATION's, and only when the user mounted one.** A thread may carry a work dir (its "residency", `conversations.work_dir`); when it does, Bash sets `cmd.Dir` to it so `ls` and every relative path in the command mean what the user means by "here". Unmounted — the default — nothing is set and the child inherits the backend process's directory… Either way `cd` never carries across calls: **this package still keeps NO state of its own about directories**, it just reads the one the turn's ctx hands it (`reqctx.GetWorkDir`).」——要害是保住那条真正没变的事实（本包不自持目录状态）、同时删尽那条已假的（cwd 概念全局废弃）。
- `pkg/agentstate/agentstate.go` 包注释，原「**cwd is deliberately absent** — the desktop agent has no working directory, so shell adds no cwd slot.（cwd 刻意不设——桌面 agent 无工作目录，shell 不引入 cwd）」→ 现「The conversation's work dir (its "residency") is **deliberately NOT a slot here even though it too spans tools**: it is per-turn IMMUTABLE CONFIG read off the conversation row, not state that tools mutate and read back, so it rides ctx instead (`reqctx.SetWorkDir`). That placement is also what makes **subagent inheritance free** — a sub-run gets a FRESH AgentState on purpose (no SeenFiles pollution), which would have **DROPPED** a residency stored here…」——结论（此处不设槽）不变，理由**整个换掉**：从「不存在这种东西」变成「它存在，但它不属于这里，而且放这里会坏掉继承」。
- **另有第三处旧立法必须一并翻，工单未点名**：`pkg/fspath` 的包注释原写「It is the single physical enforcement point of Anselm's **"always absolute, never a current directory"** rule…there is no cwd to resolve a relative path against」——那句话现在是**条件真**。已整体重述成两条规则（未挂 / 挂了驻地）并明写 `Inside` 是安全谓词。顺带 `ErrNotAbsolute` 的**文案**也改了（「the agent has no working directory」→「no work directory is mounted for this conversation」），故 `error-codes.md` 那一行同提交跟改——**它是被机械契约漂移检测覆盖的**，不改即红。第四处：`search` 包注释同款重述，并明写「驻地从不**收窄**这三个工具」。第五处：`loop/tools.go` 有一句「without adding a **seventh** messages-block type」——marker 现在**就是**第七个，那句话已改成「without adding a block type for it」。

**后端·越界写闸的实现选择（一处设计裁决）**：`loop` 必须保持通用（它分不清 `file_path` 与 `content`），故判定经**可选能力接口** `toolapp.FileWriteTool`（`WriteTarget(argsJSON) string`，返回 args 里**未解析**的原始路径），断言方式与既有 `BuildTool` **完全一致**——那是本仓库已有的「扩展一个工具而不加宽每个工具都必须满足的契约」的做法，故 `Tool` 的**五方法仍是恰五个**（S18 未破）。解析刻意留给调用方，使施加驻地根的地方**恰有一处**（`fspath.ExpandIn`）：两个解析器终会互相不同意，而那份不同意会**静默地**成为一个洞。**两个豁免都被跳过**：`approve_always` 是按 (对话, 工具) 记的，照顾它会把一次「行，那边那个文件」变成此后**任何**位置每次 `Write` 的长期许可——用户回答的是一个**路径**、不是一个工具；skill 的 `allowed-tools` 是在谁都还不知道它要写到**哪里**之前作出的同形承诺。**闸载荷加了恰一个键**：`outsideWorkDir: true`，且**只在越界时出现**，故普通 danger 确认的载荷与每个既有客户端已在解析的形状**逐字节相同**。这一个键是必需的，不是装饰：没有它，用户会为一次模型自称 `safe` 的写面对一个批准框、却无从知道**为什么**——而一个无法自我解释的弹窗只会被闭眼点掉。

**marker 的呈现路径核对结论：`events.md` 的 `node.type` 确实不变，且已在文档里写明为何不变。** 核对方法是读**代码**而非推理：`compaction` 块的唯一写者 `contextmgr.writeAnchor` 走 `CreateMessage`、**不发任何帧**，而 `compaction` 也确实不在 messages 流的 `node.type` 全集里——即「持久块型 7 个、流上块型 5 个」这个差额**在 WD1 之前就已存在**，marker 只是第二个成员。`MarkWorkDirSwitch` 逐字照那条路径写。另外三处按构造成立、已各自核对：①它永不进 prompt——`BlocksToAssistantLLM` 是**类型白名单**，marker 在 switch 里根本没有 case；②它不建场次条锚点——`buildAnchors` 的 switch 同理，故 `api.md` 的 6 种锚点词汇保持封闭；③前端拿得到 attrs——`hydrateBlockContent` 的默认分支是 `{...attrs, content}`，故 `{kind, from, to}` 自然进 `BlockNode.content`。**已在 `events.md` 增一节「不上流的两个块型」**，因为一个读者若发现 7 个块型只有 5 个流类型，必须能分辨「刻意」与「有人忘了」。

**三处与简报措辞的偏离，如实记档**：
1. **未挂态图标 = 电脑，不是「浅灰空文件夹」。** 简报写「未挂（浅灰空文件夹）」，而 §1 拍板 #8 与 §3.1 **两处**都写「电脑图标」并给了理由（**语义诚实：没有工作目录时 agent 的活动范围就是整台机器**）。规格自带的理由胜出：一个空文件夹会暗示「一个恰好什么都没装的容器」，而事实相反——未挂时 agent 能去的地方**更多**、不是更少。
2. **「不存在」态的警示落在菜单第一行 + tooltip，不是按钮的 warn 底色。** `AnButton` 没有 `warn` 变体，而为一个面包屑铸一个是在改设计系统（越权）。故警示态由 tooltip（「工作目录已不存在：X」）+ 菜单首行（「该目录已不存在」）+ 被禁用的「在访达中显示 / 在终端打开」共同承担。
3. **本批不新增「三态」颜色语义，但**「不存在」**只在探测已回答之后才敢声称**——探测在飞时读作「还不知道」。证据的缺席不是警示态：stat 还在路上就闪「目录已不存在」是这个按钮在撒谎。

**一处主动加固（发现了一个真 crash）**：按钮的两态是真正不同的**几何**（纯字形方块 vs 字形+标签），而 `AnButton` 会自己动画它的盒子——`AnimatedContainer` **无法**把固定 24pt 宽插值成无界宽，它直接 assert（`Cannot interpolate between finite constraints and unbounded constraints`）。第一版把「有没有挂」读自**异步投影**，于是每次打开一条已挂线程都会先渲一帧未挂、再形变——**测试里当场崩，真机上也一样**。两处一起修：①**形状改由线程存下来的行决定**（`conversationHeaderProvider`，头部本就 watch 着它），故按钮**第一帧**就知道自己的形状、那一帧的形变整个消失；②真正的挂/退（用户动作，罕见）给 `AnButton` 一个按状态的 `key`，使它在目标形状上**新建**盒子而非补间过去。**这不是 RI 军规所禁的条件包装**：没有任何东西被套上或摘掉，是**一个叶子按钮**改变形状，且只在用户真的挂上或退出目录时改变——理由已写进代码注释。

**一处顺带的地基强化（原则 #8）**：`openWithSystem` / `revealInSystem` 原本住在 `features/library/ui/skill_file_preview.dart` 里。chat 的驻地菜单需要它们，而 **feature 之间不得互相 import**，故它们**上移**到 `core/platform/open_in_system.dart`（并新增 `openInTerminal`），library 改为 import——而不是在 chat 里手抄第二份。三个函数都返 `bool` 而非 `void`：一个静默什么都不做的菜单项（这台 Linux 上没有终端、沙箱环境）比一个承认失败的更糟，故失败会出一条 notice。

**前端·按钮三态与菜单三段的落点**：按钮 = `features/chat/ui/chat_work_dir_button.dart` 的 `ChatWorkDirButton`，挂进 `chat_head.dart` 的头部行**第一个 child**（在名字**之前**——「我们在哪」读在「这是什么」左边，与一条文件路径同序），且它**恒是**第一个 child（自己渲未挂态、不消失），故标题 / 血缘 / 模型三个槽位从不移位。菜单用 `AnMenu` 自己的词汇表达右岛那套三段式文法：**`AnMenuSection(完整路径)` 就是身份头**（唯一放得下整条路径的地方）+ 在访达中显示 / 在终端打开 → 切换/选择 + 退出 → 最近目录 → git 段（**仅当真是仓库**：分支 + 脏/干净，`disabled: true` **只读**；切/建分支归 WD2、worktree 归 WD3，**刻意不摆禁用占位**——那等于承诺一个本批没有的形状）。未挂线程拿到 §3.1 指定的那个**小**菜单（选择 + 最近），因为没有身份可作头、也没有什么可退出。**最近目录**存 `SettingsPrefs` 的 `an.chat.recentWorkDirs`（机器级轴、零后端，JSON 串同 `an.shortcuts`；登记进 `settingsImplicitKeys` 以过三相等门禁），最近在前、去重、封顶 8（超过一小把之后「最近」就不再是回忆、而变成一份用户得去阅读的目录），**当前驻地被滤出列表**（提议切到你已经在的地方是一行什么都不做的项），坏值退化成空而不抛。

**一处状态归属裁决**：**行归 `conversationHeaderProvider`、投影归 `workDirProvider`。** 第一版让 `workDirProvider` 自己 PATCH，结果按钮标签在挂载后**不更新**——因为行的真相在另一个 provider 里，只有 SSE 回声会救它。而本仓的规则是「发起端权威 PATCH 响应即 patch state，**不等回声**」（回声是给**别的**客户端的）。故 `ConversationHeaderController.setWorkDir` 与 `rename`/`setModel` 逐字同法，而 `WorkDirController.set` 退为**唯一编排点**（写行 → 记最近目录 → 按**回显**路径重探投影）。投影的读**刻意不重试**、错误吞成未挂：这是面包屑上的装饰，探测失败必须渲成「无驻地」，绝不渲成错误态，也绝不成为 CH-b 查明的那种指数退避轮询。

**新增 i18n 键（en/zh 各 19）**：`chat.workDir.{buttonNone, buttonMounted, buttonMissing, choose, switch, leave, recent, revealFinder, openTerminal, git, branch, detached, dirty, clean, missing, markMounted, markSwitched, markLeft, openFailed}`（`switch` 是 Dart 关键字，slang 生成 `kSwitch`）。**未删任何既有键。**

**demo fixture**：两条驻地线程 + 脚本化投影，使**三态**在**任何**机器上并排可见而不依赖真文件夹——`cv_resident`（已挂 git 仓库：文件夹 + 名字 + `main` + 脏点，transcript 里含一条真实形状的 `marker` 行）· `cv_resident_gone`（已挂但目录**已消失**：警示态）· 其余每条线程都是未挂的电脑态。夹具新增 `workDirInfos` 按路径脚本化投影（`FixtureChatRepository`）。

**改动的既有测试：零。** 本批没有反转或删除任何既有断言——所有新行为都落在此前不存在的表面上（新列 / 新端点 / 新块型 / 新按钮），而未挂路径的行为**逐字未变**（这一点本身由 testend 的成对断言 + `TestExpandIn_EmptyRootIsExpand` 钉住）。`chat_transcript.dart` 的 `BlockKind` switch 因新增枚举成员而必须加一个 case，那是编译器要求、不是断言改动。

**没做的部分（与原因）**：①**WD2/WD3**（分支切换/新建、`git worktree add`）——工单明令本批不做，故 `WorkDirInfo` 里**不预埋** `branches[]`/`worktrees[]`（不留半成品、不预埋端点，同 §6 的「删除版本」裁决）。〔**已于施工序⑯ 补齐**——两个字段与三个动作的最终形见下 WD2+WD3 条。〕②**WD1.5（CL 批 rail 按驻地分组）**——独立工单，其三个后端小件（`workdir-groups` 投影 / `?workDir=` 过滤 / 两个批量动作）本批**一件未做**；本批只留下它需要的那一列，并在 `database.md` 明写「那时才建 `(workspace_id, work_dir)` 索引」。③**真机截图验收**——`make -C frontend demo` 需要完整原生工具链，不入门禁；夹具已备三态，待真机档一并做（同 §7 施工序①「Flutter 升级的真机冒烟未做」的记法，**别当已验**）。④**驻地按钮的窄窗截断实测**——按钮走 `AnButton` 的标准标签路径，未另测极长目录名下的布局。

---

**WD2 + WD3 施工记录（0725，施工序⑯）——护栏定稿、`make worktree` 约定转录，三处偏离 + 两条诚实边界逐条入档：**

**① 脏区切分支的护栏 = 「直接拒绝」（候选 a）。** 三个候选里选它，理由不是保守而是**它是唯一一个连一行活都丢不了的选项**：git 自己的语义是「能带过去就带、冲突才拒」，于是那个**令人意外**的结局（你的活现在待在一条你以为不是的分支上）落在**成功**分支上、而且是**静默**的——对一个 agent 正在其中干活的驻地，那比一个错误更糟（system prompt 里点出的分支变了、活也跟着搬走了）。候选 (b)「让 git 自己判、把失败翻成人话」被否，因为它**照样保留那个静默成功**，翻译层只美化了失败的一半；候选 (c)「提供 stash」被否，因为承担 stash 的生命周期（谁 pop、冲突怎么办）**就是**§1 拍板 #10 明令不做的那个迷你 git 客户端，而一次静默 stash 正是活消失的方式。落地为 422 `CONVERSATION_WORK_DIR_DIRTY`，**message 自带下一步**：英文 *the working directory has uncommitted changes — commit or stash them, then switch branches*，中文（前端 i18n `chat.workDir.errDirty`）「工作目录有未提交的改动。先提交或贮藏，再切换分支。」；菜单里另有一行更短的 `dirtyBlocksSwitch`「先提交或贮藏改动，再切换分支」，因为**脏时那些分支行根本不摆出来**——一个必定被拒的行比不提供更糟，而一个不给理由的禁用行是个谜。脏态在**服务端此刻现读**、不信客户端上次看到的投影（菜单打开之后用户完全可能刚在自己编辑器里改了文件；一道咨询过期投影的护栏不是护栏）。测试三处钉住它：单测断言拒完之后 **HEAD 未动、那个未跟踪文件还在、`git stash list` 为空**；testend 同样三条 + 断言 message 里含 commit/stash；widget 测断言脏时分支行**不出现**、而换成那一行下一步。

**② 与护栏刻意不对称：`:create-branch` 脏时照走。** `checkout -b` 从**当前 HEAD** 起，故工作树一个字节都不变、冲突**不可能**存在——未提交的活只是变成新分支上的未提交的活。那是最常见的开分支流程（「先动手，然后意识到这该有自己的分支」），给它上门等于守一道什么都不守的护栏（设计原则 #6）。这处不对称读者若无人明说会当它是 bug，故单测**成对**写（`TestSwitchBranch_DirtyIsRefusedWithANextStep` / `TestCreateBranch_DirtyIsAllowedBecauseNothingCanCollide`）、testend 也在同一条场景里连着断言。

**③ 路径与分支约定：逐字转录 `make worktree`，但从「主」工作树量起（一处刻意的推广）。** 根 `Makefile` 的 `worktree` 目标是 `git worktree add ../Anselm-$(NAME)` + 分支 `wt/$(NAME)`（分支已存在则复用它，见下 ⑤），CLAUDE.md「多会话纪律」写「一个并发 AI 会话一个 worktree」。转录成 `gitinfo.WorktreeBranchPrefix = "wt/"` + `WorktreeTarget(top, name) = <top 的父目录>/<top 的 basename>-<name>`：Makefile 里写死 `../Anselm-` 是因为 Anselm **就是**它那个根的名字，一般规则取根的 basename，故对挂在**任何**仓库上的驻地都成立。**唯一推广**是量起点用 `MainToplevel`（`git worktree list` 的第一条，git 明文规定它是主工作树）而不是当前树的 `Toplevel`——否则约定会**嵌套**：在 `Anselm-a` 里开一份会得到 `Anselm-a-b`、再一份 `Anselm-a-b-c`，而纪律要的是主仓库旁边**一排平的**兄弟。单测与 testend 都拿 `git rev-parse --show-toplevel` 自己算期望值，绝不假定测试自己那种拼法胜出（macOS 上 `t.TempDir()` 在 `/var/…` 而 git 报 `/private/var/…`）。

**④ 偏离一：worktree 的「分支已存在」不是失败、是复用。** 工单把「分支已存在」列在 WD3 要诚实上报的失败里；`make worktree` 的实际行为是**复用**那条分支（`make worktree-rm` 的收口语明写「branch `wt/<x>` kept — delete it yourself when merged」，故在保留的分支上重开一份 worktree 正是被写进文档的回头路）。**裁决：跟 Makefile**，复用。真正的那种「分支已被占用」——它已在**别处**被 checkout——只有 git 知道，于是它落在 `CONVERSATION_GIT_FAILED` 并带上 git 自己那句话，而**那句话点出了占着它的目录**，正是下一步（单测 `TestGitFailure_CarriesGitsOwnWords` 在真仓库上造出这个局面）。`CONVERSATION_BRANCH_EXISTS`（409）留给 WD2 的 `:create-branch`。

**⑤ 偏离二：三个动作挂在 `workdir` 子资源上，不是 `{id}:switch-branch`。** 物理原因：Go ServeMux 每个模式只许**一个**处理器，而 `POST /api/v1/conversations/{idAction}` 已被 `ChatHandler` 的 `:cancel`/`:seen`/`:fork`/`:retry` 派发器占了，故一个对话级 `:action` 会被迫从**别人**的文件里 switch。挂子资源后各是自己的字面段、自己的路由（与既有 `POST /{id}/sandbox-envs:reset-all` 同形），且读得更真：它们作用于**驻地**，而 `workdir` 正是驻地的名字。

**⑥ 偏离三：`branches[]` 只取 `refs/heads`，且不设上限。** 「有界」这件事必须**真**成立才敢写进 N4 登记。`refs/remotes` 一条不取，正是这个排除让它有界——`refs/heads` 是这个人自己建的那一集（人类尺度），而一份 fetch 过的远端可以带来上千条。既然真有界，就**不设静默上限**（静默截断是让投影撒谎，而为它加一个 `truncated` 又会把这个零参数端点拖成 trigger-schedule 那种「带真参数的窗」形——两形混登正是 WD1 前言警告过的事）。排序用 `--sort=-committerdate`，因为菜单问的是「我刚在哪干活」，按字母排会把今天那条埋在 `chore/…` 后面。

**⑦ 安全：参数数组、名字校验、目标派生。** 所有 git 调用一律 `exec.CommandContext` 传**参数数组**，**全文件零 shell 字符串拼接**。分支名交给 **git 自己的** `check-ref-format refs/heads/<n>`（原则 #8，不手搓 gitrevisions 规则），另加两条纯 Go 前置：拒空/裸 `@`/**前导 `-`**——一个以 `-` 开头的 ref 对 git 是**合法**的、却会被下一条命令读成**选项**（`CheckRefFormat` 的测试把 `-force`、`--upload-pack=evil`、`a..b`、`x;rm -rf /` 等一并钉住）。worktree 名更严：必须是**单个路径段**（拒 `..`／`/`／`\`／绝对写法／前导 `-`）且 `wt/<name>` 过 `check-ref-format`，因为这个名字**也会**成为一个目录段——而正是这份更严让「目标必须落在仓库兄弟位」成为**可证明**的，而不是一句承诺。端点因此**只收名字、绝不收路径**。

**⑧ 切分支不落 `marker`，WD3 落。** `marker` 的语义是「这段对话**住的地方**变了」；分支变化本就在投影里活着，而用户在自己终端里切分支时同样不会落标记——落了才是两套真相。WD3 真的换了目录，故它落一条，且**复用 WD1 既有的 `marker` 块型**（不新增块型、D1 只追加）:驻地切换走 `Service.Update`，那里是唯一一处会归一化路径、追加 `marker`、并发 `conversation.work_dir` 的地方（E1/E2 不加流不加帧型）。

**⑨ 两条诚实边界（记档而非糊过去）。** ①**WD3 的半状态**:worktree 建成之后，若驻地切换那一步失败（对话在此期间被删等），会留下一份**完好的** worktree 与仍在原处的线程。那是可以停在的诚实半状态——什么都没被毁、用户手动挂上即可——故不做补偿删除（删一份刚建好的 checkout 才是真的丢东西）。②**真机截图验收未做**:`make -C frontend demo` 需要完整原生工具链、不入门禁;demo fixture 已备「脏 + 两条分支 + 一个兄弟 worktree」的形状（故 demo 上就能看见护栏那一行），但**没有**真机截图，与施工序①/⑭ 同一记法，**别当已验**。

**没做的部分（与原因）**:①**commit / push / pull / merge / rebase / reset**——§1 拍板 #10 明令不做迷你 git 客户端，工单也点名本批只做「看分支、切分支、开分支」。②**worktree 的删除（`worktree-rm` 的对应动作）**——工单未列;它是破坏性动作、需要自己的确认框与「未合并分支怎么办」的立法，不该夹在本批里。③**分支的远端语义**（fetch/pull/上游跟踪、`refs/remotes` 的呈现）——它把「有界投影」变成需要游标的集合，且没有一条不涉及网络的读法。④**`marker` 的第二种 kind**（如「分支 → X」）——见 ⑧，语义上不该有。

**零后端项**:复制消息(前端 markdown 拼装,工具卡不进剪贴板)· 排队(前端队列,回合终态后逐条 send)· 最近目录(前端机器级持久化轴)。

---

## §3 前端呈现规范

### 3.1 驻地按钮(面包屑,对话名前)

- **三态**:未挂=电脑图标(语义诚实:活动范围=整台机器)→ 点击弹小菜单「选择工作目录… / 最近目录」;已挂=文件夹图标+目录名(窄窗截断);生成中不禁用(切换下轮生效)。
- **驻地菜单**(三段式文法,右岛同语言):①身份头=完整路径 + 在 Finder 中显示 / 在终端打开;②驻地操作=切换工作目录… / 退出工作目录;③git 段(仅仓库)=当前分支+脏点(WD1)、切换/新建分支(WD2)、**为此对话开一个 worktree**(WD3:`git worktree add` 平行目录 + 驻地自动切过去)。
- **中途切换**:对话流落 `marker` 行内标记「📁 驻地 → X」。
- demo 模式配 fixture 假脸(app/demo 共壳律)。

→ **已施工（0725，施工序⑭ / WD1）。** 按钮三态、菜单三段、最近目录、marker 呈现与四处偏离/加固，全部记在 §2.2 的 WD1 条。

→ **git 段已可操作（0725，施工序⑯ / WD2+WD3）。** 状态两行（WD1）之后是:其余每条本地分支各一行（一键切换）· 「新建分支…」· 「为此对话开一个 worktree…」· 其余 worktree 各一行（移进去 = 一次普通驻地变更、走既有 PATCH）。**脏时分支行被一行「先提交或贮藏改动，再切换分支」顶替**。两个要起名字的动作共用一个模态。护栏语义与全部偏离记在 §2.2 的 WD2/WD3 条。

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

→ **动作排 + 复制已施工(0725,施工序⑦ 前半)。**

新原语 `features/chat/ui/turn_actions.dart`,接进 transcript 两处回合(用户泡下右对齐、助手列下左对齐)。

**复制走数据源、不走选区**(TS 必补③在此兑现):新增 `ConversationTranscript.turnCopyText`,只取 `text` 块——reasoning 是模型在出声地想、tool 调用与结果是机械、progress/compaction 是记账,没一样是「复制这条回复」的意思,而每一样都得让读者手工删掉。用户回合两处都读(live 回声内联 / REST 重载在子块),否则会出现「重载前能复制、重载后静默失效」。

**踩到一处缓存陷阱,值得记**:`_settledRowCache` 按 id 缓存已落定行的 **widget 实例**,而「我是不是末轮」是动作排渲染内容的一部分(末轮恒显、历史 hover 现)。若把 `isLast` 当参数传进被缓存的实例,它会**冻结在建它的那一刻**,于是下一轮到来后留下一排过期的常显图标。解法:**末轮刻意不进缓存**——零代价,因为流式中底部那轮是 open 的、本来也不缓。

**分叉/重试渲成禁用而非隐藏**:动作排的形状在批次之间不再变动,且来找「分叉」的读者会知道它存在且在路上、不会以为没有。tooltip 明说「CH-b 批将至」。

**测试八条**,含一条真端到端(点复制 → 断言**真正落到剪贴板**的文本)与一条**揭示前后同一个 element**(靠不透明度、不靠条件子树——后者会重挂动作排、丢掉「已复制」态,即军规那条)。

→ **重试(可换模型)· 编辑重发 · 版本翻页已施工(0725,施工序⑧ 后半 / CH-c)。** 形态、三处落点、两条缓存律、「基于哪一版」标记的算法与一处主动降级,全部记在 §2.2 的 CH-c 条。**两处与本表措辞的偏离,如实记档**:①动作排图标序保持既有的 复制 · 分叉 · 编辑重发/重试 · 翻页,**未按本表把重试挪到分叉之前**——CH-a 已发布的形状不为措辞顺序而挪(读者已建立肌肉记忆,而两种顺序都读得通);②本表只给 AI 回复配了翻页,施工时**给 user 组也配了**:编辑重发同样产生版本,不给它翻页,读者的旧句子在 UI 里就彻底不可达,而那与「旧版永可回看」直接冲突。翻页只在真有多个版本时出现,故普通对话上两者形状完全一致。

**动作排一节至此收口:§3.2 全部动作已落地**(复制/分叉 见上,重试/编辑重发/翻页 见 §2.2 CH-c 条);§3.4 排队亦已落地(见该节),open question「排队时按停止清不清队列」已在那里裁定。

---

### 3.3 左岛与血缘

- rail ⋯ 菜单加「分叉对话」(=从最新处分叉)。
- 分叉对话头部一行极轻「分叉自 ×××」可点回源头(读 forked_from 列;relation 边喂关系图)。

### 3.4 排队

composer 生成中收 Enter → 入队;输入框上方队列 chip 行(点开改/删),`↑` 取回最后一条;停止按钮=打断(不清队列,清不清施工时给交互稿定)。

→ **已施工(0725,施工序⑦ 后半)。**

新状态件 `state/chat_queue.dart`(`chatQueueProvider` 按对话 family)。composer 四处接入:①生成中 Enter **入队**(原先是直接吞掉——那恰是唯一会惩罚「先打后发」的行为:句子留在框里、几秒后再按一次,却没有任何东西告诉读者第一次为什么没反应)②输入框上方 chip 行(点 chip 取回来改、✕ 丢掉;队列为空时整条带不占位)③空框按 `↑` 取回**最后**一条(取队首会把几条之前的消息递回来,那不是这个手势的意思;框里有字时拒绝——为找回一段未发文字而覆盖另一段是净亏)④管道转空闲即发队首,**一次一条**,故 transcript 顺序保持读者的顺序、绝不并发开轮。

**排空由 send↔stop 那个 `ValueListenableBuilder` 驱动、不挂 listener**:controller 每次重建都会换掉 notifier 实例,在 `initState` 挂的 listener 最终会盯着一个死对象——正是该 builder 上方原有注释警告过的那类 bug。因身处 build 相位,经 `runFrameSafe` 移出。

**§6 open question ④「排队时按停止:清不清队列」——在此裁定:不清。** 「停止」的意思是「停下这个回答」,那是对**在飞那一轮**的表态;读者随后打的消息是他并未撤回的、另外的表态。因为一个无关的回答被截断就把它们扔掉,会销毁读者再也找不回来的输入;而 chip 本就为「确实想扔」备了明确的 ✕。这个不对称是刻意的:只有文字短时「重打一遍」才是便宜的撤销,而我们无从知道它短。

**又一条既有测试钉着旧契约**:`chat_composer_test` 那条「while generating: Enter is swallowed」断言 `controller.text == '想插话'`,即把「按 Enter 后句子留在原处、且不告诉读者为什么」钉住了。已**反转而非删除**(与 TS 的 dragDevices 同法),并在同一条里加上「停止后 chip 仍在」的断言。

**排查出一个看着像产品缺陷、实则是夹具产物的现象,记下免得后人再查一遍**:加了 chip 行后该测试里「点停止」失效。实测原因是 `_settle` 只 pump 3×20ms(本套件**不能**用 `pumpAndSettle`——流式微光永不停),而 chip 让 composer 变高、其形状形变是 spring,于是点击落在盒子长高的**中途**,停止按钮此刻短暂位于父级边界之外(实测:盒底 336,按钮 334–348)。补足 400ms 即过。**产品无缺陷**;但这条规律对「任何让 composer 长高的改动」都成立。

---

## §4 工单拆解(建造批次;每张:门禁全绿 + 文档 1:1 同步 + 真机截图验收)

| 工单 | 范围 | 后端 | 验收要点 |
|---|---|---|---|
| **CH-a 动作排+复制+排队** | 3.2 骨架(复制/分叉入口占位)+ 3.4 排队 | 零 | 五电池(空/超长/流中/队列极值/注入);排队与 409 的竞态测试 |
| **CH-b fork 全套** | `:fork` + 消息级/左岛入口 + 血缘行 + (fork) 标题 | `:fork` 端点 + 两列 + relation 边 + testend(前缀窗/seq 重排/嵌套 remap/summary 两分支/附件共享) | fork 深历史对话真机验;分叉预填变体 |
| **CH-c 重试+编辑重发** ✅ **0725** | 版本翻页 UI + 重试(换模型)+ 编辑重发 | `:retry` + `superseded_by` + 装配过滤 + testend(重生成/编辑重发/非终态 409/版本链) | 翻页回看旧版;继续聊后基于版标记 |
| **WD1 驻地地基** | 按钮三态 + 选/切/退 + 最近目录 + 菜单①②段 + git 只读段 + marker 标记 + demo fixture | `work_dir` 列/PATCH + ctx 播种(**翻案两处旧立法注释**)+ 三族工具定根(Bash cmd.Dir/相对路径/越界写强制闸)+ workdir 端点 v1 + 系统提示注入 + subagent 继承 + `marker` 型立法 + testend | 挂/不挂两态行为;越界写弹闸;相对路径工具卡显示 |
| **WD1.5 rail 驻地分组(CL 批,§5.15)** | chat 左岛四段重组:新对话·搜索 / 置顶 / 驻地组 ×N(组头 ⋯ 批量动作)/ 最近(仅无驻地) | workdir-groups 有界投影 + List `?workDir=` 过滤 + 整组归档/删除两动作 + testend | 分组无漂移;命名防误读(绝不出现「删除目录」);fork/退驻地迁移 |
| ~~**WD2 git 操作**~~ **已完成 0725** | 菜单 git 段:切换/新建分支 | workdir 端点加 branches[] + 操作动作(shell out git,不重造) | 脏区切分支的护栏语义 → **定稿「直接拒绝」**,见 §2.2 WD2/WD3 条① |
| ~~**WD3 worktree**~~ **已完成 0725** | 「为此对话开一个 worktree」 | worktree add + 驻地切换一条龙 | 与 `make worktree` 纪律对齐的路径约定 → **逐字转录 + 一处刻意推广(从主树量起)**,见 §2.2 WD2/WD3 条③ |

**建议施工顺序**:**CR-1 → CR-2**(真机崩溃,插队最前,见 §5.5)→ CH-a → CH-b → CH-c → WD1 → WD2 → WD3(待用户最终确认,§6)。

**文档同步面总表**(#9):database.md(四处列/CHECK)· api.md(**三** :action［`:fork`/`:retry` 已落］+ workdir 端点)· domains/{conversation,chat}.md · events.md(marker 呈现路径)· frontend contract.md(DTO)· features/chat.md(动作排/驻地按钮形态)· CLAUDE.md chat 状态节(战役收口整体重述)。

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
  → **已施工(0725,施工序②)**:`LayoutBuilder` 换 `Builder`,`box.maxWidth` 六处全部换成 build 期一次算出的 `shellWidth`。**前置核对结果**:壳恒为 `MaterialApp.home`(`app/app_shell.dart:328` 与 `an_shell_test.dart` 的 `wrap()` 皆是),故窗宽即权威;S11 冻结闸所需量全部由窗宽推出,26 条既有壳测试(含窄窗/宽窗两条冻结闸测试)零改动全过 → 几何等价。加守卫 `the shell builds its contents OUTSIDE any layout callback`,断言的是**祖先关系**(岛之上不得有 `LayoutBuilder`)而非「壳内哪里都不许有」——`AnButton` 之流叶子原语合法自量,一刀切会误伤(第一版守卫正是这样红的)。
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

→ **已施工(0725,施工序③)。施工中推翻了本节两条判断,如实记下:**

**推翻①:方案①(改局部 `ValueNotifier`)治不到病,已弃。** 它基于两个错误前提:(a)以为 `setCollapsed` 每滚动帧都弄脏——实际 `shell_chrome.dart:121` **首行就去重**,只在跨阈值时改状态;(b)以为病在「弄脏了壳的 build scope」——`shellHeadProvider` 的唯一 watcher 是 `OceanBreadcrumb` 一个小 widget,**根本不重建全壳**。真正的病只有一个:**相位**。而换成 `ValueNotifier` 后,在布局期 notify 同样让消费者 setState-during-build——换了个壳、病一模一样。故只做方案②/③,且落**地基**而非九处手抄(原则 #8):新原语 `core/perf/frame_safe.dart` 的 `runFrameSafe`,只在 `SchedulerPhase.persistentCallbacks`(= build/布局/绘制)延后,且延到**同一帧**的后帧回调。**无条件延后比 bug 本身更糟**——那会给每次滚动回调加一帧延迟;安全相位下它是同步直执行,故包住 `jumpTo` 三处**零行为变化**,纯白拿加固。

**推翻②:不是九处,是十一处——本节那份名单漏了一整类。** 源码级守卫写完立刻抓到 `features/library/ui/an_document_editor.dart` 的第 10 个滚动监听器,顺藤查出 `library_ocean.dart:153 onScroll`(同步 `setCollapsed`)与 `:161 onActive`(同步改 provider)两处真病灶。**漏掉的原因值得记**:副作用**在另一个文件里、隔着一层 widget 回调**,对「找同时含滚动监听器与 `ref.read` 的文件」这种搜法是**隐形的**。修法不是去改那两个消费者,而是堵**发射端那条缝**——`an_document_editor._onScroll` 与 `_emitActiveHeading` 出口各包一道闸,则所有消费者(现有的与将来的)都免疫,且没人需要知道这条规则存在。

**测试(三层,每层都验过「拆掉就红」)**:
- `test/core/perf/frame_safe_test.dart` 三条。第一条是**真回归**——用真 widget 树复现 `setState() or markNeedsBuild() called during build`。**写这条踩了两个假构造**,都记进了注释:(a)只让内容缩短——viewport 对越界滚动走 ballistic 活动、在布局**之后**校正,复现不了;(b)在**首次**布局就 `jumpTo`——控制器尚未 attach,那次跳转根本没发生,测试全程空转。两者都是**绿的**,而绿得毫无意义。必须逼出第二次布局才真红。
- `test/guards/scroll_listener_phase_guard_test.dart` 源码级守卫:扫中 10 个文件,把一处真回归(改回旧写法)照打;附一条「守卫不是空绿」的自证。**它看不见什么也写进了头注释**——只查 `_onScroll` 体,转交同文件私有方法再弄脏会放行。**它是地板,不是证明。**
- 新文件按机制登记进 `convergence_coverage.txt`(pending)。

**CR-2 同批做掉**:`error_boundary.dart` 的 `FlutterError.onError` 内加 `resetErrorCount()`(`kDebugMode` 档)。Flutter 只给一帧内**第一条**错误打完整 dump,而一次布局期违规会在同一帧连环炸出几十条——**恰恰是我们要的诊断被折叠掉**,CR-1 那两份崩溃日志读不出现场就单凭这一条。「dump 落文件」一项**不做**:前端侧无可对齐的崩溃落盘设施(WRK-042 是后端侧),按原则 #8 不新造。

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

→ **已施工(0725,施工序④,主会话亲自——本节有两处「施工时定稿」+ 一条待验隐患,按 §7 分工判据①不外派)。**

**定稿**:高度算在**原语**里、不在宿主里(新增 `AnJsonTree.maxHeight` 自量高模式:按活节点走查出可见行数 × `AnSize.row`,以 cap 封顶,随折叠 `AnimatedSize` 长缩)。理由:**上限**该由宿主说,**高度**不该由宿主算——宿主唯一看得见的量就是顶层键数,而这恰是「一旦有任何展开就不再成立」的那个数。示能复用 `AnEdgeFade`(非 `AnFadeCollapse`——后者是折叠件、不是滚动边缘件),两侧各一条,只在那一侧真有内容时亮。

**「核对同款写法」的结论**:全仓 `AnSize.jsonViewport` 共 8 处,**只有 scheduler 这一处**按折叠态算死高,其余 7 处(chat 工具卡族)给的是固定 240,不是本病。

**待验隐患:已证实为真,同批修掉。** 未构造活 run(贵),而是直接用 widget 探针打它声称的机制:展开一个 depth-1 分支 → 灌一个**内容相同的新 Map** → 子行消失。修法选「按路径保留展开集」而非「深比数据」:后者要为每个 tick 在 650KB 上付一次全量走查,去回答一个我们其实不关心的问题;读者关心的是他自己的展开还在,那就保它,O(已展开节点),且数据真的小改时同样正确。`openDepth`/`showRoot`/`rootLabel` 变更是明确要求重铺形状,刻意不保留(单独一条测试钉住)。

**施工中自己踩了本册的军规,记下**:示能第一版写成 `if (_above || _below) tree = Stack(...)`——这让 `CustomScrollView` 在第一次亮起渐隐时从树的一个位置搬到另一个位置,重挂,抛「TreeSliverController is already associated with another TreeSliver」。这正是 §5.8 RI 那条**禁止条件包装**,**在写下它的同一天咬了一口**。改成 `Stack` + 两带无条件恒在、靠 `AnimatedOpacity` 淡入淡出。`maxHeight` 那层包装**是**条件的(条件是构造参数、活实例上不翻),这处例外写在了代码注释里。

**测试五条**(全在 `an_json_tree_test.dart`):框随活行数长缩 / cap 守住 / 内容相同的新对象不夺展开 / 新 `openDepth` 重铺 / **真宿主形状(`AnSection` 在滚动体内)确实给松高**——最后这条是必要的:紧高度下整个修复是空转的,少了它「原语对了、产品照旧坏着」是可能的(写测试时第一版宿主给的就是紧高,量到的是宿主而非修复)。

**顺带订正一处被施工序①作废的陈述**:`pubspec.yaml` 里 super_editor 的钉值理由写着「dev.41+ 引用本 Flutter 没有的 `TextInputConnection.updateStyle`」——Flutter 3.44 已提供该 API(vendored IME 装饰器已转发)。钉值现在由 ADR 0009 的 presenter 补丁扛着,不再是 SDK 缺口;注释已重述为当前事实。

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

→ **已施工(0725,施工序⑪)。派 Sonnet 5 建、主会话逐行复审 + 跑门禁**(§7 派出协议③④)。

面板四区 → 三区:①模型密钥(受管免费档卡 + llm 类 BYOK 行,受管行锁顶)②场景默认 ③搜索密钥(search 类 BYOK 行 + 默认搜索选择,不再孤悬底部)。`settingsDetailProvider.push` 加 `category` 随行字段(**未**编进 kind),两个添加入口各自把 stage 0 的 logo 网格限到同类;场景默认那个「去加 key」跳转也带上 `llm`,不把搜索厂家掺进模型选择器。诚实补丁两半都落:下拉只收 `testStatus == 'ok'`,**且**其余每行明说「未探测通过,不会进默认」。

**分类规则**(子代理定、复审认可):**「非显式 search」即模型**。理由是 `ProviderMeta.category` 本身就默认 `'llm'`,故目录里查无、或 `providersProvider` 尚在飞行中的 provider 会落进模型段——**不会两段都不显、悄悄消失**。

**复审改了一处**:搜索段原把 `_KeyRow(managed: false)` 写死。今天确实没有受管的搜索厂家,但写死会给将来某个受管厂家发上 S-1 明令它不该有的编辑/删除入口,而在它上线之前不会有任何东西报错。改成与模型段同样从目录推导。

**demo fixture 加了一把 Brave 搜索 key**:该 fixture 自己的契约是「每个设置面板都显有数据态而非空占位」(D-032/033/034),拆段后搜索段需要自己的种子,否则 `make demo` 会显一个真的空区。

**第 5 项(拆文件)没做**——本就写着「可选、不强求」,子代理选择不做以缩小改动面,复审同意:分栏本身已是一次不小的结构改动,再叠一次文件搬家只会让复审更难。

**既有测试改了一条**:`s2_models_keys_test` 里 `(kind: 'editKey', id: boundId)` 这个记录字面量改成三字段。理由是 `SettingsDetail` 现在是三字段记录,两字段字面量运行时形状不同、永远 `==` 不上,会因与该测试真正要验的事(点行→进编辑)无关的理由变红。**不是削弱断言**,是同一语义断言换成新形状。

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

→ **已施工(0725,施工序⑫)。派 Sonnet 5 建、主会话逐行复审 + 跑门禁。`insetEmpty` 已删(零使用者,grep 实证)。**

**用户点名那处的样子**:`function_overview` 的依赖现在是 `AnKv(rows: [AnKvRow.tags(d.card.deps, v.dependencies)])`,**无条件**——`AnKvRow.tags` 空表时自出破折号,于是 `依赖 —` 是一行 32px、与本卡其余五行同文法。顺带消掉一个条件分支(原先 `if (empty) 墓碑 else 标签行` 正是「禁止条件包装」那一类)。

**本节的分类有一处错,子代理查实并纠正**:`workflow_overview` 那处**不是标签字段**,它是 `if (g == null)` —— 图 JSON blob **解析失败**。那是**错误**、不是空值,压成一行 KV 会是范畴错误。已改为 `AnState(kind: error, size: inset)`——仍消掉 `insetEmpty`,但换成对的字形。**故真实构成是 6 个 A 类 + 1 个错误态 + 6 个 B 类 = 13**,总数与本节一致、分类不一致。

**多出一处**:追「零使用者」时发现 `trigger_overview` 也在用 `fieldList`(Fire payload),即第 7 个消费者。trigger 是本节六实体之外的支撑类,同法一并改(否则删不掉 `insetEmpty`)。

**B 类只交付了一半,如实记**:本节要求「引导 + **动作**(创建入口)」。子代理通读 `EntityRepository` 与 UI 后确认——**六个实体今天都没有可达的「创建版本」入口**(function/handler/agent 的版本内容按立法是 AI-only + 只读;control/approval/workflow 也没有创建版本的示能)。按简报的兜底条款,只渲了文案引导(`尚无版本` + `创建一个版本以激活该实体`)、**没有造一个通向空处的假按钮**。**这一点部分推翻了本节 B 类的方案**:那个「创建入口」并不存在,要么另立工单造它,要么承认 B 类的终态就是纯文案引导。

**一处留待真机看观感**:`fieldList` 空表时那一行的标签取了调用方自己的段/卡标题,于是「Inputs」卡头下面跟着一行「Inputs —」——**语法一致但略显重复**。备选是渲一个无标签的裸破折号,但 WRK-070 B12 明确警告过无标签裸行读作神秘词。此处不猜,列为真机观感项。

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

→ **已施工(0725,施工序⑤)。四病灶全部落地,并推翻了本节一条判断。**

**①④ 同一味药**:`ExcludeFocus/ExcludeSemantics/IgnorePointer` 三层恒挂只翻布尔;`ClipRect`+`OverflowBox` 恒挂,冻结只体现在 `clipper`/`minWidth`/`maxWidth` 三个参数上(`_UnclippedRect` 与 `null` 宽——**这套范式房里本来就有**,右岛为放行阴影一直在用 `clipper: fullyOpen ? const _UnclippedRect() : null`,不必新造 `_FreezeBox`)。

**③ 是真的,而且是靠守卫抓出来的**:`t == 0 → SizedBox.shrink()` 销毁子树,守卫量到 inspector 挂载 **2** 次。改 `Offstage(offstage: t == 0)`——保状态、跳布局与绘制、自动退出语义树。本节原写「①②修完后重估、大概率自动消解」,重估结论是**不会自动消解**。

**② 右岛拿到孪生件**:四路三元链 → `_InspectorStack`(`AnLazyIndexedStack` 五槽:library/chat/scheduler/entities/none)。槽判据与原三元链逐条同条件同顺序,故显示哪张脸不变;原先落到 `RunTerminal` 的隐形兜底(settings、无活动的 chat——壳在那里因 `hasSelection` 为假从不揭示)改成一个明说的空槽。chat 那张脸需要 id,而离开 chat 海洋时路由选区立刻变 null,故记住最后一个对话——否则保活在最有状态可丢的那张脸上恰好什么也没买到。

**推翻:本节「加重项」判断有误。** 原写「`_setAnimating` 走 postFrame,闸永远晚一帧开、晚一帧关……首帧未冻、末帧已解,两端都露」。**实测反证**:把同步上膛删掉,S11 全部测试依然绿——因为**翻转那一帧子件的控制器还没走动**,海洋宽度没变、无处 relayout;而在宽度真正开始移动的第一帧,闸已经上膛。晚一帧**下膛**同样无害(多冻一帧在终态宽=最终宽)。同步上膛仍然做了,但它是**把不变量写进代码**、不是修一个可观测缺陷——工单里这条得改口,否则下一个人会以为修掉了一个真 bug。做法 #2 提的「把两个 `AnimationController` 提到壳里」因此**不做**:那是一次侵入式改造,而它要买的东西经实测并不存在。

**做法 #3(跨重排保锚点)未做**——零重建之后是否仍有可感的位置漂移,须真机在窄窗下验(本 bug 全屏不复现,见上面的验收陷阱);未验之前不动 transcript 的滚动锚点。**留作 F 的真机验收项。**

**军规 + 守卫**:「禁止条件包装」已写入 `CLAUDE.md` 前端关键约定与 `design-system.md` 的 AnShell 条目(含正解清单与「`SizedBox.shrink()` 早退同罪」)。守卫是**行为式、非 grep**:`an_shell_test.dart` 的 RI 重挂守卫用一个数 `initState` 次数的探针,来回切两岛后断言海洋与 inspector 各只挂载一次——**任何像素断言都抓不到这一类**(前后布局都对,丢的是身份),而它一次覆盖①③④三张脸。守卫**刻意用窄窗**(1100×800):冻结闸只在海洋 <768 时上膛,宽窗守卫会宣布病灶④已修而它根本没被碰过。

**顺带修一处测试的假绿**:「收起的右岛内容离开语义树」那条原用 `find.bySemanticsLabel`,而它读的是 render object 的 `debugSemantics`——节点被排除后这个值**残留**。它此前能绿,靠的正是我们要消除的那次重挂(render object 是新的、没有残留可读)。已改成走一遍语义树问「此刻屏幕阅读器能否到达」;探针实测:语义树里确实没有(`false`),而旧 finder 仍报 `1`。

### 收口立法(RI 批的根治半):「禁止条件包装」军规 + 机械守卫

本批三处病灶(右岛禁用包装 / 冻结闸 ClipRect+OverflowBox / 另见 CR 各处)是**同一个认知盲区的三次重复**:`cond ? child : Wrapper(child)` 在 Flutter 里 = 换 runtimeType = 整棵子树卸载重建。修完后必须立法,否则半年后出现第四处:
1. **design-system 文案节立军规**:「**状态切换禁用条件包装,一律恒挂包装层、只翻参数**」(`ExcludeFocus.excluding` / `IgnorePointer.ignoring` / `Offstage.offstage` 等本就为此设计);
2. **机械守卫**入 verify:扫 `lib/` 中 `? child : Wrapper(...child...)` / `? Wrapper(...) : child` 形状(三元两臂一裸一包同一子表达式),命中即红;已有正当豁免逐处注释登记。

**验收**:右岛开/关/切海洋三动作真机逐帧核对(无骨架闪、无掉帧、**阅读位置纹丝不动**);左岛开合同样核对;性能预算套件加一条右岛开合场景;军规入 design-system + 守卫入门禁;`make -C frontend quick` 绿。

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

→ **已施工(0725,施工序⑥)。红线、拓扑、焦点、光标、chrome 排除、流式互斥六项落地;两项未做,如实列在末尾。**

**红线①(删 mouse)**:`AnScrollBehavior` 现在**完全不覆写** `dragDevices`。发现一件必须记的事——**既有测试 `an_scroll_behavior_test.dart` 断言了 `contains(PointerDeviceKind.mouse)`**,即套件在把这个缺陷钉住。该断言已**反转而非删除**,好让翻案留在记录里;常驻守卫另立 `test/guards/drag_devices_guard_test.dart`。

**拓扑**:新原语 `AnSelectionRegion`(`core/ui/`),全 app 恰好两个实例,都在壳里:海洋内容根(`_OceanRegion` 的 `Positioned.fill`,故头带/scrim/角控全在域外)与右岛内容根(在惰化三层**之内**,故收起的岛两边都选不到)。左岛 rail、顶带、grip 天然在两域之外——**这一点顺带砍掉了排除清单的一大半**:rail 全部行、通知铃托盘、顶带舞台本就不在任何域内,不需要 `disabled`。

**焦点(必补①)**:域公开自己的 `FocusNode`,`AnInteractive` 在**指针**激活时把焦点交过去。**刻意不接进 `_activate`**(Enter/Space 路径)——在那里搬焦点会把用户从他正在浏览的列表里甩出去。两个方向各有一条测试互为镜像。

**光标(必补②)**:`AnInteractive` 恒挂 `DefaultSelectionStyle`,`mouseCursor` 在可激活时给 click、否则 null(恒挂是「禁止条件包装」的要求)。

**chrome 排除**:`AnInteractive` 新增 `chrome` 开关(缺省 **false=可选**,因为搭在这个基座上的多数面是**内容行**,读者完全有理由想复制),`AnButton`/`AnTabs` 传 true;`AnKeycap` 直接 `disabled`。**`AnCodeEditor` 与 super_editor 门面 `AnEditor` 用 `disabled` 而非嵌套域**——嵌套只隔离选区,两套系统仍在抢同一个 pan 手势。

**流式互斥(必补④,本节自称价值最大的一条)**:`chat_transcript._jumpToBottom` 在 `SelectableRegionSelectionStatusScope` 为 `changing` 时直接返回。没有它,「划选文字」与「看回复流出来」互斥,而那恰是读者最想复制点东西的时刻。若流恰好在拖拽期间结束就停在读者放下的位置——**这是对的结果、不是缺口**。

**测试五条**,含一条**真端到端**:鼠标拖过两个 `Text` → `Cmd+C` → 断言**真正落到剪贴板上的文本**含两行。踩到两个坑,都写进了注释:①`flutter_test` 默认报告**移动**平台,那里复制键是 `Ctrl+C`,不覆写目标平台则 `Cmd+C` 打在空处、测试会「证明」剪贴板坏了;②`debugDefaultTargetPlatformOverride` 必须在**测试体内**还原,`addTearDown` 太晚(不变量检查在它之前)。

**一条诚实边界**:这条划选测试**证明不了红线①**。把 mouse 加回 `dragDevices`,它依然**绿**——单次 `moveTo` 跳跃在手势竞技场里的解算与真实指针逐帧移动不同,我未能构造出复现该失效的 widget 测试。故回归改由「直接断言 mouse 不在其中」来守,因果依据是 Flutter 官方 breaking-change 文档、不是我的测试。**这一点已写进测试注释,免得后人以为它守着那条红线。**

**两项未做**:
- **必补③「复制全文必须走数据源」**——本节自己写明它「与 §4 CH-a 是同一件事、合并施工」,故留到 **CH-a(施工序⑦)**。
- **排除清单的装饰性元数据(时间戳/计数/状态灯)** 未逐处 `disabled`。理由:它们散在各 feature 的行里、不在少数几个原语内,逐处铺开是一次大范围改动;而当前状态下它们被选中只是**污染 `Cmd+A` 的剪贴板内容**、不影响任何交互。**留作真机看过实际观感后再定**(可能反而希望时间戳可复制)。

**上一条 open question 的答案**:「版本风险(需拍板)」中的跨行复制丢换行,已由施工序①升 3.44 解决,无需选项②③。

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

→ **已施工(0725,施工序⑨)。派 Sonnet 5 建、主会话复审 + 跑门禁。逐条对照本节:**

**做到的**:①全宽手风琴(`Row(Expanded|Expanded)` 对切**物理删除**,一版一行 `AnRow(collapsible:true)` + `AnExpandReveal.builder` 就地展开,lead 常驻 chevron、`selected: open`)②行上信息给足(版本号 mono · 时间 · 说明 · 结构摘要 → hint;**+N −N** → trail meta;活动标记 → trail 常驻点;hover ⋯ 菜单)③**hunk 只显变更**(新 `unchangedGaps` 纯函数,上下文 **3**=`diff -U3`/git 默认,省略段可点、单行不折、全无变更不折)④**虚拟化**(行改 sliver:非 wrap `SliverFixedExtentList`[一次量出的行盒]、wrap `SliverList`;`shrinkWrap` 按 LayoutBuilder 真给的高判——装得下贴自身高、高过钳高转惰性;**逐行 `IntrinsicWidth` 物理删除**,横向宽=等宽字符宽×最长渲染行一次算出;LCS 按 (before,after,live) 记忆化,翻 wrap/展 gap 不重跑)⑤**默认开 wrap**(新 `wrap` 参数,与 `AnCodeEditor.wrap` 同契约)⑥「展开全部 (N 行)」逃生行(`onHunksChanged` 受控手,模式住 `VersionListState`,⋯ 菜单是第二入口、同一真相)⑦「设为活跃版本」从 diff 下 footer 钮**搬进 ⋯ 菜单**(零后端改动)。两个开合集按**版本号**记键、外置于 widget(侧幕纪律);打开 tab 即展开最新版本。

**三处与本节措辞不同,逐条给理由:**

**一、活动版本标记落成 trail 的常驻状态点、不是 chip。** 本节拍板写「活动版本标记自然走 trail(chip)」——但 `AnRow` 的 trail 只有三个槽:`meta`(String)、`actions`(**hover 才揭示**)、`trailingDot`(`AnStatus`,常驻)。chip 是 widget,只能进 `actions`,而那会让活动标记在静息态消失(等于没有标记);给 `AnRow` 加一个 chip 槽是改原语,本批禁区明写「新建的只有 AnVersionDiff 的 hunk 模式与虚拟化」。故取 `trailingDot`——**拍板的实质(lead 归 chevron、标记移到 trail、不跟 AnRow 较劲)全部落地**,只是形态是点而非 chip。

**二、`+N −N` 在 provider 取数时按页算一次,不在 build 里算。** 行上要显计数就得跑 LCS;放 build 则每次手风琴 toggle 都替 20 行重跑。落法:`VersionRow.added/removed`(可空)在 `_fetch` 后按页算一次(源相同直接跳过),与 `summary` 同一处、同一「页边界行无值」诚实降级。**null 不渲**,绝不显撒谎的 `+0 −0`。

**三、⑥ 的「按钮」落成卡下整宽逃生行 + ⋯ 菜单项两处,没有动 diff 的 bar。** bar 与 `AnCodeEditor` 同构是 WRK-066 拍板,不为本批加第三枚钮;逃生行走套件既有展开全部文法(`AnFadeCollapse` 开关行 / `AnLedgerList` 逃生行同形)。本节表里「`AnFadeCollapse`」那一格只被借用**文法与 i18n 语气**(`Show all (N lines)`),没有真包一层 `AnFadeCollapse`——它只钳高度、不换内容,物理上做不出「hunk ↔ 整份」。

**`lineDiff` 实测降级点(真跑,非推测)**:`(m+1)(n+1)>4M`≈**2000×2000 行**处翻闸;闸下最坏一档 1998×1998(恰 4,000,000 cell)真跑 LCS **25ms**(1500→18ms / 1000→6ms / 500→2ms),闸上**0ms**(整段替换,全删+全增)。结论:过闸前最坏丢一帧、绝不卡死,**不换 Myers**。附带发现:退化后 3000×3000 是 6002 行**零上下文**——hunk 无可折,**只剩虚拟化**挡在读者与 6002 个 widget 之间(已入五电池测)。

**顺手修的真 bug**:行号列在亚像素差一点点时会把 `18` 折成两行、行高翻倍(等高档下更是直接打破「每行一行」前提)——行号/符号列补 `maxLines:1, softWrap:false`,列宽向上取整。

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

→ **已施工(0725,施工序⑩)。派 Sonnet 5 建、主会话逐行复审 + 核实四条纠正 + 跑门禁。本节被纠正了四处,逐条记:**

**纠正①:上表「处理器 restart ❌」是错的。** `restartHandler` 早在本批之前就已封装(接口 + Live + Fixture 三处都有),只是从未被任何 UI 调用。**主会话核实:diff 里 `restartHandler` 零命中,而 `entity_repository.dart:202/620` 确实早已存在。**

**纠正②:`:iterate` 不是无参动作。** `backend/internal/app/aispawn/aispawn.go:131` 有 `if request == "" { return "", ErrEmptyRequest }`——`{request: string}` 是**必填非空**的首条消息。本节把它列进「无参动作」清单是错的。落法:菜单发一句**固定**开场白(i18n 键,非用户自由输入,照 `:fire` 的 `{manual:true}` 先例),真正的自由诉求交给随后打开的那个对话本身。**这既不是空跑、也不是逼用户先填表单。**

**纠正③(最重要):工作流「立即运行」改为导航,不再就地跑 `:trigger`。** 诚实律的无参白名单本就不含 `:trigger`(payload 可选 ≠ 无参),而更硬的理由是**本项目已有立法**:`ocean_header.dart:51` 明写「动词 CTA 退役(0718 拍板**唯一执行点**:execution lives only in the right-island debugger;两扇 Run 门是两个不同的行为)」。**主会话已核实该注释逐字存在。** 让菜单里的「立即运行」盲跑,等于重开一扇被明确关掉的门。改为导航后与 run/call/invoke 三者同一文法。

**纠正④:「导航去详情调试台」没有那个 tab。** 详情页的 tab 只有 概览/版本/日志(workflow 是运行驾驶舱=**观测**面、无起跑表单);真正能跑的界面是**右岛 `RunTerminal`**,它按 `selectedEntityProvider` 绑定。故「导航」= 选中实体 + 强制展开右岛,复用 `log_tab.dart:138-143` 已有的同一手势,**不是编造的新能力**。

**删除的引用守卫:实际行为与本节假设不同,已查实。** 七个 kind 的 DELETE **从不因入向引用拒绝**——不像 api-key 的 `API_KEY_IN_USE`(那个先例真实存在,主会话已核实)。实体的删除一律软删 → 清边,并在清边前快照被留下悬空引用的依赖方,随后经**异步聚合**的 `relation.dependency_broken` 通知点名「谁挂了个空引用」——好意提醒,**绝不挡删除**。后端也**没有**任何「预览依赖数」的 GET 端点(`CountDependents`/`ListDependents` 只在 `relation.go` 内部用,全 handler 目录零调用),故前端**物理上拿不到**「删了会影响几个东西」的预览。结论:行菜单的删除就是标准确认框 + 通用失败 toast,**没有需要特殊呈现的拒绝码**。本节「引用冲突诚实报错」这条验收项,正确的落地是「诚实地说明它不会冲突」。

**顺带修了三处 fixture 真 bug**:`_controlLogics`/`_approvalForms`/`_triggerEntities` 原先直接赋 `const []`,删除/upsert 会在 const 列表上抛。本批的删除动作会真的踩到它。

**触发器的 PATCH(改名)没做**:本节的菜单定稿从未把改名列进触发器项(只有暂停/恢复),表格那栏的 PATCH 更像 CRUD 覆盖率笔记;实体 rail 目前任何 kind 都没有行内改名(与 conversation rail 不同),不在本批擅自开这个头。

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

→ **本节那条「顺带发现」已单独施工(0725,主会话亲自——它牵动 87 处、不宜外派)。**

`AnButton.iconOnly` 现在**自带 tooltip**(取 `semanticLabel`),一处地基覆盖全部纯图标按钮。**普查结论证实**:改完立刻有 **7 处**手工 `AnTooltip` 包裹变成**双层**、六条既有测试转红——这正是「原语只生不收」之罪的实证,那 7 处已解包(每处的 `message` 与 `semanticLabel` 本就是同一个表达式,解包零信息损失)。守卫 `an_button_test` 三条:iconOnly 有 tooltip / 带 label 的没有 / 手工再包一层会被抓到(断言正是「双层」这一现象)。已写进 `design-system.md` 的 AnButton 条目。

**本节其余三项(入口迁移 / 首屏说明前置 / placeholder 可见性)未做**——它们与 §5.14 的 Library rail 重构同属施工序⑬,尚未施工。

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

→ **已施工(0725,施工序⑬)。派 Sonnet 5 建、主会话逐行复审 + 亲自复验守卫与两条依据 + 跑门禁。**

**地基**:`AnSidebarList` 加 `typeHeadActionsBuilder`(签名逐字镜像 `rowActionsBuilder`,按 `SidebarType.foldKey` 取,动作走 `AnRow` 既有的 hover 揭示尾槽)。**四海洋通用**,本批只改 Library。

**「无 New 行」形态不需要新东西**:本节写着「`_newRow()` 的渲染条件需核实」——核实结论是 `showNew`(默认 true)**本就存在**且是**结构性**门控(`if (widget.showNew) _newRow()`),`false` 时整行不入树。**主会话核实:`showNew` 在本批 diff 里零命中,确系既有能力。** Library 传 `showNew: false` 即可,不必为此新造一个来来去去的包装层(那正是军规禁的)。

**守卫**:`test/guards/search_placeholder_guard_test.dart`。扫描规则按**调用点实际接线的三种命名**(`filter:` / `filterPlaceholder:` / `placeholder:`)选键,合规式 EN `^Search [a-z].+…$` / ZH `^搜索.+…$`,并显式查三个 ASCII 点的假省略号。**主会话亲自复验了非空绿**:把 `library.filter` 改回 `Search Page` → 守卫转红,报错精确到键名与原因;还原即绿。另有一条 **反向 sanity** 钉住 19 个真·非占位的 filter/search 键不被误伤——**过严的守卫和漏掉的守卫一样坏**。**它看不见什么写在头注释里**:两个不合三种命名的真占位键(`settings.mem.searchHint` / `settings.mcp.searchMarket`,今天都合规但无守卫)、只读 i18n 表(硬编码文案它看不见——那由零硬编码律另管)、只判机械形状不判单复数与地道性。

**LI 批首屏自我解释已落**:标题与输入框之间加一句说明,把「经互联网从该来源取回文件、存进你的 skill 库」与「预授权=这些工具此后跳过确认弹窗」**前置到「解析来源」之前**。

**顺带查实一个真缺陷**:该对话框**缺 `Material` 祖先**。`AnInput` 建在 Material 的 `TextField` 上(`an_input.dart:162`,断言 `debugCheckHasMaterial`),而 `anPanelRoute` 是裸 `RawDialogRoute`、不在任何 `Scaffold` 内;经同一路由的姊妹对话框 `skill_tool_picker.dart:274` **早已**带着 `MaterialType.transparency` 正是为此。已按同一先例修。**注**:用户当初那张截图看到的是否正是这次失效(app 装了 `ErrorWidget.builder`,抛错会就地渲报错替身而非崩溃),**无从确证**——但缺陷本身与用户看到什么无关。

**一处小尾巴没清**:`LibraryRailLabels.newLabel` / `SidebarModel.newLabel` 现在恒不渲染(`showNew: false`),成了死参数。子代理按「不自己发起重构」的偏好留着未删——复审同意,删它属于另一次决定。

## §5.15 CL 批 · chat 左岛按驻地分组(0724 用户提,依赖 WD1)

> 用户:「加了文件夹概念后,chat 左岛组织形式要变:新对话、搜索、置顶,下面是各个工作目录(组也有按钮,归档/删除整个工作目录),最下面才是最近。」

**现状**:rail 只分 置顶/最近 两组(`conversation_rail_model.dart:55` 注释明言),无限翻页,行时间仅是标签。

### 两条先行裁决

1. **⚠️ 命名防误读(诚实律)**:「删除整个工作目录」绝不能出现——用户会读成**删磁盘上的真文件夹**。组头菜单文案 = 「归档全部对话」/「删除全部对话」(danger,确认框带内容盘点),**永不出现"删除目录"字样**;组头菜单另置「在 Finder 中显示」强化"目录本体我们不碰"的心智。
2. **驻地组 = 投影,非实体**:不建表、无生命周期——就是按 `conversations.work_dir` 聚合的视图;组内最后一个对话归档/删除后组自然消失。**不做"空目录组"管理。**

### 结构(定稿)

```
新对话 · 搜索(固定)
置顶            —— 任何对话可置顶;置顶赢,不在驻地组重复
📁 驻地组 ×N     —— 组头:目录名(重名补父路径消歧)+ 计数,可折叠;
                   组间按组内最近活跃排序;组头 ⋯ = 归档全部/删除全部/在 Finder 中显示
最近            —— 仅无驻地对话(驻地对话只住组里,不重复)
```

联动:fork 继承驻地 → 落同组;对话退出驻地 → 移回最近;组头动作槽 = **LR 批的 `typeHeadActionsBuilder` 地基直接复用**。

### 后端小件(归 WD 系列,防"分组撒谎")

rail 无限翻页,一窗内做客户端分组 → 组成员/计数随翻页漂移 = 撒谎。故:
- `GET /conversations/workdir-groups` → `[{workDir, count, lastMessageAt}]`(不同驻地有界,N4 有界投影,无游标;登记 api.md)
- 对话 List 端点加 `?workDir=` 过滤(空值语义=仅无驻地),组展开按组翻页
- 批量动作 ×2(整组归档 / 整组删除,事务;命名 N5,施工时定,如 `POST /conversations:archive-workdir {workDir}`)——不让前端循环打 N 请求

### 归位与依赖

依赖 `work_dir` 列(WD1)→ 施工序里排 **WD1 之后**,作 **WD1.5(rail 重组)**;demo fixture 补种带驻地的对话组。

**验收**:四段结构真机核对;组头批量动作确认框内容盘点诚实;fork/退驻地的组间迁移;分组计数与翻页一致(无漂移);置顶不重复;i18n 新键;五电池;testend 覆盖两个新端点 + workdir-groups 投影;文档 1:1(api.md/domains/conversation.md/contract.md)。

→ **已施工(0725,施工序⑮)。后端投影 + 前端 rail 组装同批落地。**

**后端四件（比工单多一件,理由在下）**:
- **`GET /conversations/workdir-groups`** → `[{workDir, activeCount, archivedCount, lastMessageAt}]`。**偏离工单措辞的一处**:工单写 `count` 单个计数,实际**分列两个**。理由是诚实——组头计数依「显示已归档」开关而变,而两个**批量动作刻意对那个开关盲**(破坏性动作不该取决于视图偏好),故确认框盘点的数必须是**和**。若只给一个 `count`,它要么让组头撒谎、要么让确认框撒谎;分列则**端点还能保持零参数**（否则要一个 `?archived=`,而那会让它既不属 N4 有界投影的①形也不属②形——api.md 前言已因此扩写②形:判据是「收不收真参数」、不是「返一个还是返一批」）。
- **List 加 `?workDir=`（三态、按键是否出现读）**——缺席=不过滤 / **出现且为空**=仅无驻地 / 有值=仅该驻地。domain 侧 `ListFilter.WorkDir *string`，指针正因中间那态:`""` 在此是**有意义的过滤值**、不是「没有过滤」。
- **⚠️ 多加了 `?pinned=`（三态）**——**工单没列这一条,这是本批唯一新增的契约面,理由如下**:结构要求「置顶赢、不在驻地组重复」,而这要求置顶段**完整**。其余各轴都按驻地过滤之后,「所有置顶线程」**再也**不能靠既有的「置顶都落首页」假定复原——一条住在**收起**的组里的置顶线程根本不会被取回来,于是置顶段会**漏行**(一个真 bug、不是效率问题)。加一个与 `?archived=` 同族的三态过滤后,rail 的四段 = 四条服务端查询、**零客户端重分桶**,且置顶段的计数也变成权威的。
- **两个集合级动作 `POST /conversations:archive-workdir` / `:delete-workdir`**（body `{workDir}`,返真正改变了几条）。**事务边界**:store 的 `ArchiveWorkDir`/`SoftDeleteWorkDir` 在**一个** `db.Transaction` 里 Pluck 出 id 集 + 施加**一条**语句 + **交叉核对行数与 id 数**;逐行级联（停生成 / 丢 humanloop 授权 / relation 边 / 触点台账 / 逐行既有回声）在**提交之后**跑、best-effort。**整组删除到底删了什么**:那些 `conversations` 行上的 `deleted_at` 戳 + 每条线程的 relation 边与触点台账。**没删什么**:任何消息行（`messages`/`message_blocks` 无 `deleted_at`、绝不物理删）、以及**文件系统上的任何东西**。**范围**:该驻地下的**未置顶**对话(置顶存活;archive 只动未归档行故重跑报 0、delete 跨归档态)。**空 `workDir` 拒 400 `INVALID_REQUEST`**（`''` 是正当的列表过滤、但**不是一个组**;接受它会让一次请求扫掉每一条从未选过目录的线程）· 非绝对拒 422 `CONVERSATION_INVALID_WORK_DIR`。**零新错误码**。

**诚实律的落实（本批第一优先）**:组头菜单 = 「归档全部对话 / 删除全部对话 / 在访达中显示」(EN: Archive all conversations / Delete all conversations / Reveal in Finder)。确认框:归档「归档这些对话？」+「「anselm」里的 12 个对话将移入归档，随时可以取回。置顶的对话不受影响。」;删除「删除这些对话？」+「「anselm」里的 12 个对话将被永久移除。**磁盘上什么都不会被删除——文件一个都不动。**置顶的对话不受影响。」**钉法**:`conversation_rail_test` 的 `honesty law · the residency-group wording never says «directory»` 遍历 `AppLocale.values`、对 8 条文案断言中文不含「目录」（注意「工作目录」**包含**它,故组的措辞也不能退回驻地按钮的词汇表）、英文不匹配 `/director|folder/i`,并**正面**要求删除框说出「磁盘/disk」且带那个计数——**可怕词的缺席不等于一句安抚**。

**重名消歧算法**（`workDirGroupLabels`,纯函数、6 条单测）:每个路径先取**末段**;把撞名的**簇**各自向左多取一段、**反复**直到唯一或段用尽（`a/x/anselm` vs `b/x/anselm` 一段不够、要两段）;**只有真撞上的才长**（旁边的 `notes` 不动）。分隔符 `/` 与 `\` 都算段（Windows 驻地）。**组间排序键** = 服务端的 `MAX(last_message_at) DESC, work_dir ASC`（全序,故两次相同请求绝不互换）。

**两处施工时定的裁决**:①**组默认收起、只有第一个(最近活跃那个)打开**——文件夹的心智是点开、收起使「最近」不必翻过一切才够得着,且收起的段**什么都不取**;而你刚干活的那个组是开着的。②**在当前范围下计数为 0 的组不渲染**——归档掉一个文件夹最后一条线程必须让它像被删掉一样消失（投影仍报告该组,因为它的归档线程还在、开「显示已归档」会把整个文件夹带回来）。

**惰性取数不靠新回调**:每段都是一个分页轴、`pageKey` **就是** notifier 的轴键（`pinned` / `recents` / `wd:<path>`）,组轴以「未加载 + `hasMore: true`」起步,故它的**第一页**由 rail **既有**的尾哨兵在该段被展开**且**滚进视野时才取——没有「展开时取数」这种特设回调。

**施工中查实并封掉的一个真洞（工单没提、但分组一落地就存在）**:rail 的**搜索**。收起的文件夹什么都不取,故一次只把四段各自收窄的搜索会对**每一条用户尚未滚进视野的对话**答「没有匹配」——相对 WD1.5 之前是**功能回归**。裁决:**搜索替换结构、不过滤结构**——有查询词时 rail 变成对整个 workspace 的一条**平的、无头的**结果列表（对驻地盲、对置顶盲）,清掉查询词即恢复四段。那也正是这个问题的诚实读法:哪些**对话**匹配、不是哪些文件夹匹配。测试 `SEARCHING replaces the structure: one flat list that reaches into FOLDED folders` 钉住它（含一条住在从未取过行的文件夹里的匹配）。

**testend 场景（5 个,`scenarios/chat_workdir_group_test.go`）**:`TestChatWorkDirGroups_{ProjectionMatchesReality, ListFilters, ArchiveWholeGroup, DeleteWholeGroup, CountsDoNotDriftAcrossPaging}`。

**⚠️ 一条诚实边界**:工单要求「整组删除断言**消息行仍在**」——那条断言**在黑盒里不可观测**。每条消息读路径都被一次对话存在性检查所辖（`chatapp.ListMessages` 先 `Conversations.Get`）,故一条已立碑线程的 `GET /{id}/messages` 按设计答 404,线缆**分不清**「线程的行被立碑了」与「它的消息被抹了」。故 D1 的证明改做在两张表都看得见的地方:后端单测 `TestDeleteWorkDir_NeverTouchesAMessageRow`（同库立起 messages schema → 写一个真回合 → 删整组 → 从 messages store 把 message 与 block 行**逐字节**读回来）。testend 那个场景转而断言线缆**能**证明的最强那些,并把这条边界写进了它自己的注释与 `domains/conversation.md`。

**顺带强化地基一处**:`ormpkg.ParseDBTime`——原始读（GROUP BY / UNION / FILTER）拿不到驱动的声明类型转换,聚合列一律作 TEXT 回来,而 flowrun store 已为此手抄了一份三格式解码。新增地基函数并让 flowrun 的私有 helper **一行转发**过去（设计原则 #8:该由地基提供的样板不在业务层再抄一遍）。


## §5.16 CH-0 · chat @ 提及回归修复(0724 用户报,紧急)

> 用户:「chat 里 @ 没有出现那个选择页面,@ 不了东西了。」既有功能断裂 = 回归,排最前修。

**复现法(用户指定)**:`make -C backend seed && make -C frontend app`(seed 里有现成实体)→ composer 里打 `@` → 面板应弹未弹。

**triage 纪律**:
1. **先在干净 main 复现**——报告来自用户真机,当时树上有另一会话的在飞改动(audio/multimodal);先排除在飞改动才知道是不是已提交历史里的回归。
2. 已定位的链路起点(读码所得,供施工时省一步):`chat_composer.dart:160-199` —— `activeMentionQuery`(token 识别)→ `mentionSourceProvider.search`(注意 :181 **查询失败静默关面板**的分支——后端没起/接口失败时面板永不弹,症状一致)→ debounce/seq 竞态守卫 → `OverlayPortal`(:648)。逐环验。
3. 嫌疑名单(按序排查,不预设):①search 抛错走了静默关面板分支 ②G10 曾动过 `mention_names.dart`(NUL 字节改 `\u0000` 转义,当时判语义等价——重验)③OverlayPortal/TapRegion 宿主变化。

→ **嫌疑①查实为一个真缺口并已修(0725,施工序⓪ 的可做部分)。**

`EntityMentionSource.search` 用一个裸 `Future.wait` 扇出到四类实体,而 `Future.wait` **快速失败**:任一类出错(端点抖动、切工作区后的 401、410)整个 search 就 reject,composer 的 catch 随即关掉面板(它没做错——留着上一个 query 的候选会让读者插错提及),于是面板干脆不出现,且读者无从分辨「没匹配到」与「出故障了」。技能那半本来就有 try/catch 兜着,实体这半没有。修法:每类各自 `.catchError` 降级成空,一类不舒服只花掉那一类的行。

**写测试时又照出我自己修复里的一个缺口**:让 fixture **同步**抛错,隔离依然失效——裸调用会在 `.catchError` 挂上之前就炸掉。改用 `Future.sync(() => …)` 包住(技能那半同理:`async` 体只转换**它自己内部**发生的抛错,而 `listSkills()` 是在 await 之前被调用的)。反证过:去掉隔离,两条测试转红。

**诚实边界:这是否就是用户那次报告的成因,尚未确证。** 确证需要他的机器(面板不开还有本节列的其他路径)。已确证的是这个故障隔离缺口,它与症状**完全一致**,且无论成因如何都该修。**嫌疑②③ 未排查**——它们需要真机复现来分辨,`ACCEPTANCE-GUIDE.md` 已记为真机项:`make -C frontend app` → 打 `@` → 若仍不弹,查控制台是否有 search 抛错。

**§5.16 要求的回归测试**:`test/app/entity_mention_source_test.dart` 四条。要求里那条「打 @ → 面板弹出 → 选中插药丸」的全链 widget 测**未写**——它需要 `chat_composer_test` 级的宿主加真 `EntityMentionSource`,而当前那套宿主注入的是 `_FakeMentions`;列为剩余。
4. **修复必须配回归测试**:「打 @ → 面板弹出 → 选中插药丸」全链 widget 测——这次断裂无测试报警,说明现有矩阵没锁这条主干行为。

**归位**:施工序 **⓪ 号位**(在 Flutter 升级之前修——先在现版本定位,避免升级变量混淆)。Fable 亲自(debug 需判断)。

## §6 open questions(施工前清)

1. ~~施工顺序~~ → **已拍板(0723,用户「都听你的」)**:**①Flutter 升 3.44**(独立一步:改钉值 → `make setup` → 根 `make verify` → 真机冒烟,确认无回归)→ **②CR-1a**(拆壳的 LayoutBuilder;RI 大半 + 海洋跳动 + 偶发崩溃皆挂其下,先拆再量剩余)→ ③CR-1b/CR-2/CR-3 → ④RI(治本后重估余量)→ ⑤TS → ⑥CH-a/b/c → ⑦VT → ⑧EA → ⑨SK → ⑩ES → ⑪WD1/2/3。**理由**:①② 会动到后续多批共用的同一批文件,先做省重复返工;功能批按「见效快→依赖重」排。
2. auto-title 对 fork 对话的接管触发条件(现逻辑是否只看首回合)——施工 CH-b 时读码核对。
3. ~~Go 版本（mise 钉值）≥1.24 则 `os.Root`，否则 EvalSymlinks+前缀~~ → **已核对（0725 施工 WD1）：`mise.toml` 钉 `go = "1.25"`（`go version` 实测 go1.25.11 darwin/arm64）→ 走 `os.Root`。** 并且**先实测了它的语义再定**：写了一个探针，在 darwin/go1.25 上对**绝对**、**相对**与**目录**三种指向根外的符号链接分别 `Root.Stat`，三种全报 `path escapes from parent`。这一步不是形式——若 `os.Root` 像 chroot 那样把**绝对**链接目标重写到根内解析，它的判词就会与真 syscall（`os.Rename`/`os.WriteFile` 会跟随的那个目标）分道扬镳，于是「用 os.Root」这条指示本身会**低报**逃逸、成为安全洞。实测证明它不会，故它可以承重。判定另需 `filepath.Rel` 先挡兄弟目录（`/root-evil` vs `/root`——`os.Root` 对它无话可说，因为它压根不在根里）。
4. ~~排队时按停止:清不清队列~~ → **已裁定(0725 施工⑦后半):不清。** 理由见 §3.4 施工记录与 `chat_queue.dart` 的类注释;测试 `chat_queue_test` 与 `chat_composer_test` 各钉一条。
5. ~~ES 批 B 类引导文案~~ → **已拍板(0723):一套通用「创建首个版本」**(不逐实体分化)。
6. ~~TS 批 Flutter 版本~~ → **已升级到 3.44.8(0725 实施)。实施记录见下,含一条调研没抓到的真阻碍。**

   **① vendored super_editor 编译不过**:`DocumentImeInputClient` 缺 `TextInputConnection.updateStyle`。这正是升级前调研列出的 3.44 破坏性变更之一(`setStyle` 弃用 → `updateStyle`),但当时逐条对照本仓代码**九条全部零命中**——因为**它藏在 `third_party/` 的 vendored 依赖里**,不在 grep 范围。教训:**破坏性变更的命中面必须包含 vendored 第三方**,否则会得出「零命中」的假安全结论。修法:装饰器补 `updateStyle` 转发(装饰器必须转发所装饰接口的每个成员,无行为可裁决);`setStyle` **保留**——它仍在接口上,删了会断掉 Flutter 尚未迁移的调用方。

   **② `axisAlignment` → `alignment`** 两处(`an_sidebar_list` / `notification_tray`):3.44 用双轴 `alignment` 取代单轴 `axisAlignment`;原 `-1` 的意图是「生长时钉住起始边」,等价写法 `AlignmentDirectional.topStart`,且 RTL 下语义正确。

   **③ `IconData.codePoint` const 契约收紧**(`icons.dart`):用了 `ignore`,但**代价写进了注释**——非 const 的 IconData 会退出图标 tree-shaking。本文件的全部目的就是运行时给 Lucide 换字重族、构造上不可能 const,且字体本就作为 asset 打包,故现状未变。**将来若体积成为杠杆,正解是构建期生成 const 表,而不是删掉那条 ignore。**

   **⚠️ 一条流程教训(比上面三条更值得记)**:验证升级时用了 `make verify | tail`,连续两次读到 "exit code 0" 而实际上**三个前端测试组全红**——管道的退出码是 `tail` 的,不是 `make` 的。这个写法看起来完全无害,却会**把门禁结果整个吞掉**。**验门禁一律显式取 `$?`**(`make verify > log 2>&1; echo $?`),绝不让 `make` 的退出码经过管道。

7. ~~TS 批 Flutter 版本(旧条)~~ → **已拍板(0723):升级到 3.44**(`mise.toml` 改钉值),顺带拿到 3.41→3.44 的其余选择相关修复。升级本身独立成一步先做:改钉值 → `make setup` → 根 `make verify` 全绿 → 真机冒烟,确认无回归再进 TS 主体。
8. ~~VT 批「删除版本」是否做~~ → **已拍板(0723):不做。** ⋯ 菜单本批只落「设为活跃版本」(搬 `:revert` 现成件)+「展开 diff」两项,零后端改动。删除版本的三个真问题(D1 归属 / diff 链断裂 / `:revert` 目标消失)未解,**不留半成品、不预埋端点**;将来真要做,单独走一次后端裁决。
7. ~~TS 批「鼠标拖滚」取舍~~ → **已拍板(0723):删掉 `PointerDeviceKind.mouse`**。滚轮/触控板/滚动条/触屏全不受影响,失去的只是"按住左键拖内容"这个**手机习惯**、换回全 app 文字可选。这不是权衡而是**纠错**——Flutter 桌面默认本就不含 mouse 且是刻意设计(官方文档明述理由即"让滚动容器里的文字可选"),当初覆写的注释「the base desktop set omits mouse」把这份刻意读成了疏漏。**同提交把该注释重写成当前事实,别再留误导下一个人的话。**

## §7 施工执行协议(0724 用户拍板)

**模型绑定(唯一事实源——换模型只改这一行)**:
- **主会话** = **Opus 5**(0724 用户改;原定 Fable 5,成本过高)。下表一律写角色「主会话」,不写模型名,免得换一次改一表。
- **派出档(两档)**:样板化 → **Sonnet 5**;有 UI 品味 / 状态逻辑 + 调研读码 → **Opus 5**(与主会话同档;派出去买的是**主会话的上下文预算**,不是单价差)。**不用 haiku**(本库文法纪律严——字重两档 / 内距单源 / i18n 铁律 / 原语禁手搓,省的钱不够付返工)。

**串行铁律**:一次只有一批在建(门禁抢树 / codegen 互踩 / 同文件交错是实证事故源);批间 `make -C frontend quick`(后端批 `make -C backend test`),战役收口根 `make verify` 全绿。派出批跑门禁期间主会话只做零代码工作(预读规格 / 备复审清单),绝不碰树。

**分工判据(非按大小)**:①设计密度(有未决裁决 → 主会话亲自)②宪法接触面(D1/seq/上下文装配/渲染语义 → 亲自)③规格完备度(照敲即成 → 可派)。太小的活不派(简报成本 > 顺手做掉)。**派出模型按「一次过概率」定档、非按单价**——返工回合(主会话复审 token + 墙钟)远贵于子代理 token。

**施工序 × 分工**(依赖已排;17 步):

| # | 批 | 谁 |
|---|---|---|
| ⓪ | CH-0 @ 提及回归 —— **嫌疑①(故障隔离缺口)已查实并修 0725**;嫌疑②③ 与「全链 widget 测」待真机,见 §5.16 | 主会话 |
| ① | ~~Flutter 升 3.44~~ **已完成 0725**(改钉 → setup → 全量 verify 四门禁全绿,commit `563c5ab2`)。**真机冒烟未做**——待 E 类真机档一并补,别当已验 | 主会话 |
| ② | ~~CR-1a 拆壳 LayoutBuilder(架构根,最重一刀)~~ **已完成 0725**(记录见 §5 CR-1a 条) | 主会话 |
| ③ | ~~CR-1b 滚动监听 ×9 + CR-2 错误钩子~~ **已完成 0725**(实为 **11 处**,名单漏一类;记录见 §5 CR-1b 条) | 主会话 |
| ④ | ~~CR-3 Output 树高度~~ **已完成 0725**。**改判为主会话亲自**——本节有两处「施工时定稿」+ 一条待验隐患,按上面分工判据①(有未决裁决)不该外派;记录见 §5.7 | 主会话(原定派 Sonnet 5) |
| ⑤ | ~~RI 右岛四病灶 + 「禁止条件包装」军规+守卫~~ **已完成 0725**(四病灶全落 + 军规入 CLAUDE.md/design-system + 行为式重挂守卫;推翻本节「加重项」判断,做法 #2/#3 各有取舍,见 §5.9) | 主会话 |
| ⑥ | ~~TS 文本选择~~ **已完成 0725**(红线/拓扑/焦点/光标/chrome 排除/流式互斥六项;必补③并入 CH-a、装饰性元数据留真机后定,见 §5.10) | 主会话(未派——排除清单被拓扑砍掉大半后不值一次简报) |
| ⑦ | ~~CH-a 动作排+复制+排队~~ **已完成 0725**(动作排+复制见 §3.2 记录;排队见 §3.4 记录,含 open question④ 裁定) | 主会话 |
| ⑧ | ~~CH-b fork + CH-c retry~~ **已完成 0725**——CH-b(前后端 + testend 五项,两处契约冲突已裁决入档)· CH-c(`superseded_by` + `:retry` 两分支 + 装配过滤三点 + testend 五项 + 前端三入口与版本翻页;四处裁决 + 两处措辞偏离入档,记录见 §2.2 CH-c 条) | 派 Opus 5 + 主会话复审 ✅ |
| ⑨ | ~~VT 版本页~~ **已完成 0725**(全宽手风琴 + hunk 只显变更 + 真虚拟化;三处偏离工单措辞已入档;降级曲线主会话复跑复现) | 派 Opus 5 ✅ |
| ⑩ | ~~EA 实体 ⋯ 菜单~~ **已完成 0725**(七 kind 菜单 + 6 个 repository 封装;**纠正本节四处**〔restart 早已封装 / iterate 非无参 / 立即运行须导航〔唯一执行点立法〕/ 调试台=右岛而非 tab〕+ 查实删除无引用守卫,见 §5.12) | 派 Sonnet 5 ✅ |
| ⑪ | ~~SK 密钥分栏~~ **已完成 0725**(派 Sonnet 5 建、主会话逐行复审并改了一处 + 跑门禁;记录见 §5.6) | 派 Sonnet 5 ✅ |
| ⑫ | ~~ES 空态退役 ×13~~ **已完成 0725**(A 类 6 + 错误态 1〔本节分类有误已纠〕+ B 类 6;`insetEmpty` 已删;**B 类只有引导没有动作——创建入口不存在**,见 §5.8) | 派 Sonnet 5 ✅ |
| ⑬ | ~~LR+LI rail 重构+文案+tooltip 地基~~ **已完成 0725**(tooltip 地基主会话亲做;rail 重构+文案+守卫+首屏说明 派 Sonnet 5、主会话复验守卫非空绿;记录见 §5.13/§5.14) | 混合 ✅ |
| ⑭ | ~~WD1 驻地地基~~ **已完成 0725**（后端八件 + 前端按钮/菜单/标记/最近目录 + 文档九处 + 单测 41 条 / testend 六场景 / widget 15 条；**三处与简报措辞的偏离**与**一处主动加固**已记档，见 §2.2 WD1 条） | 主会话 |
| ⑮ | ~~WD1.5 rail 驻地分组(CL)~~ **已完成 0725**(后端四件〔投影两计数分列 / `?workDir=` / **多加的 `?pinned=`** / 两个事务型批量动作〕+ 前端四段 rail 多轴态 + 组头菜单与两个确认框 + 诚实律守卫 + 文档五处;**三处偏离/新增与一条诚实边界已入档**,见 §5.15) | 主会话 ✅ |
| ⑯ | ~~WD2 git 操作 / WD3 worktree~~ **已完成 0725**（`infra/gitinfo` 扩成四读三写 + 三个 `workdir:` 动作端点 + 投影两列表 + **8 条新错误码** + 前端 git 段三动作与一个命名模态 + 文档六处;**脏区护栏定稿为「直接拒绝」**、`make worktree` 约定逐字转录、**三处偏离与两条诚实边界已入档**，见 §2.2 WD2/WD3 条） | 主会话 ✅ |

**派出协议(五条,G 战役教训)**:①简报 = 本册对应节 + 禁区清单(不许动的文件 / 不许自造抽象)②一批一提交、文档同步同责(#9)③**主会话逐行对抗复审后才准提交**(全量读 diff,非抽查)④门禁由主会话跑(不与子代理抢树)⑤视觉批每批交用户真机截图验收。

**开工令**:用户明令「我真的说开始才开始」——本册就绪后待令。
