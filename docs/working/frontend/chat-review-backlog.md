---
id: WRK-059
type: working
status: active
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-07
review-due: 2026-10-05
audience: [human, ai]
---

# Chat 模块完整性审计 backlog —— 大修待办

> **2026-07-07,34-agent 对抗审计**(8 子系统并行审 + 逐 finding 对抗验证)产出。用户明确:chat **要大修**,先把问题记全别搞忘。本页 = **待修台账**;修一条勾一条,修完的移入下方「已修」区。每条带 file:line 证据 + 修法方向。建造账见 [`chat.md`](chat.md)。
>
> **审计基线**:chat 骨架/composer/工具卡/浮层头/人在环 = 🟡 大体完成但有真 bug;浮层头/模型/landing = ✅;**右岛 V8 = 完全未建**(唯一整块缺失)。审计前 V5 已修一个真 bug(嵌套 subagent message 摊平,commit 92c9f8e1)。

## 逐子系统完整度

| 子系统 | 完整度 | 一句话 |
|---|---|---|
| 浮层头 + landing + 模型 + 自动命名 | ✅ complete | 全接线正确,仅低优 polish |
| rail 左岛 | 🟡 mostly | 功能全接,但琥珀点被遮蔽 + loadMore 无重试 |
| transcript + 滚动 | 🟡 mostly | 核心正确,但 max_tokens 误红 + 两个对账边缘 bug |
| composer | 🟡 mostly | 主体全落,失败附件静默丢 + 若干 @ 边界 |
| tool 卡 B1–B7 | 🟡 mostly | 底盘扎实,但 6 工具漏编目落 generic |
| 人在环 V6 | 🟡 mostly | 连接态对,但重连不重拉 GET interactions |
| 右岛 V8 | ⛔ not-built | 后端台账就绪,前端零代码 |
| demo/i18n/a11y | 🟡 mostly | 3 已建面 demo 看不到 + 1 i18n 漏 + 过时注释 |

---

## 🔴 HIGH —— 大修主目标

### H1. 右岛 V8 entity-workspace 完全未建（chat 最大剩项）
- **是什么**:chat 的「对话上下文台账」右岛——对话里碰过的实体聚合成工作区(「随对话长出」)。后端 touchpoint 台账 **100% 就绪**(4 层 + 装配 + 门禁 + 契约文档),前端**零代码痕迹**。
- **要建五层**:① 契约 DTO(freezed 镜像后端行 `{id,itemKind,itemId,itemName,verb,lastActor,count,firstAt,lastAt,lastMessageId}`,verb/itemKind/lastActor 是封闭集可 seal)② 数据 repo(Live: dio `GET /conversations/{id}/touchpoints` keyset 分页 + `?kind`/`?verb` 过滤 + messages 流 durable `touchpoint` 信号消费 / Fixture)③ SSE 消费(touchpoint 信号现在到前端被 `block_tree_reducer.dart:95` `FrameSignal(): break` 静默丢——V8 要接消费方)④ paged state(AsyncNotifier + KeysetQueryPaging)⑤ 右岛 UI + **AppShell chat 分支**。
- **AppShell 硬门(H1 的一部分)**:`app_shell.dart:90-92` 右岛 `hasSelection` 只门控 entities/documents,`onChat` 恒 false → chat 永远打不开右岛;`:208` inspector child 三元无 chat 分支(即便打开也会错拿 entities 的 RunTerminal)。要加 `onChat && <选中/常显条件>` 分支 + `onChat ? ChatWorkspace : ...`。
- **证据**:`frontend/lib/features/chat/{data,state}/`(无 touchpoint 文件)· `app_shell.dart:90-92,208,210` · 后端 `handlers/touchpoint.go:52` · `docs/references/backend/domains/touchpoint.md`。

