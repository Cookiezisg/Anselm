---
id: DOC-021
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-21
review-due: 2026-10-19
audience: [human, ai]
---

# chat —— 对话引擎

## 1. 定位

把一条用户消息变成持久化回合、在工作区工具上驱动 ReAct 循环（`app/loop`）、实时推流、落盘结果。**它是枢纽但一无所有**：conversation/messages/tool/attachment/memory/document/catalog/todo/model 全部经 DIP 端口注入（loop 例外——chat 直接调 `loopapp.Run`、并作为 `loop.Host` 被其回调）——chat 用 fake LLM 即可整测。chat 无 domain 包（[messages](messages.md) 是中立内容模型）；自己的 HTTP 错误（`EMPTY_CONTENT`/`STREAM_IN_PROGRESS`/`NO_PENDING_INTERACTION`/`INTERACTION_INVALID_ACTION`）就地用 errorspkg 定义。

## 2. 心智模型：每对话一条串行队列

`Send` 是**两段式**（头部先验对话存在——404 早退不落孤儿行；归档对话**自动解档**后照常接收，软失败不挡消息）：① 同步落 user 回合（text block + 附件 id/@提及快照（见 §5 freeze-on-send）进 Attrs）+ 开 assistant 回合（streaming、无 block——先 mint id 作流锚点）+ 发 message_start；② 任务入该对话的 `convQueue`。**每对话一个抽取 goroutine 串行生成**（同时一个 assistant 回合 → block seq 分配天然无竞争）；生成中（`q.running`，至 finalize 放行）再 Send 直接 409 `STREAM_IN_PROGRESS`（不排队）；回合收尾活（同步压缩检查，可达秒级真 LLM 调用）期间的 Send 落进**单槽缓冲**、紧随其后被服务，槽满仍 409。队列 **5 分钟无任务自毁**（休眠对话零成本），新 Send 按需重建；拆卸与投递在 q.mu 下原子互斥（task 不可能滞留死 channel）。**Shutdown 即时**：cancel 全部在跑回合 + stop 信号短路每个队列（不等 idle timer）。

**processTask 的 ctx 装配**（Send ctx 早已消失，全部重建）：`Detached(ws)` + locale + conversationID + messageID + AgentState + messages 流桥 + entities 流桥（build 镜像）+ humanloop broker + **驻地 `SetWorkDir(conv.WorkDir)`**（WD1，见 §8——**在读头行之后**种，故中途切换在**下一**回合生效） + **回合总墙钟 `WithTimeout(limits.Timeout.ChatTurnSec)`**（默认 1800s、可 `PATCH /limits`；步数封顶 MaxSteps 之上的**时间兜底**——流/工具卡过每步守卫（F93 流总墙钟、F83/F92 工具墙钟）的回合否则在 detached ctx 上永跑、卡 isGenerating + 阻塞 graceful shutdown，F100）+ cancel（Cancel 端点 / shutdown 触发）。

## 3. 回合生命周期

