---
id: DOC-051
type: reference
status: active
owner: @weilin
created: 2026-07-08
reviewed: 2026-07-08
review-due: 2026-10-06
audience: [human, ai]
---

# Chat 右岛「侧幕 Sidestage」——当前形态

> chat 海洋的右岛(V8,WRK-061 建成,W0–W7 全落)。**AI 干活时右岛自动活起来**:工具流入即登台直播、落定谢幕收进触点台账。建造规范与逐决策记录见归档 [`WRK-061`](../../../archive/chat-right-island/README.md);本文只陈当前物理事实。

## 0. 存在条件——右岛按需存在（用户 0718-19 拍板）

**有 Activity 才有右岛**：空对话的右岛按钮 = 通向墓碑的门,故无内容→无门。

- **判定源** = 侧幕自己的四条数据源、逐条镜像 `_AccordionList` 的非空判断(`state/sidestage_activity_provider.dart` 的纯函数 `sidestageHasContent` + `sidestageActivityProvider(id)` autoDispose family):触点台账有实体行(或首拉失败→错误+重试面,亦是内容)∨ 活舞台主角/频道 ∨ 待办板 ∨ 落定 subagent(无触点,transcript 是唯一真相)。**裸人闸刻意排除**——`ask_user`(唯一无舞台无实体的闸)内联渲于对话流、不在侧幕,计它会让「按钮亮点开却空」。`AppShell` 以 `chatConversation != null && sidestageActivityProvider(id)` 组进 `hasSelection`,故右岛 + `onToggleRight` 皆 activity 门控;本 provider 在选中会话时保活台账/导演器/场记(岛开或闭),这让 activity 一到按钮就反应式亮相。**每帧成本 O(1)(S7)**:transcript 在写入点维护 `subagentEpoch`(Subagent tool_call 开/合、settled 窗换代才自增,流式 delta 不动),活动旗的 `_onTranscript` 与手风琴的重建判定都只比对这个 int——旧法每个合并帧全树递归 `subagentBlocks` + 分配(随会话线性);`subagentBlocks` 本身也按 epoch 记忆化,结构未变返回同一 list。
- **头部控件位置语法**(`AnShell` 头尾槽):新成员从尾端插入、旧成员左移。**场次条 Scenes**(`TranscriptToc`)对任一选中会话恒在(与 activity 无关);第一条 activity 到达时 **panel-right toggle 经 `AnExpandReveal(axis: horizontal)` 自尾端横向滑入**、把 Scenes 往左挤一格(「挤」是真实位移;登台即在则即时,reduced 即时)。
- **首个活动是否自动开岛 = 跟随三档说了算**（缺口A,用户 0719 改判——旧 WRK-065「运行中绝不自动弹窗」的立场现收编为「从不」档）:**chat 桶默认收起**（`rightPanelCollapsedProvider` 唯 chat 默认 collapsed,余海洋默认开）,会话**首个登台活动**到来时——`always` / `每会话首次` 档**自动开岛**、`从不` 档不开（按钮亮、只点亮 R-15 activityBit）。机制 = `state/sidestage_auto_reveal.dart` 的 `sidestageAutoRevealProvider(id)`（`AppShell` 在选中 chat 会话时 bare-watch 保活,故岛开或闭都在跑）:观 `stageDirectorProvider.stageOpen` **false→true** 即 `rightPanelCollapsed.set(false)`——**导演器已按同档 gate 登台**（`never` 从不 stageOpen→从不开岛,`每会话首次` 只登台一次）,故揭示随该 gate、显式 `never` 守卫只作兜底。**尊重手动关**（WRK-065「别做成关不掉的弹窗」):用户本会话把**可见**侧幕关过后,该会话记入 `sidestageManualCloseProvider`（keep-alive,不再自动弹）;仅在面板确在屏（有 activity）时记,故切海洋翻桶不误记。用户点开后照旧按海洋桶粘住（W7 持久化不变）。切到无 activity 对话:岛收、按钮隐、Scenes 回位。

## 1. 结构(自上而下)

`StagePanel`(`features/chat/ui/stage_panel.dart`,`AppShell` 在 chat 海洋**有 Activity**时挂进右岛,见 §0):