### H2. 6 个真实后端工具未编目、落 generic 兜底（证伪 B7「无 generic 剩余」）
- **是什么**:`read_memory`/`write_memory`/`forget_memory`(memorytool)、`WebFetch`/`WebSearch`(webtool)、`search_tools`——全是 LLM 可调、会在 transcript 产 tool_call 块的真工具,但 `tool_card_catalog.dart` 的 `_catalog`(110 条)+ `mountSpecFor`(只名路由 `mcp__`/`handler__`)三处零命中 → 渲成通用卡(「正在调用 read_memory」+ 裸 JSON),而非蓝图设计的 MemoryNoteCard(#41)/WebHitList(#48)/ToolChecklist。
- **相关(partial)**:WebFetch/WebSearch 的 soft-fail 散文(status=completed 但内容是失败句)被通用卡渲成中性「完成」行、无 `resultFailed` 红壳——蓝图 #48 的 `webOutcome` 分类器未建。
- **修法**:给这 6 个补 catalog spec(按蓝图 #41/#48/ToolChecklist);WebFetch/WebSearch 加 soft-fail 分类。
- **证据**:`tool_card_catalog.dart:544-1237`(_catalog 缺这 6)+ `:1242` 兜 generic;`tool_card_mount.dart:36-41`;后端 `build_services.go:276,283`(MemoryTools/WebTools 入 Lazy)+ `chat.go:251`(SearchTools 常驻)。

---

## 🟡 MEDIUM —— 大修必带

### M1. 琥珀「等你输入」状态点在生产永远不出现（rail）
- **根因**:真实人闸时后端 `isGenerating` 与 `awaitingInput` **同时为 true**——humanloop `Broker.Request` 同步阻塞的正是 `processTask` goroutine,该 goroutine 仍占 `q.running=true` → `chat.go:439` IsGenerating 返 true;`interactions.go:114` HasPending 使 AwaitingInput 也 true。而前端优先级 蓝(生成中)> 琥珀(等你)→ 任何真正待批准/回答的对话渲蓝点,**最该被凸显的「需要你」状态在生产中不可达**(注释的「互斥」前提为假,对抗验证坐实是分类死态)。
- **修法**:前端把 awaiting **优先于** generating;或后端把「被闸阻塞」的回合排除出 IsGenerating。
- **证据**:`conversation_rail_model.dart:17-23` · 后端 `chat.go:431-440` · `humanloop.go:112-133` · `conversation.go:176-188`。

### M2. `max_tokens` 终态被误染成红色 error 横幅（transcript）
- **是什么**:模型因 `FinishReason=="length"` 截断 → 后端 `stopReason=max_tokens` 但 `status` 仍 `completed`(内容完好、只是被截断的正常回合)。前端 `_stopBanner` 只处理 cancelled/max_steps/context_budget,`max_tokens` 落 `_` 默认 → 红色「Something went wrong」。一条成功回合被打红标,不诚实。i18n 也缺 `stoppedMaxTokens` 键。
- **修法**:加 max_tokens 分支(诚实文案「已达输出上限,可继续」,非红色 error)。
- **证据**:`chat_transcript.dart:388-394` · 后端 `stream.go:190-192` · `loop.go:210-214` · `messages.go:129`。

### M3. FIFO 回声对账不跳过失败泡 → 错并失败泡 + 永久重复泡 + 卡死 composer（transcript）
- **触发**:send1 POST 失败→泡标 failed 留存。此时 hasInFlight=false(唯一泡 failed),composer 允许再发。用户 send2→其 durable 回声到达→`removeAt(0)` 消费的是 index 0 的 **failed 泡(send1)** 而非 send2。后果:① send1 失败泡被静默移除、用户失去 retry/discard;② send2 乐观泡永不对账、与真实 echo 并存成永久重复泡,且 send2 泡非 failed → hasInFlight 恒 true → **composer 永久卡 stop 态**。
- **修法**:`applyFrame` 的 pending 消费跳过 failed 泡(取第一个非 failed)。
- **证据**:`conversation_transcript.dart:126-132`(removeAt(0) 不过滤)· `:72`(hasInFlight 排除 failed)· `chat_composer.dart:525,532`。

### M4. send 间隙 410 resync 留永不对账重复泡 + 卡死 composer（transcript）
- **触发**:发送后未收 echo 时遇 410 resync→`_onResync` dropLive + setHistory 重拉头,**pending 泡刻意保留**(假设「会再 echo」)。但若该用户消息此刻 REST 头页已是 terminal(completed)→ setHistory 只种非终态尾进 live、terminal 用户回合进 settled、settled 不产 live 回声帧 → **保留的 pending 泡永不对账**、与 settled 真实回合成重复泡,且非 failed → composer 永久 stop。窗口窄但可达。
- **修法**:resync 后对账 pending 与 settled(按 content/时序去重),或 terminal 化的 pending 直接清。
- **证据**:`conversation_stream_provider.dart:145-150` · `conversation_transcript.dart:151-155,90-104`。

### M5. 失败附件在发送时被静默丢弃且清空（composer）
- **是什么**:失败 chip 不禁发(仅 uploading 禁)。用户带 1 failed 附件点发→`_send()` 只取 `readyIds`(排除 failed)、发送后无条件 `_att.clear()` 连失败 chip 抹掉→消息发出、附件既没上行也从 UI 消失、零提示。用户可能以为附件已发。
- **修法**:发送前对残留 failed 给提示或阻挡。
- **证据**:`chat_composer.dart:331,339,358` · 意图佐证 `chat_composer_test.dart:351-353`。

### M6. 人在环重连不重拉 GET interactions（V6 硬需求半落）
- **是什么**:`pendingInteractionsProvider` 只在 build 冷启拉一次 `GET interactions`、**不听 `transcriptResync`**。interaction 是 seq=0 ephemeral,mid-session 断线窗口内产生的 danger/ask 门丢了就再也不重取 → 门永久不显。这正是当初点名的硬需求(重连必拉否则 turn 永久阻塞)。
- **注**(对抗验证修正):provider 是 autoDispose,当阻塞工具是对话**首个** tool_call 块时会意外自愈(块重现→fresh build→_seed 重跑);只有对话已有更早 settled tool_call 使 provider 全程存活时才**确定性**永久失门。
- **相关**:`_seed` 纯增量 merge、从不裁剪本地已不在权威快照的 awaiting 记录(幻影门不收敛)。
- **修法**:build 里订阅 `transcriptResync` → 重拉 `GET interactions` + 用权威快照 reconcile(增删都做)。
- **证据**:`pending_interactions_provider.dart:62-76`(_seed 纯增)· 缺 transcriptResync 订阅。

### M7. compaction 低语在 make demo 完全不可见（demo）
- **是什么**:transcript 会渲 `ChatContextMark`(V5 刚建),但 demo/showcase/base 三个 fixture **没种任何 compaction 块** → make demo 永远看不到「上下文已压缩」低语,只 gallery 有。
- **修法**:某条 demo 对话种一个 `type='compaction'` 块。
- **证据**:`chat_demo_fixture.dart:269-305`(无 compaction)· `chat_transcript.dart:369`。

### M8. 活态人在环门在 make demo 无法演示（demo）
- **是什么**:门只在 `phase==awaitingConfirm && interaction!=null` 渲,但 `demoChatRepository()` 从不种 interactions（`chat_fixtures.dart:254` map 恒空）；cv_show_human 展台的 decide_approval/ask_user 都带 tool_result → 相位 settled 非 awaitingConfirm。→ **活态门(可点 approve/deny/ask 按钮)+ 已决出处章 demo 一次都不出现**,人在环在 demo 里只呈现为普通结果卡。
- **修法**:demo 种一个 awaiting 态 interaction。
- **证据**:`chat_demo_fixture.dart:256-268` · `chat_tool_card.dart:150,263` · `chat_fixtures.dart:254`。

### M9. chat rail loadMore 失败无重试 + per-RTT 请求风暴（rail）
- **是什么**:`ConversationListState` 无 error 字段、`buildConversationRailModel` 从不设 `SidebarType.loadError`(全 rail 死代码,永走不到重试 UI)。loadMore 失败→loadingMore 复位 false、hasMore 仍 true、rethrow 成未捕获异步错误;model 变→AnSidebarList 换新 GlobalKey 重建→`_LoadMoreSentinel` 全新 State→initState postFrame 再触 loadMore。持久服务端错误 → **per-RTT 重试风暴 + 每轮一个未捕获错误**。
- **修法**:state 加 error 字段 + rail 传 loadError + onLoadMore catch;失败后停自动重触、给手动重试。
- **证据**:`conversation_list_state.dart:16-23` · `conversation_rail_model.dart:130-138` · `conversation_rail.dart:136-137` · `keyset_paging.dart:49-55` · `an_sidebar_list.dart:859-870,811-844`。

---

## 🔵 LOW

- **L5** 附件泡内 chip 未在任何 demo 对话种(`chat_demo_fixture.dart:51,55` 仅形参)。〔demo-data,连 B1 demo 故事重排一并做〕

〔L1/L2/L3/L4/L6 已修,见下方「已修」区〕

## 过时注释 / 过度声称（顺手清）

- `chat_transcript.dart:374`「message 块 V5 接入」注释过时(嵌套 subagent B6 已落,现走 message 摊平)。
- `gallery/catalog.dart:266` ChatContextMark 描述标「V5 特殊块」(已落,可去)。
- `chat_showcase_fixture.dart:4-8` 头注「逐族触发全 113 工具卡」过度声称——实际只 ~33 工具 / 7 族。
- `tool_interaction_gate.dart:335` deny 用 danger 变体但类 doc 声称 negative=ghost(文档/代码不符,择一)。
- name 排序下就地改名不重排,行停旧字母位(`conversation_list_provider.dart:205-226`,polish)。
- @ 面板不随外部点击/滚动消隐(`chat_composer.dart:125-160`,polish)。
- head/rail 打字机 showCaret 不一致 + 揭示「静态→重播」闪烁竞态(`chat_head.dart:55-56,77`,polish)。

---

## 已修（勾掉留痕）

- ✅ **M1 琥珀「等你输入」点被蓝遮**(2026-07-07):`conversation_rail_model.dart` `conversationDot` 把 `awaitingInput` 提到 `isGenerating` **之前**(被人闸阻塞的回合两者同真,「需要你」琥珀点须赢蓝点否则生产不可达)。rail model 测同步改。
- ✅ **M2 max_tokens 误染红**(2026-07-07):`chat_transcript.dart` `_stopBanner` 加 `'max_tokens'` 分支(amber `warn` 限额提示「Reached the output limit」,非红 error)。i18n 补 `stoppedMaxTokens`。
- ✅ **M3 FIFO 回声不跳失败泡**(2026-07-07):`conversation_transcript.dart` `applyFrame` 的对账从 `removeAt(0)` 改 `indexWhere((p)=>!p.failed)`——回声对账最老**在飞(非失败)**泡,失败泡存活(保 retry/discard),真发送不留幻影重复泡、不卡 composer。加回归测。
- ✅ **M5 失败附件静默丢**(2026-07-07):`chat_composer.dart` `_send` 前若 `_att.failedCount>0` 弹 toast(`attachmentsFailedDropped`)——发送仍进(取 readyIds)但用户被告知哪些没发,不再静默。`PendingAttachments` 加 `failedCount`。
- ✅ **M6 人在环重连不重拉**(2026-07-07):`pending_interactions_provider.dart` build 订阅 `transcriptResync()` → `_reconcile(prune:true)`(重拉 GET interactions:增新门 + 删幻影待决,保本地已决章);`_seed` 重构成 `_reconcile({prune})`。加 2 回归测(重连拉回窗内起的门 / 剪幻影门)。
- ✅ **L1 词中退格误删 @提及**(2026-07-07):`chat_composer.dart` `_atomicBackspace` 加**右边界**——光标后粘着词/中文字符(`@alicexyz`/`@alice你好`)则不整删 `@name`、退回逐字删。加 mid-word 回归测。
- ✅ **L2 搜索失败留过期候选**(2026-07-07):`chat_composer.dart` `_syncMentionQuery` search catch 里 `_closePicker()`(若仍最新查询)——查询失败关面板、不留上个查询的过期候选(否则选中插错提及);不挡输入。
- ✅ **L3 反向选区提及触发重复文本**(2026-07-07):`chat_composer.dart` `_insertMentionTrigger` 从 `base/extent` 直算改用**归一** `sel.start/end`——反向拖拽(base>extent)下 `substring(0,base)+'@'+substring(extent)` 会重复选中跨度(before 与 tail 交叠);归一后正确替换选区。加反向选区回归测。
- ✅ **L6 硬编 filter**(2026-07-07):`tool_card_skins.dart` Grep 卡 `'filter /$x/'` → i18n `grepFilter(p:)`。
- ✅ **L4 landing 首发孤儿回滚**(2026-07-07):`new_conversation.dart` `startConversation` 把 `setModelOverride`+`send` 包 try/catch——**modelOverride PATCH 抛错**(create 成功、盖章失败)时 best-effort `deleteConversation` 回滚刚建的空标题线程再 rethrow(landing composer 留字供重试)。**send 失败不回滚**(那是乐观失败泡路径、线程合理保留,`_post` 吞错不冒泡)。fixture 加 `failNextModelOverride` 钩 + 回滚回归测。
- ✅ **V5-C 嵌套 subagent message 摊平**(2026-07-07,commit 92c9f8e1):真后端嵌套回合是 tool_call 下 `message` 包装、轨迹是孙节点,`transcriptBlockRow` default→shrink 吞它 → 真后端 NestedRunPane 渲空(B6 fixture 用 raw 形没测到)。`ToolCardState.of` 加 message 摊平修复。