`chatHost` 实现 loop.Host（agentHost 的持久化对应物）：
- **LoadHistory**：经 `LoadThreadForLLM(convID, 水位)` **读最小化载入**——**同族三个排除全部下推 SQL**：subagent 子消息（`subagent_id = ''`，内部 trace 不进父历史）+ **被取代的版本**（`superseded_by = ''`，重试/编辑重发的早期版本，见 §3.5）+ 压缩已折叠块（`seq > 水位`，即 seq ≤ `summaryCoversUpToSeq` 的块已并入 conversation.summary、从不读盘），故长单对话会话不再每轮从盘重读整张含折叠的 block 表。水位是折叠的权威信号（`archived` 是其 best-effort 冗余标记、恒 seq ≤ 水位；水位恒落回合边界），故 LLM 可见集与"整 LoadThread + 读后 Go 过滤"逐字相同——读后的 Go 过滤（subagent 跳过、`unfolded`、空回合跳过）留作双保险、对已过滤集是 no-op。summary 前置；user 回合按模型能力渲染多模态附件。（`LoadThread`——全内容——仍服务 UI reload / 自动标题 / 压缩 / subagent 轨迹读。）
- **Tools 每步重算**：resident + `search_tools` + **能力工具（CapabilityTools 缝,WRK-082 批B）** + 本对话近期已 activated 的 lazy 工具。能力工具是**逐请求 resident**——仅当运行期路由存在才注入(诚实缺席:`generate_image` 有 key 能出图才在、`generate_speech` 有 key 能说话才在,`tool/generate.Router.ImageAvailable/SpeechAvailable(ctx)` 每步重估,key 增删下一步生效;两者**各自**判定——能出图不代表能说话);完整 schema 随请求走、不进 lazy 简介表(模型必须**知道**自己会画,无发现舞步)。注意一个刻意边界:能力工具**不入** `GET /tools` 静态目录(它按 ctx 存在,目录是静态集);subagent 侧经 `SetMultimodal` 吃同一份 `capabilityTools`(见 [subagent.md](subagent.md))。inactive inventory 在 system prompt 只放 name + ≤180 rune 首行简介；`search_tools` 的 durable tool_result 只返 `{name,purpose}` 激活清单，完整 schema 仅在**下一请求的 tools 字段出现一次**，不再双份占上下文。AgentState 用 16 项 recency set，重新发现刷新、最旧淘汰，防长会话最终退化为“全工具常驻”。**AutoActivator**——LLM 直接点名 lazy 工具时自动激活（免先跑 search_tools）。
- **ReminderProvider**：每步前注入 live todo 清单为临时 `<system-reminder>`（不污染持久历史）。
- **MediaExpander（WRK-082 批B' 消费咽喉·tool_result 半）**：loop 每步工具跑完后从 tool_result 收集 MediaRef（`pkg/mediaref`），chatHost 经 attachment 服务按**本回合已解析模型**的模态展开成原生 content part，以追加 user 消息只喂后续请求——`generate_image`/MCP 返图当轮即被模型看见；展开失败只 warn、绝不炸回合；这条消息**不落盘**（persist 的 blocks 不含它，重放时由同一咽喉重新展开）。
- **附件文档媒体（WRK-082 批F 消费咽喉·第三个入口)**:附件文档以**文本**进 system prompt,而 system prompt 是一个**字符串**——一份 @ 进来的文档里的图表,到达模型时会是字面串 `![chart](anselm://media/att_…)`,模型一个像素也看不到。故 host 构造时**一次**问 `DocumentRenderer.MediaAttachmentIDs`(逐步问会为同一答案把同样的行重读十几遍——LoadHistory 是 loop 每步都调的),LoadHistory 把这些 id 经**同一条**咽喉展开、**追加**到最后一条 user 回合的 parts 上(那是一张图在请求里唯一能物理存在的地方;追加而非替换,保住用户自己附的东西;纯文本回合转成 parts 时自己的文字**在前**——问题仍读在它所问的图之前)。看不了图的模型在此拿不到东西、仍读得到文档正文(诚实降级)。
- **附件文档媒体（WRK-082 批F 消费咽喉·第三个入口)**:附件文档以**文本**进 system prompt,而 system prompt 是一个**字符串**——一份 @ 进来的文档里的图表,到达模型时会是字面串 `![chart](anselm://media/att_…)`,模型一个像素也看不到。故 host 构造时**一次**问 `DocumentRenderer.MediaAttachmentIDs`(逐步问会为同一答案把同样的行重读十几遍),LoadHistory 把这些 id 经**同一条**咽喉展开、**追加**到最后一条 user 回合的 parts 上(那是一张图在请求里唯一能物理存在的地方;追加而非替换,保住用户自己附的东西;纯文本回合转成 parts 时自己的文字**在前**——问题仍读在它所问的图之前)。看不了图的模型在此拿不到东西、仍读得到文档正文(诚实降级)。
- **PromptCompactor + ContextObserver**：每次 sampling 前由 loop 做 route-aware 上下文治理；chatHost 把结构化 semantic checkpoint 委派给 contextmgr/utility model，并把最后一次成功 prompt 的真实 input/budget/route、request 组件 bytes、edit/compaction/recovery 计数写进 assistant `Attrs.contextUsage`。这与 `Message.InputTokens` 的整轮累计计费量严格分栏。
- **WriteFinalize 在 Detached ctx**：用户中途关页也绝不留永久 streaming 孤儿；finalize 同事务持久化 `Attrs.contextUsage`。**硬崩溃**（kill -9）的孤儿由 boot 对账兜底（`SweepOrphans`——每 workspace 把 pending/streaming 行扫成 cancelled，messages 版 scheduler.Recover）。
- **recency + 未读 watermark（经 `ConversationReader` 端口）**：Send 落 user 回合后 `TouchLastMessage(…, unread=false)`、WriteFinalize 落 assistant 回合后 `TouchLastMessage(…, unread = status==completed)`——**这条不对称就是未读信号**：用户发送=已读、完成的回复=未读、取消/出错终态=不算（queued-cancel 路径不调 Touch、不动 unread）。两次都把 unread 折进 last_message_at 的同一原子 UPDATE（自己的消息绝不半提交成未读）。端口另有 `MarkSeen`（`:seen` 动作用户打开线程时清 unread）。详见 [conversation.md](conversation.md) 的 hasUnread。
- 回合后（仍在队列槽内防竞态）：首回合自动起标题（utility 模型、best-effort）+ 同步触发 durable 上下文压缩检查（contextmgr）；**长单回合不再等到这里才处理**，loop 已在每个 sampling 前做旧 tool_result 清理与 continuation checkpoint，并在 provider 权威超限时透明重试同一步。**utility 默认由 freetier provisioning 播种**——建 workspace / 每次 boot 自愈时把受管 `anselm-auto` 播成 dialogue/utility/agent 三 scenario 默认（只填未设、绝不覆盖用户显式选择，见 [support-services](support-services.md) 的 freetier），故 `ResolveUtility` 开箱即解析。标题据首条 user+assistant 摘要、**按对话语言**产出，经 `SetAutoTitle` 落 Title+AutoTitled 并发**单条** `conversation.auto_titled`。**两个预算，不是一个**（WRK-083 L11）:`autoTitleTimeout`(10s) 只编**慢的那半**（读线程 + 生成，一次网络往返），落盘另取一个从 **detached** context 新 derive 的 `autoTitlePersistTimeout`(5s)——共用一个 deadline 会让慢步把快步**饿死**:标题已经生成出来，却在最后一寸被一个与「写它」无关的 deadline 丢掉（真机实证）。`maybeAutoTitle` 只在仍无标题时开火，故这种丢失会被**下一轮**静默补上（代价是又一次 LLM 调用），而**只发生过一轮**的对话会永远叫「New chat」。同一规矩 `WriteFinalize` 早已照做（它也重新取 detached ctx，理由同款）——autoTitle 是唯一没铺到的那一处。压缩水位统辖整回合：旧附件跨水位前把持久附件 id 写入摘要，后续 agent 只能经 `read_attachment` 重读，不编造已移出上下文的媒体细节。utility 缺席时，loop 仍可用主模型 semantic checkpoint，失败再走确定性应急 checkpoint；回合边界 durable summarize 则 best-effort 跳过。
- maxSteps **实时读** `limits.Current().Agent.MaxSteps`（默认 25，`PATCH /limits` 热换下回合即生效；高于 agent invoke 默认的 `InvokeMaxTurns`=10——交互对话合理串更多步）；触顶诚实报 stop_reason `max_steps` + error_code `MAX_STEPS_REACHED` + "继续"提示。

