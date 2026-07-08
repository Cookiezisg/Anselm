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
| 舞台 | `AnExpandReveal` 揭示 `_GenericStage`(眉+诚实丝带+kind 量身体);poll 型主体带**活运行卷**(`_RunProgressSection`:flowrun 节点 tick 逐行静落,mono 节点+状态字形+选中 `port` accent 徽,≤12 行,durable 终态一行收卷);**exhibit 置位时让位 `ExhibitStage`**;舞台内滚动=pinned(阅读即持镜,只认用户手势) |
| 药丸行 | `AnFollowPill`(gate 琥珀「AI 在等你决定」压一切 / live「AI 正在编辑 X」点回跟随) |
| Rundown | `_RundownSection`(`AnTaskRing` 补弧 + `AnRundownList` 三态行,todo 整表帧,按 subagentId 分板) |
| 演员表 | `_CastList`(触点台账 R-2 实体聚合行:`AnCastRow` 新鲜度晕+动词微词+×count;**hover 尾位换双微动作**「跳到发生处」(''=藏)/「去实体页」(无面板即藏);**点行=exhibit 登台**;主角行 R-6 静态脉点;**谢幕落账洗亮** ~1.8s 衰减) |

## 2. 引擎与状态

- **`StageDirector`**(`model/stage_director.dart`,纯状态机):六态 idle/following/pinned/curtain/failedHold(+anchored 视口子态);500ms 登台防抖(短操作永不登台)、800ms 静默+2400ms 驻留换台仲裁、优先级 humanGate>build>execution>subagent;**pinned 永不自动收**;failed 驻留红纱。`LifecycleSource` 三型——toolClose(常规)/poll(`trigger_workflow`:202 关帧绝不谢幕,**驻留到 durable `run_terminal` 到达**——`onRunTerminal` 净→停拍谢幕、败→红纱,R-10 已退役)。
- **宿主 `stageDirectorProvider`**(`state/stage_director_provider.dart`,autoDispose family):会话帧投影(tool_call open/delta/close)+ 人闸旗 + 唯一闹钟 advance(到期时刻);**poll 记账**——工具名留自 open、workflowId 解自关帧 args、flowrunId 解自入队回执,按 `workflowFrames(workflowId)`(entities 流 scope 订阅)听 `run_terminal` **按 flowrunId 匹配**并把节点 `run` tick 喂进 `flowrunProgressProvider`(tick 绝不猜——错 run 的进度是谎言,缺卷只是缺口)。`followModeProvider` 持久三档。
- **`touchpointLedgerProvider`**(`state/touchpoint_ledger.dart`):R-2 (kind,itemId) 聚合、durable 触点信号直 patch(绝不过 CoalescingNotifier)、410 重拉首页并入、keyset 无限滚。
- **`exhibitProvider`**(`state/exhibit_provider.dart`):用户钉的 Cast 展品——**刻意在导演器之外**(StageActivity 只能由 tool_call open 出生);`ExhibitStage` 美术馆开灯入场,attachment=**展品座**(缩略图+size/mime/sha256 前缀 mono),实体=身份面(id mono+动词史 KV),墓碑静态;驻留到关闭。
- **`rundownProvider`**:todo 整表替换直 patch + GET 水化。
- **R-15 activityBit**:右岛收起时,`AppShell` 以 `stageDirectorProvider.select(channels.any(live))` 点亮 `AnShell.rightActivity`(panel-right 钮柔 accent 点)。

## 3. 12/13 kind 量身舞台(`ui/stages/`,registry `stage_registry.dart`)

fn(地层→OpTicker→活代码窗→落定真 diff 徽)/document(书脊+前缀快进+R-9 元数据卡;`[[id]]` 内联药丸经 `stageMentionNamesProvider` 走 composer/编辑器同一条 MentionSource 缝**解真名**,解不出回落 id;id 集键按被渲切片算——流式绝不每帧扫兆级正文)/workflow(真画布图生长+判别式抽屉)/control(丝线决策梯+透传幽灵+否则徽)/approval(信笺+琥珀插值+timeout 人话)/trigger(四脸+R-16 落定只信 GET;nextFireAt **按分钟活钟**重渲,无动画)/subagent(单席 ReAct 尾+群像点卡换台+tokens 结算;主体卡内联**终端活窗**——分身当前工具流出 progress 时尾部就地滚动 ≤10 行,「一整页是终端用的」的克制版)/handler(方法架,W0 带路径通道同名 body 隔离)/agent(R-9 未提及槽 40% 旧真相)/skill(装订台+琥珀 allowedTools+$ 占位槽)/memory(记忆笺,图钉 REST-only)/mcp(接线现场+工具货架)。conversation 不设舞台;attachment=exhibit 展品座(无建造工具入口)。共同律:R-4 live 禁成功语义、R-5 edit 登台即 GET 旧真相、R-9 渐进开区、R-12/13 有界动画窗。

