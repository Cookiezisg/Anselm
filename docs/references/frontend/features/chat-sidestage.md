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

## 1. 结构(自上而下)

`StagePanel`(`features/chat/ui/stage_panel.dart`,`AppShell` 在 chat 海洋有选中会话时挂进右岛):

| 段 | 物 |
|---|---|
| 头带 | `AnInspectorHead` + **跟随三档菜单**(`_FollowMenu`:每次/每会话首次/从不,持久化 `fy.stage.follow`,settings 模块读同一 `followModeProvider`)+ 舞台开着时 ✕ 收场 |
| 频道条 | `AnChannelStrip`(≥2 并发活动时,cap 4 + 溢出;点 tab=pin 换台;failed 挤台成红点 tab) |
| 舞台 | `AnExpandReveal` 揭示 `_GenericStage`(眉+诚实丝带+kind 量身体);**exhibit 置位时让位 `ExhibitStage`** |
| 药丸行 | `AnFollowPill`(gate 琥珀「AI 在等你决定」压一切 / live「AI 正在编辑 X」点回跟随) |
| Rundown | `_RundownSection`(`AnTaskRing` 补弧 + `AnRundownList` 三态行,todo 整表帧,按 subagentId 分板) |
| 演员表 | `_CastList`(触点台账 R-2 实体聚合行:`AnCastRow` 新鲜度晕+动词微词+×count;**hover 尾位换双微动作**「跳到发生处」(''=藏)/「去实体页」(无面板即藏);**点行=exhibit 登台**;主角行 R-6 静态脉点;**谢幕落账洗亮** ~1.8s 衰减) |

## 2. 引擎与状态

- **`StageDirector`**(`model/stage_director.dart`,纯状态机):六态 idle/following/pinned/curtain/failedHold(+anchored 视口子态);500ms 登台防抖(短操作永不登台)、800ms 静默+2400ms 驻留换台仲裁、优先级 humanGate>build>execution>subagent;**pinned 永不自动收**;failed 驻留红纱。`LifecycleSource` 三型——toolClose(常规)/poll(`trigger_workflow`:202 关帧绝不谢幕,**驻留到 durable `run_terminal` 到达**——`onRunTerminal` 净→停拍谢幕、败→红纱,R-10 已退役)。
- **宿主 `stageDirectorProvider`**(`state/stage_director_provider.dart`,autoDispose family):会话帧投影(tool_call open/delta/close)+ 人闸旗 + 唯一闹钟 advance(到期时刻);**poll 记账**——工具名留自 open、workflowId 解自关帧 args、flowrunId 解自入队回执,按 `workflowFrames(workflowId)`(entities 流 scope 订阅)听 `run_terminal` **按 flowrunId 匹配**。`followModeProvider` 持久三档。
- **`touchpointLedgerProvider`**(`state/touchpoint_ledger.dart`):R-2 (kind,itemId) 聚合、durable 触点信号直 patch(绝不过 CoalescingNotifier)、410 重拉首页并入、keyset 无限滚。
- **`exhibitProvider`**(`state/exhibit_provider.dart`):用户钉的 Cast 展品——**刻意在导演器之外**(StageActivity 只能由 tool_call open 出生);`ExhibitStage` 美术馆开灯入场,attachment=**展品座**(缩略图+size/mime/sha256 前缀 mono),实体=身份面(id mono+动词史 KV),墓碑静态;驻留到关闭。
- **`rundownProvider`**:todo 整表替换直 patch + GET 水化。
- **R-15 activityBit**:右岛收起时,`AppShell` 以 `stageDirectorProvider.select(channels.any(live))` 点亮 `AnShell.rightActivity`(panel-right 钮柔 accent 点)。

## 3. 12/13 kind 量身舞台(`ui/stages/`,registry `stage_registry.dart`)

fn(地层→OpTicker→活代码窗→落定真 diff 徽)/document(书脊+前缀快进+R-9 元数据卡)/workflow(真画布图生长+判别式抽屉)/control(丝线决策梯+透传幽灵+否则徽)/approval(信笺+琥珀插值+timeout 人话)/trigger(四脸+R-16 落定只信 GET)/subagent(单席 ReAct 尾+群像点卡换台+tokens 结算)/handler(方法架,W0 带路径通道同名 body 隔离)/agent(R-9 未提及槽 40% 旧真相)/skill(装订台+琥珀 allowedTools+$ 占位槽)/memory(记忆笺,图钉 REST-only)/mcp(接线现场+工具货架)。conversation 不设舞台;attachment=exhibit 展品座(无建造工具入口)。共同律:R-4 live 禁成功语义、R-5 edit 登台即 GET 旧真相、R-9 渐进开区、R-12/13 有界动画窗。

## 4. 导航(W6)

- **transcriptJump「re-anchor」**(`state/transcript_jump_provider.dart` 命令通道,`chat_transcript.dart` 唯一消费):近跳=`retargetCenter` 移锚零拉取;深跳=`?around=` 窗**整扇替换**(目标即 center sliver 首行,零 extent 估算)+双向续翻(`olderCursor`→`?cursor=`/`newerCursor`→`?dir=newer`)+「回到现场」pill(发送隐式离窗;`backToLive`=410 重同步同径);落点洗亮 hold+fade;**跳转即解钉——流式帧绝不夺视口**(组测验收)。
- **场次条 `TranscriptToc`**(`ui/chat_toc.dart`,目录钮在 `ChatHead`):`GET /{id}/anchors` 全量锚点(循环分页),gate 琥珀置顶>newest-first 时间线(user 主锚加粗/`tools`「⚙ N 项操作」折叠簇/danger/compaction/abnormal 逐条),点锚=jump+自收。
- **R-14**:落定舞台眉部「跳到发生处」=`ConversationTranscript.messageIdOf` 走父链到回合锚(role 式 Subagent 台账无影,这是它唯一的锚)。

## 5. a11y 章

四播报(`SemanticsService.sendAnnouncement`,polite):登台/人闸/失败/落定;live 流式区 `ExcludeSemantics`(播报+落定真相载义);全交互件带 semanticLabel;循环动效(FollowPill 呼吸/雷达环)骑共享 `PulseClock` 且 reduced-motion 冻结;洗亮/开灯等一次性动效 reduced 直落终态。

## 6. 契约(引用)

窗/锚 DTO 与 repo 缝 → [`contract.md`](../contract.md);后端 `?around=`/`?dir=newer`/anchors/`run_terminal`/tick `port` → [`references/backend/api.md`](../../backend/api.md) · [`events.md`](../../backend/events.md);触点台账 → [`domains/touchpoint.md`](../../backend/domains/touchpoint.md)。性能地基(增量 JSON 会话/revision memoize/PulseClock)与 perf 门禁 → 归档 WRK-061 §5/§10-W0。

## 7. 已记账的取舍(非欠账,是决策)

完整 AnCurtainCall 飞入行编舞(现=reveal 收起+落账洗亮)/词级淡入与快进滚动完整动效版/dagre 增量布局+fitView 跟拍/水脉闪真连线/nextFireAt 分钟活 tick/AnEnsembleGrid kit 提炼/整页终端升页交互/[[id]] 真名解析(MentionSource)/富 tooltip 待 `AnTooltip` 原语(kit 批)——以上为可选奢侈项,按需另立工单;深跳窗真机帧靠手动验(合成滚轮进不了 Flutter app)。