## 3.5 原地重试 / 编辑重发（`POST /{id}:retry`，WRK-077 CH-c）

**分支模型是「版本指针」、不是删改**：`messages` 是 D1 Log 表，故「重试」= 旧行写 `superseded_by` = 新行 id（唯一写者 `MarkSuperseded`，**单列部分 UPDATE**、不碰 content/status/created_at）+ 新行 `attrs.retryOf` = 旧行 id，**零删除**。为何合 D1、以及本列**不是**软删，见 [database.md](../database.md) `messages` 行的判据段。

**`Retry(RetryInput{Content, ModelOverride})` 的两分支**（`app/chat/retry.go`）：无 `Content` = **重生成**（supersede 末 assistant、开一条新 streaming assistant 行、入**既有** convQueue，不写新 user 回合）；有 `Content` = **编辑重发**（supersede 末 user + 其 assistant 两条，落带编辑后文本的新 user 回合 + 新 assistant 回合）。**写序刻意是「先落新行、后 supersede 旧行」**：两步之间失败留下一个**看得见的重复问句**（自我修正——下次重试把两种写法一起 supersede，且屏幕上诚实），而反序失败会从模型视图里**删掉**一次交流且什么都不留下。编辑重发的新 user 行 Attrs = **原附件 id**（附件内容寻址、引用不花钱）+ `retryOf`；**@ 提及快照刻意不带**（冻结**内容**而非引用，编辑后的文本可能已删掉那个 `@`），且触点台账把 `attached` 触碰**重锚**到现在是现行版的那一行（`lastMessageId` 是跳转目标，指向已被折进版本组的行会把读者送到屏上不存在的气泡）。