| 段 | 物 |
|---|---|
| 头带（§1 身份头 + §2 速览带,三段式文法 · 0719） | **`AnPanelHead`**(core/ui 原语):脉冲/活动 icon + 「活动」标题 + **单个 ⋯ 溢出菜单收编一切面板动作**(跟随三档[每次/每会话首次/从不,持久化 `fy.stage.follow`,settings 模块读同一 `followModeProvider`]· 展开全部 · 收起全部;退役旧「四小钮」) + ✕ 收岛。头下一行 **§2 速览带**:一行安静 `AnText.meta`「N 触点 · M 执行 · K 待你处理」——N=触点台账实体数、M=执行过的实体数、K=`pendingInteractionsProvider` 待决数;**零人话律=有真信号才在**(每段 `>0` 才现、全零整行不渲) |
| 频道条 | `AnChannelStrip`(≥2 并发活动时,cap 4 + 溢出;点 tab=pin 换台;failed 挤台成红点 tab) |
| 舞台 | `AnExpandReveal` 揭示 `_GenericStage`(眉+诚实丝带+kind 量身体);poll 型主体带**活运行卷**(`_RunProgressSection`:flowrun 节点 tick 逐行静落,AnLedgerRow 行+语义状态点(WRK-066 批6,字形三态退役)+选中 `port` accent 徽,≤12 行,durable 终态一行收卷);**exhibit 置位时让位 `ExhibitStage`**;舞台体内点击/拖动=**G2 行级认领**(该行移出自动展开账本、谢幕绝不收正在读的行;导演器照常流动,只认用户手势) |
| Rundown | `_RundownSection`(`AnTaskRing` 补弧 + `AnRundownList` 三态行,todo 整表帧,按 subagentId 分板) |
| 演员表 | `_CastList`(触点台账 R-2 实体聚合行:`AnCastRow` 新鲜度晕+动词微词+×count;**hover 尾位换双微动作**「跳到发生处」(''=藏)/「去实体页」(无面板即藏);**点行=exhibit 登台**;主角行 R-6 静态脉点;**谢幕落账洗亮** ~1.8s 衰减) |

> **§3 分组内容（三段式文法 · 0719）**：侧幕**落定 Cast**（触点台账实体行）按**时间三档**折叠（照通知托盘的精神、用对话的刻度）——**刚刚**（本回合）/ **早些时候**（今天更早）/ **更早**（跨天），键 = 行的最后触碰时间 `lastAt`（纯分类器 `sidestageTierKey`，`stage_group_collapse.dart`）；档序**刚刚→早些时候→更早**，档内**最新先**（复用台账 freshest-first 排序）。组头 = **AnRow 组头文法**（常驻箭头 lead + 计数 meta、**无 ⋯**，与左岛 Pinned/Recents 头、通知托盘时段组头**同一语言**）。**两条防碎律**：①空档不渲组头 ②**只剩一档时连组头都不渲**——整列裸行（全「刚刚」时分组即噪音，零人话律；短对话干净一列、长对话自动分层）。**todo 行 + 活/委派层（合成 live 行、落定 subagent）恒不分组置顶**（活层不与档折叠打架，保「live 骑顶」不变式）。档折叠态 `stageGroupCollapseProvider`（**与行级 `stageExpansionProvider` 正交**——档折叠=新顶层态、粘性手风琴管行内展开，两层互不干扰）；**含 live / 被自动展开（导演器/深跳）行的档强制展开**，绝不藏活（`test/features/chat/ui/stage_grouping_test.dart` 测锁）。**折叠动效**：每档整合成单 list item（`_buildTier`：组头 + `AnExpandReveal.builder` 裹档内行），折叠/展开走 **kit 标准收合滑动**（chevron 旋转 + 高度滑动同播，reduced 双闸即时，与全 app 一致）；**强制展开（深跳/导演器）翻 `open` → reveal 播同一滑动**（声明式，非命令式）。**「刚刚」取径**：R-14 回合锚需 transcript 节点时间戳，但 `hydrateTurn` 丢弃 `createdAt`、`BlockNode` 无时间戳 → 回合锚在 accordion 数据上取不到 → 用**固定 10-min 窗**代「本回合」（用户 0719 授权的退化取径）。日界（早些时候 vs 更早）= 本地日历天。

## 2. 引擎与状态

