---
id: WRK-059
type: working
status: archived
owner: @weilin
created: 2026-07-07
reviewed: 2026-07-08
review-due: 2026-10-05
audience: [human, ai]
landed-into: references/frontend/features/chat-sidestage.md, working/frontend/chat.md
---

# Chat 模块完整性审计 backlog —— 大修待办

> **2026-07-07,34-agent 对抗审计**(8 子系统并行审 + 逐 finding 对抗验证)产出;**2026-07-08 全部清账、本页归档**。17 confirmed(H×2 / M×9 / L×6)+ 7 条注释/polish 全部修毕(逐条见下方「已修」区,每条留修法与位置);H1 右岛 V8 由 [`WRK-061`](../chat-right-island/README.md) 整段建成(当前形态 [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md))。建造账见 [`chat.md`](../../working/frontend/chat.md)。
>
> 仍需**用户在场**的口味/原生项(demo taste / 图 1:1 视觉 / native chrome / IME 签字)不属本台账 confirmed 缺陷,单列在 memory 的 chat-overhaul 账里等用户。

## 逐子系统完整度

| 子系统 | 审计时 | 清账后(2026-07-08) |
|---|---|---|
| 浮层头 + landing + 模型 + 自动命名 | ✅ complete | ✅ |
| rail 左岛 | 🟡 琥珀点被遮蔽 + loadMore 无重试 | ✅ M1 + M9 修毕 |
| transcript + 滚动 | 🟡 max_tokens 误红 + 两个对账边缘 bug | ✅ M2 + M3 + M4 修毕 |
| composer | 🟡 失败附件静默丢 + @ 边界 | ✅ M5 + L1/L2/L3 修毕 |
| tool 卡 | 🟡 6 工具漏编目落 generic | ✅ H2 修毕(6 工具全编目 + soft-fail 诚实) |
| 人在环 V6 | 🟡 重连不重拉 GET interactions | ✅ M6 修毕 |
| 右岛 V8 | ⛔ 未建 | ✅ H1 由 WRK-061 W0–W7 整段建成 |
| demo/i18n/a11y | 🟡 3 面 demo 看不到 + i18n 漏 + 过时注释 | ✅ M7/M8/L5 种齐 + L6 + 注释全清 |

---

## 已修（勾掉留痕）