**替换目标的选取**（`retryTargets`）：只看**现行且顶层**的行（`superseded_by = '' && subagent_id = ''`）——已被取代的行是更早的版本，第二次重试必须替换**最新**版而不是某个祖先，否则版本链会分叉、「后续基于哪一版」就有两个答案；subagent 行根本不是本线程的回合。尾巴合法地可以是**一条没有回答的 user 行**（崩溃清扫过的线程、或生成从未开始的编辑重发），此时「重生成」自然降级为「把缺的那个回答产出来」，无需别处任何特例。

**409 门读两处**，因为它们答两个不同问题：内存队列 `IsGenerating`（此刻是否有回合在跑/在排）+ **末行的耐久状态**（线程自己的尾巴是否终态——硬崩溃留下的 pending/streaming 行不是可叠着重试的东西）。两者都用**既有** `STREAM_IN_PROGRESS`：一条非终态的尾巴**就是**一个（就耐久真相而言）仍在跑的回合，它不需要自己的码。无回合可重试 → 复用 `MESSAGE_NOT_FOUND`（message id 在此与 `?around=`/`:fork` 一样是坐标）。**本批零新错误码。**

**`modelOverride` 是逐回合的**：它随 `task` 走、在 `processTask` 里胜过 `conv.ModelOverride`，**绝不回写对话头**——「用别的模型再答一遍」是对**一个回答**的表态、不是改线程设置（那有它自己的 PATCH）；行的 `provider`/`model_id` 溯源随即记下究竟哪个模型产出了这个版本。

**`retryOf` 必须被重新种到 host 的 assistant message 上**（`task.retryOf` → `processTask`）：`WriteFinalize` **整体重写** Attrs，只在 `CreateMessage` 时写的 `retryOf` 会在回合收尾那一刻被抹掉；`failTurn` 同理收整个 `task` 而非裸 message id——一次模型解析失败的重试必须留住版本指针，否则那个失败的版本会渲成**多出来的一轮**而不是版本翻页里的一页（而用坏模型重试正是读者最需要翻回去的时刻）。

**SSE 不加新流、不加新帧型**（E1/E2）：`retryOf` 搭在**既有** `message` 节点的 content 上，**三处**——assistant 开场 `messageOpenContent.retryOf` · assistant **收场 `messageStopContent.retryOf`** · user 回声 `messageUserContent.retryOf`，三者都由 `retryOfOf(m)` 从 Attrs 读同一个源。它必须上线缆，因为一个**不是发起方**的客户端没有别的办法知道「正在到来的这个回合是**取代**屏幕上已有的那一条、而不是接在它后面」。

**收场那一处不是重复、是 replay 的唯一入口**（与上一条 `WriteFinalize` 整体重写 Attrs 是**同一种形状**）：E2 规定 Close 是 durable 帧、其快照即重连真相，而客户端从该快照**整体覆写** content。于是错过 open 的客户端——410 后 replay、中途连上的第二个窗口、任何重连——只凭这一份重建节点；快照缺了指针，它就被告知「本回合**接在**上面那条后面」，把被取代的版本与它的替代者渲成**连续两轮**（同一个问题答两遍、且没有版本翻页）。守卫两层：`retry_test.go` 的 `TestRetry_CloseSnapshotCarriesTheVersionPointer`（穿过真 JSON 读，故不会被一个永不序列化的字段蒙混）+ testend `TestChatRetry_VersionChainWalksOnTheWire` 的 SSE 半（**仅凭 close 帧**重建整条向后链）。

**同族过滤的另外两处**（都不是 token 优化、是诚实）：① **contextmgr 的压缩读**在唯一读点丢掉被取代的回合——否则装配过滤就有一个**单向阀式的洞**：`LoadThreadForLLM` 把被重试掉的回答挡在历史之外，可一旦它被折进 `conversation.summary`，内容就会**回流**进此后每一次 prompt，而摘要不是后面某个过滤器能收回的话（顺带让 `protectedFrom` 数的是真回合、不是版本）；② **`buildAnchors` 跳过被取代的回合**——transcript 把旧版折进版本组、只渲一行，故给某个版本建锚点要么让节选重复（「你说了两遍」）、要么给出一个跳向屏上并不存在的气泡的跳转。**`SumTokens`（usage）刻意不过滤**：那些 token 是真花掉的。