- **`StageDirector`**(`model/stage_director.dart`,纯状态机):**三态 idle/following/failedHold(G2 镜头锁退役)**——旧 pinned 一次体内点击即冻结整条自动登台流水线且无任何解除入口、curtain 声明而不可达,双双删除;**用户所有权改为面板行级认领**(体内点击/拖动把该行移出 `_autoOpenedRow` 自动展开账本→谢幕绝不收正在读的行,导演器永远流动)。500ms 登台防抖(短操作永不登台)、800ms 静默+2400ms 驻留换台仲裁、优先级 humanGate>build>execution>subagent;failed 驻留红纱。**行头状态四态派生(G3)**——live(蓝点「进行中」)/ polling(蓝点「运行中」,R-10 关帧后 flowrun 仍在跑)/ settling(绿点「正在落定」,1.8s 停拍)/ failed(红点「失败」)——一律从 `StageActivityView` 自身真相派生,「导演器还记着」≠「活着」;失败行 hover 亮**行级清除**(`onClearActivity`,失败驻留的唯一出口——旧失败活动永久滞留渲蓝「Live」且无出路);「正在执行 N 项」只数真 live 调用;行头命名单源(live/落定同一条派生,分身行读任务名缝,行绝不在落定瞬间改名)。**落定谢幕收行**（缺口B,用户 0719 改判）:following 主角落定 → 停拍（`settleBreath`≈1.8s 停留让人看清结果）→ 无接场则收场（subject→null）→ `StagePanel._onDirector` 把**自动展开的那行**动画收回台账行（同一 `AnExpandReveal` 收合滑动 + 既有落账洗亮）;**只收自己自动展开的行**(`_autoOpenedRow` 记账),且 **G7 三法**:①收行按**活动个体**触发(该 blockId 离开 subject∪channels 即收自己那行——旧「subject 归零」只盖最后一幕,接场全漏、右岛渐成全展开墙);②键迁移**全员化**(subject 与 channels 一视同仁,`block:` → `kind:itemId` 时展开态与账本同迁——旧只迁 subject,用户展开的频道行在解出瞬间当面合上);③自动展开**绝不认领用户已开的行**(旧认领把用户的行列进谢幕收起清单)。用户自展/认领(G2)的行、failedHold 定格天然豁免。**身份单源(G7)**:itemId 只在宿主一处解析——参流关帧取**顶层**常规键(深搜曾被 workflow ops 节点 id 假命中)+ 执行回执顶层 id(创建落地即与台账真身行合流——旧显示名兜底铸出永不合并的键、同一实体永久双行)+ 名寻址白名单(skill/memory/mcp,台账本按名建键);舞台体内零 id 猜测。`LifecycleSource` 三型——toolClose(常规)/poll(`trigger_workflow`:202 关帧绝不谢幕,**驻留到 durable `run_terminal` 到达**——`onRunTerminal` 净→停拍谢幕、败→红纱,R-10 已退役)。
- **宿主 `stageDirectorProvider`**(`state/stage_director_provider.dart`,autoDispose family):会话帧投影(tool_call open/delta/close)+ 人闸旗 + 唯一闹钟 advance(到期时刻);**poll 记账**——工具名留自 open、workflowId 解自关帧 args、flowrunId 解自入队回执,按 `workflowFrames(workflowId)`(entities 流 scope 订阅)听 `run_terminal` **按 flowrunId 匹配**并把节点 `run` tick 喂进 `flowrunProgressProvider`(tick 绝不猜——错 run 的进度是谎言,缺卷只是缺口)。**G5 真相对齐**:导演器按 `subagentEpoch` 变化(水化/410 重同步换窗、分身开合——稀有事件、绝不逐 delta)对照 transcript 全部 live 根**重新接地**——流缺口吞掉终态留下的「Live 幽灵」被清扫(只清导演器认为 live 而真相说没在执行的;停拍/poll 驻留/失败红行豁免),水化种进来的在飞调用走正常防抖重新登台(重载后跑着的分身不再无行);poll 关帧后未见 `run_terminal` **不离场**(202 只是回执——旧非主角被当场错杀,终态到达时无人认领),终态监听只在派发成功后装(错误/取消不装表,免被无关 run 洗白);poll 账本拆双义(calls/workflow 两账);provider build 重入先清旧订阅/闹钟/账本。已知诚实降级:410 缺口跨越期间的 run 活卷不重建(卷宗归 scheduler 海洋),幽灵则绝不留。`followModeProvider` 持久三档。**G4 执行相位单源**:侧幕一切判活(`StageScene.live`/分身卡/通用体)走 `ToolCardPhase`——tool_call 关帧只是参流收束,真执行终态=tool_result close(与中央工具卡同源);cancelled 结算渲中性记号、绝非成功绿勾;嵌套子块(result 下 progress、分身嵌套树)开帧与 delta 经属主映射喂回所属顶层工具的活性钟(执行中的主角不再被判静默丢台),delta 不发布也不再逐帧拆装闹钟。**G6 嵌套过滤**:分身体内的 tool_call(经属主映射判定嵌套于被追踪顶层调用之下)不入导演器——旧行为按优先级(build>execution>subagent)反超自家分身抢台、铸幻影行、点亮 R-15;现只喂属主活性钟。
- **`touchpointLedgerProvider`**(`state/touchpoint_ledger.dart`):R-2 (kind,itemId) 聚合、durable 触点信号直 patch(绝不过 CoalescingNotifier)、410 重拉首页并入、keyset 无限滚。
- **`exhibitProvider`**(`state/exhibit_provider.dart`):用户钉的 Cast 展品——**刻意在导演器之外**(StageActivity 只能由 tool_call open 出生);`ExhibitStage` 美术馆开灯入场,attachment=**展品座**(缩略图+size/mime/sha256 前缀 mono),实体=身份面(id mono+动词史 KV),墓碑静态;驻留到关闭。
- **`rundownProvider`**:todo 整表替换直 patch + GET 水化。
- **R-15 activityBit**:右岛收起时,`AppShell` 以 `stageDirectorProvider.select(channels.any(live))` 点亮 `AnShell.rightActivity`(panel-right 钮柔 accent 点)。