- ✅ **H1 右岛 V8 entity-workspace**(2026-07-08,整段另立 WRK-061):W0 性能前置 → W1 底盘(touchpoint ledger + StageDirector)→ W2–W5 12/13 kind 舞台 → W6 导航(?around=/anchors/深跳)→ W7 polish。归档 [`WRK-061`](../chat-right-island/README.md),当前形态 [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md)。
- ✅ **H2 六工具编目 + web soft-fail 诚实**(2026-07-08):新建 `tool_card_memory_web.dart`(~560 行)——`write_memory`(三分支正向门控回执[Saved→N 行/Cannot save→danger/模板漂移→无回执绝不猜]+ `memoryLiveBody` 内容尾流 + 不可逆徽)· `read_memory`(后端模板 `### name (source: x)\n描述\n---\n正文` 反解 → `MemoryNoteCard`[mono 名+source 徽+描述+发丝线+AnMarkdown 排版体,>900 字渐隐折叠];miss=回执即卡)· `forget_memory`(刻意薄+不可逆徽)· `WebSearch`(**`webSearchOutcome` 六态分类器**[hits/empty/noBackend/misconfig/providerFail/unparsed],命中=`_WebHits` 链接列表[title 15/snippet 13 clamp2/host mono 12,行点开走 `openExternalUrl` scheme 白名单],三种配置/供应商失败 `resultFailed` 红壳)· `WebFetch`(**`webFetchOutcome` 五态**[summary/empty/raw/jsShell/fail],fail 红壳;live=固定高 144 视口散文尾;体=问句行+ProseWindow/mono 原文)· `search_tools`(薄命中卡:mono 名+`schemaParamDigest` 星标参数摘要[滤 framework 三字段]+描述+受控 AnDisclosure schema 逃生口)。回执解析锚定后端稳定英文模板(后端改模板须同提交改测试);10 契约测 + showcase `cv_show_mem` 六卡展台;新地基 `core/platform/open_external_url.dart`(http/https/mailto 白名单,拒绝/失败返 false 绝不抛)+ `url_launcher` 依赖。真机验证:回执排/MemoryNoteCard/WebHits/薄卡四帧。
- ✅ **M4 send 间隙 410 resync 留重复泡**(2026-07-08):`conversation_transcript.dart` `setHistory` 尾新增 `_reconcilePendingWithSettled()`——重拉头后,在飞(非失败)pending 泡按 FIFO 与 settled **尾窗**(in-flight+2 个 user 回合)按原文精确匹配消费:真落盘的发送泡被重拉吃掉、不再与 settled 回合并存;失败泡绝不动(retry/discard 保留);只看尾部避免误吞深历史同文。410 resync 与 back-to-live 两路径同受益。加回归测(落盘泡恰消费一份 + 失败泡存活)。
- ✅ **M7 compaction 低语 demo 可见**(2026-07-08):`chat_demo_fixture.dart` cv_scroll 长卷第 21 回合种 `type='compaction'` 块(「Compacted 18 earlier turns into the running summary.」),`ChatContextMark` 时间轴低语 demo 可达(深历史处,渲染路径有 widget 测)。
- ✅ **M8 活态人在环门 demo 可演**(2026-07-08):demo 新增 `cv_gate`「展台 · 活人闸」——**门的真实线缆形**(tool_call 块已关帧[开着=argsStreaming 永远到不了 awaitingConfirm——本次真机验证抓到的形状错误]+ 无 tool_result + message 仍 streaming)+ `repo.interactions['cv_gate']` 种 danger 待决(delete_function/不可逆 summary/args)。真机验证:琥珀「Awaiting your approval」+ Dangerous 章 + 证据 KV + Deny/Always allow/Allow 三键 + rail 琥珀点 + 侧幕琥珀丸全同框。fixture `listAnchors` 同步从 `interactions` 出 gate 锚(场次条门置顶镜像后端)。
- ✅ **M9 rail loadMore 失败风暴**(2026-07-08):`ConversationListState` 加 `loadMoreFailed` 旗;notifier `loadMore` override——失败**吞掉**(不再 rethrow 成未捕获错误)+ 置旗停自动重触;旗经 `conversation_rail_model.dart` 传 `SidebarType.loadError` → `AnSidebarList` 既有手动重试行(此前全 rail 死代码)终于接活;重试先清旗再翻页。fixture 加 `failNextListConversations` 钩;回归测(失败停风暴→手动重试续页)。
- ✅ **L5 附件泡内 chip demo 种齐**(2026-07-08):置顶 demo `m_s3` 补 `attrs.attachments: ['att_demo_shelf']` + `attachmentMetas` 种元数据(shelf-audit.csv/CSV/47.1KB)——泡内附件卡(元数据解析路径)demo 可达,与侧幕展品座同一 id 串线。真机验证泡内 chip 同框。
- ✅ **注释/polish 七条**(2026-07-08):①`chat_transcript.dart` message 块注释、②gallery ChatContextMark「V5」标、③showcase 头注过度声称——三条经查**此前批次已顺手修毕**(现注释与代码一致);④`tool_interaction_gate.dart` 类 doc 对齐代码(deny 穿 DANGER 变体——拒绝不可逆动作配得上响色,decline=ghost,三处注释重述);⑤name 排序就地改名重排(`conversation_list_provider.dart` `applyUpdate` sort==name 时本地重排[pinned 先/title 小写比较/id tiebreak],游标不动);⑥@ 面板外点消隐(`chat_composer.dart` composer+面板同 `TapRegion` groupId,外点 `_closePicker`,面板内点/composer 内点不误关);⑦head/rail 打字机 caret 统一(`chat_head.dart` `showCaret:false` 与 rail 同;「静态→重播」竞态经查主路径被空→非空门挡住,残余为微观可接受、录记于此)。


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
