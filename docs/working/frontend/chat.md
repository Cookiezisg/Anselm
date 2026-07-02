---
id: WRK-050
type: working
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-06-30
review-due: 2026-09-28
audience: [human, ai]
---

# Feature:Chat(对话海洋)—— 建造文档(在建)

> Phase 4.2,接 Entities 之后的第二个真 feature。**当前**:左岛 rail 已落(STEP 0–7);**中心海洋(对话正文 + composer)未建**——是下一步主战场。本页是 chat 的活建造账,建完 → 结论提取进 `references/frontend/features/chat.md`(届时新建)+ 本页归 `archive/`。背景见 [`overview`](../../references/frontend/overview.md);hub 见 [`README`](README.md)。
>
> ⚠️ **旧 chat 线只活在 `backup/chat-phase-20260629` 分支**(老前端的完整 chat:transcript/composer/人在环/demo-parity,1037 测)。当前 `frontend-rebuild` 是**换新设计系统 + 新三岛壳从头重建**,以 backup 为**决策/模式强参考**、不照搬实现。

## 一句话 + IDEAL

一个**永远活着、跟手、不让你想「我在哪」的对话体验**。rail 是平静的常驻列表;中心是顺滑的对话正文。= ChatGPT 顺滑 + 活态点 + Claude 归档灰点 + Linear 跟手实时。**行永远单行**(状态点 · 标题 · 时间/⋯),**无消息预览/摘要**(项目无摘要概念)。

---

## A. 左岛 rail —— ✅ 已落(STEP 0–7)

**当前形态**:`ConversationRail`(`features/chat/ui/conversation_rail.dart`)over `AnSidebarList`,**完整镜像 entities rail**:

- **两组**:置顶(pin 图标)+ 最近(history 图标),单一 `SidebarType` 头路径(图标 + 计数右对齐 + 行缩进),**无时间桶**。每行 = `状态点 · 标题 · 相对时间`。
- **状态点**(`conversationDot`,优先级高→低):🔵 生成中(`isGenerating`,唯一呼吸)> 🟡 等你输入(`awaitingInput`)> 🟢 答完未读(`hasUnread`)> ⚪ 已归档(`archived`,仅显归档时)> 无。
- **⚙ 菜单**:排序(activity/created/name → 服务端 `?sort=`)+ 显示开关(显示已归档[重取]/分组计数/时间)。
- **⋯ 行菜单**(STEP 7,hover 显):重命名(**就地改名**,复用 `AnInlineEdit`)/ 置顶·取消 / 归档·取消 / 删除(danger + 确认弹窗)。写打后端 PATCH/DELETE,发起端拿响应**乐观更新**列表(`applyUpdate`/`applyDelete`,幂等),不等 SSE。
- **数据缝** `ChatRepository`(Live/Fixture/`chatRepositoryProvider`);**列表 state** `ConversationListNotifier`(分页 via `KeysetQueryPaging` mixin + sort/archived watch 重翻 + 乐观 patch + notifications 实时重排);**选区** `/chat/:id` 路由派生。
- **实时生命周期**(✅ 本片落):`ChatRepository.lifecycleSignals()` 投影 notifications 流的 `conversation.<action>`(`ConversationSignal`,镜像 entities `EntitySignal`;payload id=`conversationId`);`ConversationListNotifier` build 订阅 → `_onSignal` reconcile:`deleted`→drop、`created`→取回前插、其余(`updated`/`auto_titled`/`archived`/`pinned`/…)→`GET /{id}` 重读 + `applyUpdate`(就地替换 / 隐藏时移出归档 / 重分置顶)。仅 `durable`(seq>0)生效、幂等(与发起端乐观写重叠安全)。**注**:活动点(生成中/等你/未读)的流转**不在** notifications 词表,由 messages 流驱动 → 随中心海洋(§B)一起活。

**后端 rail 能力(已就绪、已消费)**:`?sort=name`(orm PageAsc NOCASE)· `awaitingInput`(humanloop 派生 bool)· `hasUnread`(持久布尔列 + `POST :seen`,免时钟比较)· `ArchiveScope` 三态(`?archived=all`)。`lastMessagePreview` 已删(无预览)。