## 3. 12/13 kind 量身舞台(`ui/stages/`,registry `stage_registry.dart`)

fn(地层→OpTicker[**三态点**:live 空心/落定 ok/失败中性——失败不演成功,G10]→活代码窗→落定真 diff 徽[before=G9 冻结基线])/document(书脊+前缀快进[记账代际=编辑块id+基线长,同文档二次编辑不再串账,G10]+R-9 元数据卡;「全量替换」徽两端同为**字节**;`[[id]]` 内联药丸经 `stageMentionNamesProvider` 走 composer/编辑器同一条 MentionSource 缝**解真名**,解不出回落 id;id 集键按被渲切片算——流式绝不每帧扫兆级正文)/workflow(真画布图生长+判别式抽屉;update_node 线缆形=顶层 `id`+RFC-7396 `patch`,判别式只吃 `patch.input`;**edit 的 ops 重放在旧图上**[增/改/删节点与边,不再塌成孤岛]、地层墨与「基于 vN」仅 live、**落定 edit 画布对账新鲜真相**,G10)/control(丝线决策梯+透传幽灵+否则徽)/approval(信笺+琥珀插值+timeout 人话[**settle 面同一开关**,不再漏英文裸枚举];失败面**不盖**「预览·尚未寄出」幽灵章、改红标「创建失败·残稿如下」,G10)/trigger(四脸+R-16 落定只信 GET;**edit 无 kind[不可变]——live 期经 R-5 取旧真相换脸,编辑全程不无脸**;nextFireAt **按分钟活钟**重渲,无动画)/subagent(**一席一卡,G1 群像退役**——手风琴行即群像,行体只渲本行分身;**任务名=args.prompt 首行**[schema 只有 subagent_type+prompt,无 description];单席 ReAct 尾+**结算双源**[live=嵌套子消息关帧的 inputTokens/outputTokens/stopReason,重载=REST 折叠抬升键;无话可说 footer 不渲];卡内联**终端活窗**——分身当前工具流出 progress 时尾部就地滚动 ≤10 行,「一整页是终端用的」的克制版)/handler(方法架;set_init_args_schema 线缆键=**args**;update_method=`name`+RFC-7396 `patch` **合并上架**[旧读整 method 对象,update 全被丢];timeout 渲**钟词**[30000→30s];轨段/书脊头/schema 药丸归假想框 X=8,G10)/agent(R-9 未提及槽 40% 旧真相——**prompt/tools/knowledge/model 四槽全铺**,落定后未触槽回全墨[未触=旧值即现值];落定 prompt **有界视口内滚动**;modelOverride=**对象** `{apiKeyId,modelId}`,G10)/skill(装订台+allowedTools 琥珀**仅在信任门已批时**——未批安装渲中性+「已请求·未批」文案[toolsApproved 经真身投影传入],G10;$ 占位槽)/memory(记忆笺,图钉 REST-only)/mcp(接线现场+工具货架——**货架=类型化读安装/重连回执的 `tools` 列表、仅接线调用**[install_mcp_server/reconnect_mcp/create_mcp];执行调用 mcp__* 铭牌=工具名,业务结果绝不冒充货架)。conversation 不设舞台;attachment=exhibit 展品座(无建造工具入口)。共同律:**G1 立法——舞台体只消费本行 `StageScene`、禁 watch 导演器全局态(subject/channels)**;**G8 键律——舞台体读取键与后端工具 schema/线缆逐字同源(禁猜键、禁正则捞结果文本、落定读数走类型化 `resultObj`),fixture 帧形=真线缆(守卫测试断言 demo 的 tool_call 关帧快照键集 ⊆ 后端快照键集 name/arguments/summary/danger/entityName)**;R-4 live 禁成功语义、R-5 edit 登台即 GET 旧真相、R-9 渐进开区、R-12/13 有界动画窗;**G9 真相代际两律**——①build 工具执行终态即 `invalidateTruth`(kind,id) 失效对应 truth provider(「看真身」/R-16 从此永远新鲜——旧暖缓存可无限期端出编辑前快照);②R-5 消费者(diff 徽 before/静置旧图/前缀快进基线)改读**编辑基线** `<kind>BaselineProvider((id,block))`——按编辑块冻结、取到即 keepAlive,真相失效绝不把真 diff 洗成 +0−0(同一实体、两种新鲜度契约、两族 provider;trigger 刻意留活真相:kind 不可变 + R-16 要新);**假想框律**(WRK-070 §A#1,`ui/stages/stage_frame.dart`):每个块逻辑上住在一个框里——真框(`AnWindow`/`AnCard`/`AnCodeEditor`/`AnLayerDiff`/着色丝带)满宽贴 X=0、绝不二次缩进;**体内除真框满宽外,一切裸内容(文字/沟行/chips/梯)左缘统一从 X=8 起**(=AnKv 键 h:s8 线)。裸文字(墓碑/timeout/error/计数句/提示句)归**假想框** `stageFramed`;chips 与判别式梯同律(control 整梯+旧地层、function op ticker+签名药丸、agent 腰带/知识/模型、mcp env 键、workflow 计数+判别式抽屉、document 路径 chip+前缀 caption、trigger spec 面+CEL+等待行皆经 `stageFramed` 归 X=8);icon 行归定宽 iconSm **沟** `stageGutterRow`——**沟格自己也住在假想框(从 X=8 起,不再顶格贴岛缘)**、icon 对 icon 光学居中/文字对文字(mcp 铭牌·工具行·计数句、approval 预览行归此;**唯 subagent 卡内尾行 `framed:false`**——已在卡 `AnWindow` 内距里、免二次缩进越过卡头字形)。control 梯的序号沟、document 书脊、trigger 双雷达等 stage-local 结构件保留原锚(梯整体右移到 X=8、书脊仍 X=0)。

## 4. 导航(W6)

- **transcriptJump「re-anchor」**(`state/transcript_jump_provider.dart` 命令通道,`chat_transcript.dart` 唯一消费):近跳=`retargetCenter` 移锚零拉取;深跳=`?around=` 窗**整扇替换**(目标即 center sliver 首行,零 extent 估算)+双向续翻(`olderCursor`→`?cursor=`/`newerCursor`→`?dir=newer`)+「回到现场」pill(发送隐式离窗;`backToLive`=410 重同步同径;**归队即重钉贴底**——快速重拉可不换 State、转变显式重钉,否则读者被晾史中[真机抓获的真 bug,组测钉死]);落点洗亮 hold+fade;**跳转即解钉——流式帧绝不夺视口**(组测验收)。
- **场次条 `TranscriptToc`**(`ui/chat_toc.dart`,目录钮经壳 `AnShell.headTrailing` 槽渲于浮层头右缘、紧贴右岛开关钮左侧——`app_shell.dart` 喂入,**非**在 `ChatHead` 内容里):`GET /{id}/anchors` 全量锚点(循环分页),gate 琥珀置顶>newest-first 时间线(user 主锚加粗/`tools`「⚙ N 项操作」折叠簇/danger/compaction/abnormal 逐条),点锚=jump+自收;抽屉高 560(导航面配得上高度——一眼更多场次);fixture `listAnchors` 镜像 broker 规则(未决 interactions 骑首页顶),demo/测试同真。
- **R-14**:落定舞台眉部「跳到发生处」=`ConversationTranscript.messageIdOf` 走父链到回合锚(role 式 Subagent 台账无影,这是它唯一的锚)。

## 4.5 可发现性

图标控件(目录钮/头 ⋯ 溢出[跟随三档·展开/收起全部并入此]/Cast 双微动作/exhibit 头动作/R-14 眉锚)全带 **`AnTooltip`** 或 semanticLabel(kit 新原语:Flutter Tooltip 机制穿设计系统皮——岛面+发丝边+meta 档,500ms 才现,无箭头无富体;gallery 有 specimen)+ semanticLabel。

## 5. a11y 章

四播报(`SemanticsService.sendAnnouncement`,polite):登台/人闸/失败/落定;live 流式区 `ExcludeSemantics`(播报+落定真相载义);全交互件带 semanticLabel;循环动效(FollowPill 呼吸/雷达环)骑共享 `PulseClock` 且 reduced-motion 冻结;洗亮/开灯等一次性动效 reduced 直落终态。

## 6. 契约(引用)

窗/锚 DTO 与 repo 缝 → [`contract.md`](../contract.md);后端 `?around=`/`?dir=newer`/anchors/`run_terminal`/tick `port` → [`references/backend/api.md`](../../backend/api.md) · [`events.md`](../../backend/events.md);触点台账 → [`domains/touchpoint.md`](../../backend/domains/touchpoint.md)。性能地基(增量 JSON 会话/revision memoize/PulseClock)与 perf 门禁 → 归档 WRK-061 §5/§10-W0。

## 7. 取舍与裁决(全部已清账,无待办)

**已实现(0708 清账批,口味=流式展示/显示舒服/企业级)**:活运行卷(poll 舞台 flowrun tick 覆层,本页 §2)/`AnTooltip` 原语+全控件应用(§4.5)/nextFireAt 分钟活钟/舞台滚动=pinned/`[[id]]` 真名解析(MentionSource)/subagent 内联终端活窗/场次条加高+fixture gate 镜像/demo 补种(60 回合长卷+附件展品座静物+trigger_workflow 运行卷一幕)。

**已裁决不做(与「不花哨」口味一致,非欠账)**:词级淡入与快进滚动完整动效版(业界流式标准即纯追加,稳定优先)/完整 AnCurtainCall 飞入行编舞(现=reveal 收起+落账洗亮已足)/dagre 增量布局+fitView 跟拍+FLIP 节点滑移(边线 CustomPaint 直绘目标位,节点滑行期箭头脱节 240ms 视感如 bug——瞬时重排是 graphviz 业界常态;活边 comet 已在实体页画布)/水脉闪舞台加戏(实体页画布已有 comet)/update_node 脉冲(op 已在判别式抽屉文本可见)。

**G10 已裁决暂缓(记录在案,非欠账即小账)**:handler 在途 body 的**逐书脊跟随**(现仍只在首方法闭合前渲在途窗——W0 路径通道地基具备,接线归后续)/真身画布 **pos 保真**(sceneFromTruth 的 workflow 投影不带 pos → 自动布局;落定 edit 已改走 graphParsed[带 pos],纯真身渲染仍自动布局)/agent knowledge 芯片**解名**(现渲裸 doc id;解名走 MentionSource 缝归后续)。

**真机边界(记录,非账)**:合成 CGEvent 滚轮/焦点进不了 Flutter 弹层——深跳窗与抽屉深滚的真机帧靠手动复核;gate 锚真机需真后端人闸(fixture/组测已镜像钉死)。