## 4. 导航(W6)

- **transcriptJump「re-anchor」**(`state/transcript_jump_provider.dart` 命令通道,`chat_transcript.dart` 唯一消费):近跳=`retargetCenter` 移锚零拉取;深跳=`?around=` 窗**整扇替换**(目标即 center sliver 首行,零 extent 估算)+双向续翻(`olderCursor`→`?cursor=`/`newerCursor`→`?dir=newer`)+「回到现场」pill(发送隐式离窗;`backToLive`=410 重同步同径;**归队即重钉贴底**——快速重拉可不换 State、转变显式重钉,否则读者被晾史中[真机抓获的真 bug,组测钉死]);落点洗亮 hold+fade;**跳转即解钉——流式帧绝不夺视口**(组测验收)。
- **场次条 `TranscriptToc`**(`ui/chat_toc.dart`,目录钮在 `ChatHead`):`GET /{id}/anchors` 全量锚点(循环分页),gate 琥珀置顶>newest-first 时间线(user 主锚加粗/`tools`「⚙ N 项操作」折叠簇/danger/compaction/abnormal 逐条),点锚=jump+自收;抽屉高 560(导航面配得上高度——一眼更多场次);fixture `listAnchors` 镜像 broker 规则(未决 interactions 骑首页顶),demo/测试同真。
- **R-14**:落定舞台眉部「跳到发生处」=`ConversationTranscript.messageIdOf` 走父链到回合锚(role 式 Subagent 台账无影,这是它唯一的锚)。

## 4.5 可发现性

图标控件(目录钮/跟随三档/Cast 双微动作/exhibit 头动作/R-14 眉锚)全带 **`AnTooltip`**(kit 新原语:Flutter Tooltip 机制穿设计系统皮——岛面+发丝边+meta 档,500ms 才现,无箭头无富体;gallery 有 specimen)+ semanticLabel。

## 5. a11y 章

四播报(`SemanticsService.sendAnnouncement`,polite):登台/人闸/失败/落定;live 流式区 `ExcludeSemantics`(播报+落定真相载义);全交互件带 semanticLabel;循环动效(FollowPill 呼吸/雷达环)骑共享 `PulseClock` 且 reduced-motion 冻结;洗亮/开灯等一次性动效 reduced 直落终态。

## 6. 契约(引用)

窗/锚 DTO 与 repo 缝 → [`contract.md`](../contract.md);后端 `?around=`/`?dir=newer`/anchors/`run_terminal`/tick `port` → [`references/backend/api.md`](../../backend/api.md) · [`events.md`](../../backend/events.md);触点台账 → [`domains/touchpoint.md`](../../backend/domains/touchpoint.md)。性能地基(增量 JSON 会话/revision memoize/PulseClock)与 perf 门禁 → 归档 WRK-061 §5/§10-W0。

## 7. 取舍与裁决(全部已清账,无待办)

**已实现(0708 清账批,口味=流式展示/显示舒服/企业级)**:活运行卷(poll 舞台 flowrun tick 覆层,本页 §2)/`AnTooltip` 原语+全控件应用(§4.5)/nextFireAt 分钟活钟/舞台滚动=pinned/`[[id]]` 真名解析(MentionSource)/subagent 内联终端活窗/场次条加高+fixture gate 镜像/demo 补种(60 回合长卷+附件展品座静物+trigger_workflow 运行卷一幕)。

**已裁决不做(与「不花哨」口味一致,非欠账)**:词级淡入与快进滚动完整动效版(业界流式标准即纯追加,稳定优先)/完整 AnCurtainCall 飞入行编舞(现=reveal 收起+落账洗亮已足)/dagre 增量布局+fitView 跟拍+FLIP 节点滑移(边线 CustomPaint 直绘目标位,节点滑行期箭头脱节 240ms 视感如 bug——瞬时重排是 graphviz 业界常态;活边 comet 已在实体页画布)/水脉闪舞台加戏(实体页画布已有 comet)/update_node 脉冲(op 已在判别式抽屉文本可见)/AnEnsembleGrid kit 提炼(单一消费者,提取即为抽象而抽象——原则 #8;群像壳已骑 kit `AnInteractive`)。

**真机边界(记录,非账)**:合成 CGEvent 滚轮/焦点进不了 Flutter 弹层——深跳窗与抽屉深滚的真机帧靠手动复核;gate 锚真机需真后端人闸(fixture/组测已镜像钉死)。