**rail 写契约**(Explore `a33793ae`):rename/pin/archive 全 `PATCH /api/v1/conversations/{id}` **单字段**(`{title}`/`{pinned}`/`{archived}`)+ `DELETE`(软删 204);走 **notifications 流**回声、**无 echo 抑制**(合并须幂等);title 后端零校验(前端挡空)。

**rail 尾巴**:✅ 无限下滑(`AnSidebarList` 虚拟化 + `onLoadMore` → `loadMore`,`pageKey='recents'`)· ✅ 跨客户端 notifications 回声合并(见上「实时生命周期」)。**唯一剩项**:活动点(生成中/等你/未读)真正流动——由 messages 流驱动,随 §B 中心海洋一起做(rail 本身在无中心时已做到能做的极限)。

---

## B. 中心海洋 —— ✅ 纯聊天骨干已落(切片①–⑧,真后端免费模型端到端亲测);tool 卡/人在环/右岛 ⏳ 待建

> **建法(2026-07,用户拍板)**:视觉阶梯 **V0–V8 逐模块 gallery-first 锁死长相再组装**。**模块已锁**:V0 `AnComposer`(发送框原语+完整转场动效,`b8f2f7a4`+`5ca606b5`)· V1 `ChatTurn`(回合韵律:用户泡/助手裸 + `surfaceSunken` token,`e688d7f2`)· V2 `ChatThinking`(推理块「低语+流窗」完整生命线 + `AnShimmerText` 流光原语,`78b30c79`)+ `AnMarkdown`(`a157dec9`)· **V7-transcript 半(用户泡完整体)**:`AnAttachmentCard`/`AnAttachmentThumb` + `UserTurnContent`(附件在上、提及 `AnRefPill` 内联、文本在下;五态降级诚实)。**待建**:V3 tool_call chassis → V4 tool_result 三形状 → V5 特殊块 → V6 人在环卡(interaction 重连补拉硬需求)→ V8 右岛 entity-workspace(须深读 demo 再定)→ V7-composer 半(上传流/预览条/@ picker)。

### B.1 已落形态(纯聊天组装,切片①–⑧)