**分叉 × 重试的交汇**（CH-b × CH-c）：`Fork` 必须把**message id 也预铸**并 remap 两个版本指针（`superseded_by` 与 `attrs.retryOf`）——保留源 id 的复制会让分叉的版本链指进源线程，而**丢掉** `superseded_by` 更糟：它会把每条被复制的行重置成「现行」，于是模型拿到同一个问题的**两个**回答。被前缀窗**切掉**的取代者留下零值，这恰好正确（在分叉里，既然更新的版本根本不在，该行**就是**现行版）；目标落在窗外的 `retryOf` 被**丢弃**而非留成悬空指针。

## 3.6 驻地（对话工作目录）的 chat 侧三件事（WRK-077 WD1）

驻地本身是 conversation 的一列（见 [conversation.md](conversation.md)）；chat 拥有它在**回合里**的三处兑现。

**① ctx 播种**：`processTask` 在**读头行之后**、`loop.Run` **之前**种 `reqctx.SetWorkDir(ctx, conv.WorkDir)`。顺序承重两次：那一列是真相源，且「中途切换在**下一**回合生效」正是驻地按钮对用户的承诺（按钮因此在生成中**不禁用**）。从 `ctx` 派生保住回合的超时与 cancel。

**② 每轮 system prompt 带一段 `work_dir`**（`prompt.go`，紧邻 `environment`——它**就是** environment：本回合「这里」是哪儿）：路径 + 分支（若是 git 仓库），随后三句话——相对路径以此解析、Bash 从这里起步、**「你仍可用绝对路径读机器上任何地方，这是焦点、不是限制」**，最后点明往外写会先问用户。诚实陈述 zoom 是必需的：一个被暗示自己被关起来的 agent 会拒掉它本被允许做的事，然后为此与用户争辩；而一次没被预告的强制确认读起来就是一次随机卡顿。**只跑廉价 git 探针**（`rev-parse --abbrev-ref HEAD`，O(1)）——**脏态刻意缺席**：它要走整个工作树、在 prompt 与模型首次工具调用之间本就会变，而模型自己跑一次 `git status` 即可；驻地**路径**才是它无从自行发现的东西。未挂线程该段为空、`buildSystemPrompt` 丢掉空段，故**未挂线程的 prompt 与 WD1 之前逐字节相同**（`GET /{id}/system-prompt-preview` 复用同一函数，故预览与模型所见仍逐字一致）。

**③ subagent 继承（拍板 #7）——免费**：`subagent.Spawn` 的子 ctx 由父回合 ctx 派生，故驻地原封不动带过去，**零管线代码**。这正是驻地住 `reqctx` 而非 `AgentState` 的原因：子运行**刻意**拿一个全新 AgentState（不污染父 `SeenFiles`），存那儿会被静默丢掉，于是父线程 zoom 在某处、subagent 却开始把相对路径解析到虚空。`pkg/agentstate` 的包注释已就此重述（旧文写「桌面 agent 无工作目录，shell 不引入 cwd」）。

**④ 中途切换的 `marker` 块由 chat 写**（`MarkWorkDirSwitch`，即 conversation 的 `WorkDirMarker` 端口——消息归 chat）：一个合成 assistant 回合 + 一个 `marker` 块，与 compaction 锚（`contextmgr.writeAnchor`）**完全同形**，因为两者答的是同一类问题：关于**这段对话**的某件事在两个回合之间变了。**刻意不发 SSE 帧**——该块随普通 `GET /{id}/messages` 读回，故 [events.md](../events.md) 的 messages `node.type` 词表分毫不动、E1/E2 成立；正看着线程的客户端靠 PATCH 本就广播的 `conversation.work_dir` 回声重读。**空线程不落标记**；`content` 恒空（标签客户端本地化）。它对模型不可见**不靠过滤**——`BlocksToAssistantLLM` 是类型白名单，marker 在里面没有 case。

## 4. 人在环

