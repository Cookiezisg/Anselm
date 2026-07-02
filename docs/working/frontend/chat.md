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

## B. 中心海洋 —— ⏳ 下一步(主战场)

rail 选中/新建后,中心要长出**对话正文 + 输入**。这块从零建,是 chat 的核心。

> **建法已改(2026-07,用户拍板)**:视觉阶梯 **V0–V8 逐模块 gallery-first 锁死长相再组装**(用户对着 gallery 看,不管内部联调)。**已落**:V0 `AnComposer`(发送框原语+完整转场动效,`b8f2f7a4`+`5ca606b5`)· V1 `ChatTurn`(回合韵律:用户泡/助手裸 + `surfaceSunken` token,`e688d7f2`)· V2 `ChatThinking`(推理块「低语+流窗」完整生命线 + `AnShimmerText` 流光原语,`78b30c79`)+ `AnMarkdown`(本提交)。待建:V3 tool_call chassis → V4 tool_result 三形状 → V5 特殊块 → V6 人在环卡 → V7 @提及/附件 → V8 右岛;组装(transcript 管道/BuildSpy/滚动器)在模块锁完后进行。

### B.1 计划面(从 New 起头)

1. **New 懒建**:点「新对话」→ 进**空 landing**(composer,ChatGPT 式),**首句才真建**(POST 会话 + 自动标题),rail 原地不跳。这步把中心海洋 + composer 起头。
2. **对话正文 transcript**:历史水化(REST `Message.blocks[]` → `BlockNode`)+ 实时流式(messages SSE)经 **`BlockTreeReducer`**(已有,run 终端共用)折块树渲染。
3. **markdown 渲染**(决策①)✅:`AnMarkdown`(core/ui,`gpt_markdown 1.1.7` token 锁定门面、版本钉死)——bold→w400 组件替换(包默认在钉轴 VF 上渲 w300,两档字重是功能必需)· 标题降档 20/16/13 · 围栏→`AnCodeEditor` 只读(唯一高亮源)· 表→AnThinTable · 链接 scheme 闸+宿主回调、永不自动开 · 图不取网 · HTML/`(x)` 惰性 · LaTeX 关;流式 text 纯 prop、未闭合围栏乐观渲染(接 transcript 时**必经 `CoalescingNotifier`**)。12 专项测试 + gallery 五电池。
4. **人在环确认卡**(决策③):危险/ask = **内联确认卡**(非模态);turnEnd Continue 后端无 resume → 诚实发续跑消息。
5. **右岛 entity-workspace**(决策②):随对话「长出」(touchedEntities + Todo + Subagent + picker,active 跟最新)。**右岛内容须深读 demo `features/chat` 再定**(用户明确要认真参考 demo)。

### B.2 后端契约要点(建前必扇出详读)

- **messages SSE** 唯一 scope = `conversation:<id>`;**耐久判据 = `seq>0`**(不看帧动词)。
- **interaction 是 `seq=0` ephemeral** → 重连**必拉 `GET .../interactions`** 否则 turn 永久阻塞(**硬需求**);无「resolved」帧(靠 tool_result 流入关确认卡)。
- markdown 渲染器已落(`AnMarkdown`,见 B.1-3)。
- 块型:后端 **6 持久块 + `message` + `unknown` + 第 9 非块 `interaction` 信号**;demo 的 `todo`/`turnEnd`/「3.5s 自动批准」与后端不符,**勿造**(human-loop 无超时/无自动批准)。

### B.3 🔥 流式渲染性能纪律(B 阶段真落地处)

中心海洋是流式 firehose——**绝不整页重绘**靠 7 层 AND(详见 [[chat-4.2-plan]] 记忆全文):

- **L0–L2 原语 4.0 已建**:网关 demux(订阅者只拿自己帧、禁逐帧 `.where`)· ephemeral/durable 分流(seq=0 瞬时 holder / seq>0 patch 缓存)· **每帧合并器** `CoalescingNotifier`(`_flushScheduled` 守一帧 ≤1 notify,几百帧/秒 → ≤1 重建/帧)。
- **L3–L6 本阶段写**:L3 family provider per blockId · L4 叶子 `.select` slice · L5 叶子 `Consumer`+`ValueListenable`+`RepaintBoundary`(**页面 `const` StatelessWidget 建 `ListView.builder`、绝不 watch 流**)· L6 `ListView.builder` 虚拟化 + 稳定 `ValueKey` + **`reverse:true`**(底部增长)。
- **禁** A1–A6:页面 watch 整流 · 叶子不 select · 逐帧 where · 一 token 一 notify · ephemeral 灌 durable · helper 函数建行。
- **性能门禁** `make fe-verify`:`BuildSpy` 灌 200 帧 + `pump()`,断言 **叶子≈190 / 行≤1 / 页面==0** + durable 进缓存。= 「绝不整页重绘」红绿证明。

---

## C. 跨阶段决策 + 咬人的坑(durable,移植/续建必读)

- **`ListView reverse:true` 是滚动 bug 的根治**(backup 对抗复审 `waium6gnb` 10 confirmed):正向 ListView + 手动 offset 数学是一族 bug 的根(切会话误翻 / prepend 早一帧失效 / 变高行估高);reverse 令贴底+保位**布局自带**。短会话底贴(WhatsApp 流派,与底部 composer 衔接)。
- **`CoalescingNotifier` 持有者必须每 build 重建**一只 + build 域 onDispose 释放(Riverpod onDispose 重建时也触发,`final` 实例释放后仍被 ValueListenableBuilder 绑 = 冻结/崩);用 `late` 重建。
- **async 分页 flag 须 try/finally 复位**(`_loadingOlder`),否则瞬时错误/410 抢占永卡。
- **interaction 重连补拉**(B.2)是硬需求,别漏。
- **hover 揭示的 widget 测**:`AnRow` 的 ⋯/actions 受平台 highlightMode 门控 → 测里须 `focusManager.highlightStrategy = alwaysTraditional` + 真鼠标 down/up(非 `tester.tap`,否则点击穿透);chat 有 generating 呼吸点 → **禁 `pumpAndSettle`**(永不 settle),用定量 pump。
- **真机截图揪集成 bug**(隔离 widget 测漏):壳右岛门 hasItems 漏算 / transcript 误升嵌套 subagent 为根——state/壳门控必须真机端到端跑。

---

## 建造顺序(B 阶段,照 entities 拓扑 + 流水线 7 步)

> rail STEP 0–7 ✅。以下为中心海洋:每步 扇出读后端 → best-practice → 本文档加 STEP 规范 → 你拍板 → gallery-first → 建 → 五电池 → 真机截图。

1. **New 懒建 + composer + landing**(起中心海洋骨架)
2. **transcript 水化 + 流式合并**(BlockTreeReducer 接历史 + messages 流;L3–L6 叶子 + BuildSpy 门禁)
3. **markdown 渲染**(gpt_markdown + AnCodeSurface,gallery 先行)
4. **人在环 surface**(内联确认卡 + interaction 重连补拉)
5. **右岛 entity-workspace**(深读 demo 后定)
6. **两流活态接线 + 重连对账**(messages + notifications;rail 跨客户端合并并入此)
7. **五电池 + 真机端到端**