- **契约+数据缝**:`core/contract/messages/chat_message.dart`(REST `ChatMessage`/`ChatBlock`)+ `ModelRef`(conversation `modelOverride` 三态)+ `ModelCapability`;`ChatRepository` 扩 transcript 面(`createConversation`/`listMessages`/`sendMessage`/`cancelTurn`/`markSeen`/`setModelOverride`/`conversationFrames`/`transcriptResync`/`listModelCapabilities`),Live/Fixture 双实现。
- **合并模型** `ConversationTranscript`(`features/chat/model/`,纯 Dart 可单测):**三层** settled(终态水化)/ live(`BlockTreeReducer` 流式,永不升层)/ pending(乐观回声 FIFO 对账,线上无 nonce);**未完回合种子**——REST 头页的非终态尾巴以合成帧种进 live,流续写不孤儿;echo close 快照会整写 content → `_echoMentions` 每耐久帧后重并(测试抓到的真 bug)。
- **流控制器** `ConversationStreamController`(autoDispose family):订阅→预置缓冲→水化→放帧;`late CoalescingNotifier` 每 build 重建;`send`/`retrySend`/`discardFailed`/`cancelTurn`/`loadOlder`(flag try/catch 复位);`_onResync` 重缓冲+dropLive+重水化;`_syncPin` 在飞时 keepAlive 钉活;`:seen` 仅当前选区(水化 + 助手耐久 close 两处)。
- **transcript 视图**(`chat_transcript.dart`):**CustomScrollView + center 锚**——老页填锚上 sliver(负偏移向上长,**prepend 零位移**),头页+live+pending 填锚下(向 max 长,上翻阅读者不被推);**dock 语义**:锚下超屏 → 贴 max(逐 tick 跟随);未满屏 → **钉 min**(露出锚上让头 padding,首行永不被浮层头盖——E2E 抓到的真 bug,修于同切片);上滑解钉、发送重钉。终态行**身份缓存**(同实例短路 element 重建)= L3 等价;`TranscriptProbe` BuildSpy 门禁(200 deltas:页 0 / settled 行 0 / 叶≤1/帧)。块派发:text→`AnMarkdown` · reasoning→`ChatThinking` · tool_call→占位(V3 前)· 非 end_turn 终态→诚实横幅(cancelled/error[码+文案]/max_steps/budget)。
- **composer @ 提及**(切片 C,W3C combobox + Slack/Notion 标准):行首/空白后打 `@` 或点 lead @ 钮 → `AnMentionPanel` 在 composer 上方整宽弹出(`OverlayPortal`+`LayerLink`,不夺焦——focus 恒在输入框,键盘活动行经 `AnMenuRow.highlighted` 外驱高亮[地基强化]);空 query=浏览、续打服务端过滤(150ms 防抖+迟到守卫)、无匹配即关;↑↓ 循环 / Enter·Tab 选中(**面板开着时 Enter 拦在发送前**)/ Esc 关且同 token 不再弹(离开 token 重置);词中 @(邮箱)不触发(`activeMentionQuery` 纯函数)。选中插 `@name ` 经 `MentionTextEditingController.buildTextSpan` 染 accent 伪药丸(**IME 合成期不整体回退**——合成区间单独下划线、周围照染,否则打中文药丸闪灭;token 边界才染),药丸后一次退格整删;发送时文本里仍存的 `@name` 快照上行(仅 `{type,id}`,后端冻结 name+content)。数据缝 = **core `MentionSource` DIP**(`mentionSourceProvider`,app 层 `EntityMentionSource` 聚合 4 类实体 list `?search` 并发扇出、每类封顶 5、固定 kind 序,app+demo 两 main 同一 override)。
- **composer 附件三入口**(切片 D,调研定稿 `file_selector`+`pasteboard`+`desktop_drop` 纯平台通道三件套、零 Rust):① 📎 → `openFiles()`(沙箱 entitlement `files.user-selected.read-only` 两份 entitlements 已加)② **粘贴** → `Actions` 覆写 `PasteTextIntent`(EditableText 的 paste 注册为 overridable——Cmd+V 与右键粘贴一次全拦;判序 **文件→位图→callingAction 放行文本**——Finder 复制自带图标位图、图先会贴成图标;位图恒 PNG,命名 `pasted-image-<ts>.png`)③ **拖放** → `DropTarget` 包整个中心(Slack 大目标惯例,悬停半透明面纱+居中提示,落下喂当前草稿)。三入口汇 `pendingAttachmentsProvider`(按草稿键,与文字草稿同寿命):立即 `POST /attachments`(multipart `file`)→ `AnAttachmentChip`(uploading 转圈[reduced 静态字形]/ready 大小/failed 点体重试;放 `AnComposer.attachments` 槽触发 pill→card);移除 ready chip 顺手 DELETE(后端无 GC);发送带 `attachmentIds`(纯附件可发、上传中禁发),成功后仅清本地。**泡内解析**:`attrs.attachments` 纯 id 经 keepAlive `attachmentMetaProvider`(GET 元数据,不可变)解析成 文件名/kind/大小 卡;**图片渲真缩略图**——`AttachmentImageProvider`(键=附件 id[行不可变],字节经 `GET /{id}/content`[`ApiClient.getBytes`],Flutter 全局 ImageCache 免费去重);composer 里有字节的图片 pending 渲 `AnAttachmentThumb` 瓦片+角 ✕(图片 ready 后**保留字节**供缩略,非图即弃);加载=resolving、404=missing 墓碑。契约:`core/contract/attachment.dart`(`AttachmentMeta` 镜像后端 DTO)。
- **composer 接线**(`chat_composer.dart`):Enter 发 / Shift+Enter 换行 / IME composing 守卫 / 生成中 Enter 吞;docked 态随 `hasInFlight` 在 send↔stop 间切;草稿 per-thread(`chatDraftsProvider`,成功即清);landing 失败留文本 + toast。
- **landing + New 懒建**:无选区 → `_ChatLanding`(**静态问候 h2/主墨/一次淡入上移**——三家[ChatGPT/Claude/Gemini]皆无打字机,流式隐喻留给回答;组锚 40% 高度)+ 浮起 composer;首句 `startConversation`(POST 空题会话 → **landing 选了模型则 PATCH modelOverride 先于首条消息盖章**[建会话只收 title、PATCH 唯一路径]→ 新 controller 发送,keepAlive 跨导航持住)→ `context.go` 进线程;rail 行由 notifications `created` 信号长出。
- **浮层头**(`chat_head.dart` + `conversation_header.dart`)**两态**:landing=模型菜单独占最左(选择粘性 `landingModelProvider`,首发盖章);线程=标题就地改名(`AnInlineEdit`,同 rail PATCH;**loose 宿主下 min 收紧**——壳给 head tight 全宽槽,不收紧会把模型钮顶到最右)+ 紧跟其右的**模型菜单**(`alignEnd:false` 右下展开——AnMenu 默认 end 会向左;`GET /model-capabilities`;Auto=清覆写走 workspace 对话默认;PATCH `modelOverride` 三态)+ 生成中蓝点;**自动命名活着落**——header controller 听 lifecycleSignals(durable+本 id)静默重读,rail 行同信号重读,**完成瞬间双落、无需刷新**(真机已验)。
- **标题假流式**:新自动命名首落(title 空→非空 + `autoTitled`;改名不命中)以**一次性打字机**出现——head(播完切回可改名标题,`Center(widthFactor:1)` 收紧、模型钮随打字右移)与 rail 行(`labelWidgetFor` 渲染层覆盖)同播;单一检测点在 list notifier 折入处(`titleRevealsProvider` 队列,播完出队)。地基:`AnTypewriter.onDone`(非循环打完触发一次,reduced 下一帧即触)+ `AnRow.labelWidget`/`AnSidebarList.labelWidgetFor`(label 覆盖逃生舱,模型保持纯)。demo 镜像后端钩子(首回合完成后取首行 12 字素命名)。
- **rail 空标题回落**:未命名线程(建完未命名/命名失败)rail 行回落「New chat」(与头一词),行绝不空白(E2E 抓到的真 bug)。
- **demo 脚本流式**:`DemoChatRepository.sendMessage` 经与真网关同一帧缝回放 回声→thinking deltas→text deltas→close(~4s),流中 Stop 落诚实 cancelled;种子会话铺满已锁模块。`make demo` 零后端全闭环。