危险工具（LLM 自报 dangerous）/ `ask_user` 在 loop 内**阻塞**于 humanloop broker。chat 注入的 Surface 把待决交互推成 messages 流的 **ephemeral** `interaction` 信号（即时弹出）；**broker 内存 pending 表是真相源**——重连客户端走 `GET .../interactions` 重新同步。`ResolveInteraction` 先校验 action 属封闭决策集（approve/approve_always/deny/accept/decline，枚举外 → `422 INTERACTION_INVALID_ACTION` 带 `details.validActions`，先于 broker 查找就拒——loop 门是 fail-safe，非 approve 一律拒，故拼错的 action 不再无声拒掉一个危险工具），再把决定交给 broker（approve 跑 / deny 反馈 / approve_always 加**对话级会话白名单**——active skill 的 allowed-tools 也是预授权来源）；重复 POST 安全（`NO_PENDING_INTERACTION` 404）。broker 经 ctx 流入嵌套 agent 运行（嵌套不冒泡，阻塞的 goroutine hold 整栈）。broker 是 **app 级单例**（比任一对话活得久），故 always-allow 白名单按 `conversationID` 键、**对话删除时经 `ForgetConversation` 钩子（conversation 删除级联调）整批清掉**——否则授权会越过删除永久泄漏在内存里（与 stream-stop 的 `Cancel` 区分：后者只停在途生成、对话仍活、保留白名单）。

## 5. freeze-on-send（@提及）

发送时**快照**被 @ 实体的内容（function 代码/handler 类/agent 描述/文档正文…经 mention registry 解析）进 user 回合 Attrs——之后实体再改不影响已发送回合的语境。渲染进 LLM 历史时从快照读。快照落定后 Send 同时把 @提及/附件记进**对话触点台账**（`mentioned`/`attached`，actor=user、锚 user 消息——`app/chat/touches.go`，best-effort；AI 侧触碰在 loop 工具咽喉记，见 [touchpoint.md](touchpoint.md)）。

## 6. 契约（引用）

端点（send/cancel/**retry**/interactions/usage/system-prompt-preview/messages 三读形态[cursor·around·dir=newer]/anchors）→ [api.md](../api.md) · 码 4 个（`EMPTY_CONTENT` 400 / `STREAM_IN_PROGRESS` 409 / `NO_PENDING_INTERACTION` 404 / `INTERACTION_INVALID_ACTION` 422）→ [error-codes.md](../error-codes.md)（**`:retry` 不引入新码**——非终态末回合复用 `STREAM_IN_PROGRESS`、无回合可重试复用 `MESSAGE_NOT_FOUND`，见 §3.5）。注：message 行的 `error_code` 字段（如 `LLM_RESOLVE_ERROR`/`MAX_STEPS_REACHED`）是**回合级错误码**（前端展示），与 HTTP wire code 是两个命名空间。

**导航锚点（`GET /{id}/anchors`，场次条）**：`chatapp.ListAnchors` 归属前置校验后走 `ListAnchorSource` lean 扫描 → `buildAnchors` 建锚（oldest-first）→ 反转 newest-first → 内存 keyset 分页（游标键 `(at, blockId|messageId)`）。锚点分类学（业界收敛 + WRK-061）：**人类内容是主锚与硬边界**——`user`（回合首行节选 ≤120 rune）；锚点间连续非危险 tool_call 折叠为一条 `tools` 簇（count 计数、钉簇首块，跨回合可并）；`danger`（attrs.danger=dangerous 逐条露出，title=工具名·entityName）/ `compaction`（块型）/ `abnormal`（回合 status error/cancelled，title=stopReason→errorCode→status 回退）同样打断簇；`gate`（待决人闸）来自 broker.Pending——**无日志行的活状态**，只前置首页顶、不占 limit、置身 keyset 之外（重连本就重拉首页）。落在 chatapp（而非独立 service）正因 gate 只有 broker 可给。

## 7. 跨域集成

消费：conversation（线程配置）/ messages（持久化）/ loop（引擎）/ toolset（resident+lazy）/ attachment（多模态渲染，按模型 caps 门控；内置 Anselm 网关的图片/MP4 先换成短期 remote media lease URL，聊天 wire 不含原始 base64）/ memory·catalog·document（各贡献 system prompt 一段，连同 user 自定义 prompt + **work_dir 段（驻地，仅挂载时，见 §3.6）** + environment + 静态规则段 + `conversation_management` 段[声明压缩自动·无手动 compact 按钮·归档/置顶走 `manage_conversation`，杜绝 agent 臆造按钮，F38]组成完整 prompt）/ todo（reminder）/ model（resolve）/ contextmgr（**压缩全自动、无手动路由**——每次 sampling 即时治理 + 回合收尾 durable 检查，无 LLM 工具/UI 按钮可手动 compact）/ humanloop（broker）。被消费：`invoke_agent` 嵌套呈现（E3）、subagent 落 sub-message、aispawn 的 `:iterate`/`:triage` 开对话。