### B.2 端到端实证(2026-07-02,真后端 + 免费模型,cliclick 亲测)

`make server`(:8742)+ 真 app(`ANSELM_BACKEND_URL`):workspace 冷启动自建 + **免费档自动开通**(managed key `anselm`/`deepseek-v4-flash`)→ landing 首发懒建 → **无默认模型时诚实错误横幅**(`LLM_RESOLVE_ERROR · no model configured for scenario`)→ 设 dialogue 默认后**真流式全程**(thinking 流光→流窗→thought 收起;正文 token 级贴底跟随;未闭合 markdown 乐观渲)→ **自动命名走 utility scenario**(只设 dialogue 不够——rail+head 完成瞬间活着双落)→ 流中 Stop 落 `cancelled` + 半截保留 + Stopped 横幅 → 杀 app 重启 transcript/标题/横幅全量恢复。**E2E 揪出并同切片修复 2 真 bug**:未满屏首行被浮层头盖(dock-to-min 修)· rail 空标题空白行(New chat 回落修)。

### B.3 后端契约要点(后续 V3–V8 建前仍必读)

- **messages SSE** 唯一 scope = `conversation:<id>`;**耐久判据 = `seq>0`**(不看帧动词);用户回声 close 带内联 content+attachmentIds、**不带 mentions**(本地快照并入)。
- **interaction 是 `seq=0` ephemeral** → 重连**必拉 `GET .../interactions`** 否则 turn 永久阻塞(**硬需求**,V6 落);无「resolved」帧(靠 tool_result 流入关确认卡)。
- 块型:后端 **6 持久块 + `message` + `unknown` + 第 9 非块 `interaction` 信号**;demo 的 `todo`/`turnEnd`/「3.5s 自动批准」与后端不符,**勿造**(human-loop 无超时/无自动批准)。
- **自动命名 = utility scenario**(非 dialogue):free-tier 开通只建 key、**不设默认模型**(consent 门);app 首启需引导设 dialogue+utility 两个默认(平台 backlog,见 WRK-042)。

### B.4 🔥 流式渲染性能纪律(已落实)

- **L0–L2 原语 4.0**:网关 demux · ephemeral/durable 分流 · `CoalescingNotifier`(一帧 ≤1 notify)。
- **L3–L6 已落的等价形**:终态行身份缓存(= per-block provider 的目的:settled 零重建)· live 回合逐 tick 新建但只它一个 · `RepaintBoundary` 于行 · CustomScrollView 懒 sliver。**门禁红绿证明**:`BuildSpy` 200 帧断言 页==0 / settled 行==0 / 叶≤1/帧,入 `make fe-verify`。
- **禁** A1–A6:页面 watch 整流 · 叶子不 select · 逐帧 where · 一 token 一 notify · ephemeral 灌 durable · helper 函数建行。

---

## C. 跨阶段决策 + 咬人的坑(durable,移植/续建必读)

- **滚动根治 = CustomScrollView + center 锚**(取代 backup 时代的 `reverse:true` 结论):老页在锚上负偏移向上长(**prepend 零位移、无 offset 数学**),live 在锚下向 max 长(上翻阅读者不被流式推);贴底是**显式跟随**(钉住时逐 tick 跳 dock 目标,上滑解钉、发送重钉)。dock 目标 = 超屏贴 max、未满屏钉 min(锚定列表初始停锚上、首行会被浮层头盖——min 才露出锚上让头 padding)。`reverse:true` 的旧结论只对正向 ListView + 手动 offset 成立,center 锚同样布局自带保位且不引入 reverse 的语序反转。
- **`CoalescingNotifier` 持有者必须每 build 重建**一只 + build 域 onDispose 释放(Riverpod onDispose 重建时也触发,`final` 实例释放后仍被 ValueListenableBuilder 绑 = 冻结/崩);用 `late` 重建。
- **async 分页 flag 须 try/finally 复位**(`_loadingOlder`),否则瞬时错误/410 抢占永卡。
- **interaction 重连补拉**(B.2)是硬需求,别漏。
- **hover 揭示的 widget 测**:`AnRow` 的 ⋯/actions 受平台 highlightMode 门控 → 测里须 `focusManager.highlightStrategy = alwaysTraditional` + 真鼠标 down/up(非 `tester.tap`,否则点击穿透);chat 有 generating 呼吸点 → **禁 `pumpAndSettle`**(永不 settle),用定量 pump。
- **真机截图揪集成 bug**(隔离 widget 测漏):壳右岛门 hasItems 漏算 / transcript 误升嵌套 subagent 为根——state/壳门控必须真机端到端跑。

---

## 建造顺序

> rail STEP 0–7 ✅;纯聊天骨干切片①–⑧ ✅(契约缝→管道→视图滚动→composer→landing→头→点灯→端到端,B.1/B.2)。剩余按视觉阶梯:

1. **V3 tool_call chassis → V4 tool_result 三形状 → V5 特殊块**(gallery-first 锁长相再接 transcript 派发)
2. **V6 人在环卡**(内联确认卡 + interaction 重连补拉硬需求)
3. **V8 右岛 entity-workspace**(深读 demo 后定)+ V7-composer 半(上传流/预览条/@ picker)
4. **每步照流水线**:扇出读后端 → best-practice → 规范 → 拍板 → gallery → 建 → 五电池 → 真机截图
