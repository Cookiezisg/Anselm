---
id: WRK-068
type: working
status: active
owner: "@weilin"
created: 2026-07-11
reviewed: 2026-07-11
review-due: 2026-10-01
audience: [human, ai]
---

# WRK-068 「同轨」法典 —— 六族当家件 API + 版式文法(2026-07-11 拍板修订版)

> [`convergence.md`](convergence.md)(WRK-066)P2 产物。**2026-07-11 用户看帧拍板**(修订见 §拍板记录),据此冻结;
> 一切视觉争议回本档查表。拍板后:法典正文提取进 `references/frontend/design-system.md`(reference 级)。

## 对抗复审整改记录(2026-07-11,54-agent 复审 50 confirmed 全修)

用户抓获 diff 两幕与落定不同构 + 质量批评 → 全新上下文对抗复审(4 维度+逐条证伪,2 HIGH 真跑探针证实)→ 全部修复并入回归电池(`test/core/ui/tonggui_primitives_test.dart`)。关键裁决入法典:
- **diff live 与落定同一渲染路径**(仅行序不同:先全 − 后全 +,流中不做 LCS);live 有界贴底视口(codeViewport 档)。
- **代码/diff 双脸同钳**:`maxHeight`(AnSize 档)两脸同传 → 落定只解除钉底、高度零跳变;live 期 null 兜底 `AnSize.codeViewport`。
- **prose 活尾贴底惯用式**:reverse 只读滚动(Align+钳会把段落钉头,复审 HIGH)。
- **台账行弹性纪律**:左簇唯一弹性区,primary 与每枚 chip 各自可缩(刚性 chips 曾在 280 宿主溢出,复审 HIGH)。
- **窗**:钳高=内滚静默安全裁+底缘渐隐;宽安全(无界宽宿主收身);窗禁套窗 debug assert 可执行;footer=截断注记槽。
- **芯片**:全族单半径 pill;filled 承 AnBadge 强调重;copyValue=常驻示能槽(✓/✗ 原槽闪不改宽,失败诚实 ✗);truncate 按字素。
- **条**:`notes: List<AnStatNote>`(多注记并存,danger=mono/warn=label 两声);tone→色全走 `tone.fg`(删两处重抄)。
- **AnStickViewport 增 `fadeColor`**(白宿主传 surface,灰底退役)。bar 同构补齐:编辑器 copy 驻留走 AnMotion.dwell + AnTooltip。
- AnLedgerRow 补 `expandChild`;「展开全部 N」列表壳 **deferred → P4 吸收四套台账时落**。

## 批D7 落地(2026-07-13,D 轨收官——失败注入簇 H 逐条裁定 + 活问闸)

**D 轨全部 35 GAP 落定:30 done + 5 exempt(D-001/003/004/017/030),0 open。** 簇 H 失败注入钩经 fresh-context 研究逐条裁(seed-vs-豁免,不放水):
- **D-002 活问闸 ✅ seed**:`cv_ask` 会话种活 `ask_user` 门(streaming 回合带关帧 ask_user tool_call 无 result + kind=ask 未决 interaction[message+options])——琥珀活态待答,补齐 danger 门外的 ask 脸。
- **D-012 台账首拉失败 ✅ seed**:`DemoChatRepository.listTouchpoints` override 对 cv_flaky 首拉一次性抛→error+retry,重试成。懒加载 family 仅此对话错。
- **D-021 发送失败泡 ✅ seed**:`DemoChatRepository.sendMessage` override 对 cv_flaky 首发一次性抛→乐观泡失败态长出重试/丢弃(抛在回放前不排 timer)。
- **D-029 实体详情错误 ✅ seed**:新 `DemoEntityRepository` 子类 getFunction override 对 `fn_broken` 抛(rail 列出但详情 GET 抛)→autoDispose.family 仅选中时 error+retry,兄弟照开。
- **豁免五条(硬技术,非放水)**:D-001(uploadAttachment 无 conversationId 不可 scope,全局 arming 破 happy-path 首附件)· D-003(唯一活 gate=cv_gate 是 happy-path M8 须保持干净,第二 flaky-gate=人造)· D-004(failNextListConversations 在 build() 首拉即检,静态 arming 每启破整 rail)· D-017(_resync 单全局广播,非破坏性无持久泡,须脚本恰时 in-flight send)· D-030(demo osNotifierProvider=NoopOsNotifier[批D6])。
- **裁定原则**:passively-visible-on-open(开即见错:D-002/012/029)+ scoped-recoverable(D-021)=seed;action-required-transient 或 结构性全局(D-001/003/004/017)=豁免。三 override 全 one-shot、scope 到单一 seeded item,happy-path 零损。
- 验收=三份**数据级电池**(chat/data/flaky_demo[台账首拉抛→重试成·send 首发抛·实体 GET 抛]·chat/data/ask_gate_demo[未决 ask interaction+options·streaming 门无 result])+ fe-verify 全绿。**D 轨(demo 全展示)战役收官。**

## 批D6 落地(2026-07-13,D 轨 demo 可达性——分页/文档/toast/快捷键+OS 通知豁免)

簇 D-G 六 GAP(五做一豁免):
- **D-035 快捷键**:`demo_main` 镜像 `app.dart` 挂 `GlobalShortcuts+Focus(autofocus)`(⌘B/⌘\/⌘,/⌘±/⌘0 冷启即达)——handler 全纯 provider/静态调用,demo 全有,无门控。
- **D-023 文档全块型**:种 `Formatting Reference` 样章跑遍编辑器每种块——h1–h6 六档(锁大纲缩进不变式,h4–h6 折进 clamp level 3 仍列条目)+ 真 markdown URL 链接 + wikilink + 表格 + 有序/无序/task 三列表 + 引用 + 围栏代码。
- **D-031 活 toast**:`demoLiveToast()`(workflow.run_failed danger)+ `demo_main` 延时 6s `notifRepo.emit(...)`→`ToastDispatcher`(shell watch 活)弹右上 toast;danger tone 穿透开关。
- **D-005 rail 分页**:种 20 条**短真**历史对话(honoring #1:无空 filler,每行真 Q&A 开有内容),rail 越过 30 行页→loadMore+骨架脚。
- **D-011 台账分页**:`cv_p20` 马拉松会话种 54 触点(前 10 复用真快照开真舞台+44 合成 `viewed` 行,开时 `StageBodyFromTruth` error 分支诚实降级摘要、绝不崩),Cast 台账越过 50 行页。
- **D-030 OS 通知 = 硬技术豁免**:demo 的 `osNotifierProvider` 默认 `NoopOsNotifier`(**仅真 app main.dart:52 装 LocalOsNotifier**),OS 原生通知需真通知权限+应用失焦,零后端 fixture demo 的 Noop 永不触发——不可达是设计结论非放水(dispatcher 失焦径在 demo 走 Noop.show=空操作)。
- 验收=四份**数据级电池**(settings/entities 之外新增:documents/demo_fixture[全块型+大纲六档]·notifications/demo_toast[danger tone+durable 信号]·chat/data/pagination_demo[rail 30 页越+台账 50 页越,键集不重复])+ fe-verify 全绿。**簇 D-G 收官(唯 D-030 豁免)**。

## 批D5 落地(2026-07-13,D 轨 demo 可达性——failedHold 失败舞台收尾簇 C)

D-015 failedHold 是 live sidestage 的失败 phase,非落定 transcript 态——但 `sceneFromSubagentNode`(scene_from_truth:303)对**失败 subagent**(node.isError)落定即 `StagePhase.failedHold`(ledger 明许「或失败 Subagent」)。这是最干净的落定径,不污染 happy-path 流式脚本:
- `cv_show_nested` 补失败 subagent `sb0`(Subagent tool_call **status=error**→hydrateTurn `..status=b.status`→node.isError→subagentBlocks 收录)+ 嵌套失败轨迹(Grep「No files found」)+ error:true 结果。
- **顺带补全悬空引用**:该对话的 `get_subagent_trace` 结果早已列 `subagt_02`(status:failed,spawningToolCallId:sb0)但 transcript 无 sb0 块——补 sb0 使 trace 与实块自洽。
- subagent **无触点无 ledger**(stage_panel 第三源),其落定失败 run 经 `block:<id>` 合成行开侧幕即 failedHold+红丝带。
- 验收=**数据级电池**(fail_terminal_showcase_test D-015:从 cv_show_nested 建 ConversationTranscript→subagentBlocks 找 sb0→isError·sceneFromSubagentNode.phase==failedHold·subject.failed)。**簇 C 全 7 项(D-014/015/016/018/019/020/022)完工**。

## 批D4 落地(2026-07-13,D 轨 demo 可达性——chat 失败与终态六 GAP)

demo 展台此前全 `stopReason=end_turn`、全成功——六种失败/终态脸无从看见(D-014/016/018/019/020/022)。新增**一处集齐**的展台对话 `cv_show_term`「失败与终态」(手搓多回合,因 `showcase()` 单回合):
- **回合 1(卡级失败三张)**:`edit_workflow` morph 卡(+1 ~1 −1 节点+边 delta,ops-delta 形,D-014)· `WebFetch` **软失败**句「Failed to fetch」(status=completed 但 `webFetchOutcome.fail` 渲红——WRK-059 H2 诚实,D-016)· `run_function` **硬失败** `tool_result error:true`→status=error 红回执/ownsError(D-020)。
- **回合 2–4(三诚实终态横幅)**:`stopReason=max_steps` 琥珀(D-019)· `errorCode=LLM_RESOLVE_ERROR`+`stopReason=error`→「重选模型」CTA(D-018,`hydrateTurn` 把 message 终态投影进 turn.content)· `stopReason=error`+`errorCode=HANDLER_RPC_TIMEOUT`+errorMessage 通用红 error 横幅(D-022)。
- 验收=**数据级电池**(`test/features/chat/data/fail_terminal_showcase_test.dart` 四测:三终态字段·WebFetch soft-fail 分类·硬 error:true·edit_workflow ops-delta)+ showcase 编目测过(新卡全 cataloged)+ chat feature 全绿。
- **D-015(failedHold 流式侧幕态)留 open**:属 live streaming 阶段(sidestage phase),非落定 transcript 态,需失败节点/脚本帧,单独批处理(不并入落定态草率清)。

## 批D3 落地(2026-07-13,D 轨 demo 可达性——chat 侧幕六 GAP 补种)

chat 侧幕(右岛 Cast)按当前对话的**触点行**开幕,再 GET 该实体旧真相渲舞台。demo 置顶对话 cv_sync 此前只有 function/workflow/document/attachment/skill/mcp 六触点,control/approval/trigger/agent/handler 五 kind 无触点无快照→侧幕永无从开这五舞台(D-006~010);且无墓碑演示(D-013)。cv_sync 台账补 6 行 + 对应快照:
- **D-008 控制 / D-010 触发**:`amount_gate` ControlLogic + `cron_nightly` TriggerEntity——**正是 wf_night 图已路由的两个 ref**(图 gate/trg 节点),补快照后点 Cast 行开真身舞台(R-16:trigger 舞台只信此 GET 快照,不信帧)。
- **D-006 agent / D-007 approval / D-009 handler**:`ag_reconcile`/`apf_refund`/`hd_ledger` 三快照 + 触点,补齐仅存的三空舞台(agent 渐进开区 / approval 信笺 / handler 方法架)。
- **D-013 墓碑**:`fn_legacy_sync` verb=deleted 触点行(**不种快照**)——`stage_panel` 的 `!tombstoned && hasTruthStage` 门控使其走 `SettledBody(tombstoned:true)` 显墓碑、绝不 GET(对齐 cv_gate 危险交互删的正是 legacy_sync,叙事自洽)。
- 验收=**数据级电池**(`test/features/chat/data/sidestage_demo_test.dart` 三测:control/trigger 触点+快照 GET 成·agent/approval/handler 三快照有料·墓碑 verb + GET 被禁抛 StateError)+ chat feature 694 测全绿(cv_sync 从 7→13 行不破既有断言)。

## 批D2 落地(2026-07-13,D 轨 demo 可达性——实体 fixture 五 GAP 补种)

`demoEntityRepository()` 此前 control/approval 段恒空、版本历史仅 active 一版、无停车 run、图编辑器 ref picker 无 mcp 候选(D-024~028)。补种一个**自洽互锁的实体世界**(种子相互引用,非孤立堆料):
- **D-025 控制**:`ctl_quality` ControlLogic(pass `input.score>=0.7` / retry catch-all 分支)——**正是 wf_digest 图路由的 ref**,补种后图的 control 节点有真实体背书。
- **D-024 审批**:`ap_publish` ApprovalForm(CEL 插值 markdown 模板 + allowReason + 24h→reject 决策规则)。
- **D-026 停车 run**:新 `wf_release`「build→人闸→deploy」发布线 + `flr_park` 停在 `approve_deploy`(status=parked)——喂 `listFlowrunInbox`(左岛 flowrun 收件箱)+ 详情页停车信笺。
- **D-027 版本历史**:`handlerVersions`(hd_slack ×2)+`agentVersions`(ag_researcher ×3,最新在前),history tab 有轨迹。
- **D-028 ref 候选**:`mcpServers`(context7/filesystem)+`mcpTools`;control/approval 候选自上面 logics/forms **自动派生**(listControls/listApprovals 已有此缝)。
- 验收=**数据级电池**(`test/features/entities/demo_fixture_test.dart` 五测:分支端口/末支 catch-all·模板 CEL+决策规则·inbox 停车+信笺·版本轨迹倒序·mcp+派生候选)+ 实体 feature 179 测全绿(新 wf_release/种子不破既有断言)。

## 批D1 落地(2026-07-13,D 轨 demo 可达性——settings 三面板补种)

D 轨(demo 全展示)开台。`make demo` 挂的 `demoSettingsRepository()` 此前只种 keys/quota,记忆·MCP·沙箱三面板全空占位 → 用户 demo 看不到这三面的真实形态(D-032/033/034)。补种诚实数据态:
- **D-034 记忆面**:三行各态——`coding-style` **pinned·user**(金 pin 行)/ `user-timezone` user / `retry-policy` **ai**(AI 撰写态)。
- **D-032 MCP 面**:`context7` **ready** 带 2 工具(resolve-library-id/get-library-docs)+ `github` **failed** 带诚实 lastError(consecutiveFailures=3);market registry 两候选(filesystem/postgres)。
- **D-033 沙箱面**:两 `SandboxRuntime`(python 3.11.9 / node 20.11.0 已装)+ function owner(`sync_inventory`)下一 ready `SandboxEnv`(httpx/pydantic 依赖)。
- 验收=**数据级电池**(`test/features/settings/demo_fixture_test.dart` 三测:ready+工具/failed+错误·pin 过滤投影·runtime kind+env ready)——真机帧因 demo 冷启落 chat 非 settings、窗坐标漂移不稳,改数据级锁死种子正确性(fixture 是纯数据非渲染,数据锁足证面板有料)。

## 批5a 落地(2026-07-12,芯片族·五件收编+点族)

A-032/A-033/A-034/A-036/A-038/A-046/A-048 关账(A-031 剩 AnAttachmentChip、A-039 剩 function_stage opTicker 内点随 A-043、A-045 缓议——窗头裸字形 vs 芯片壳待帧裁,均留 open 注记)。**AnBadge/AnCopyChip 物理删除**(131+8 用点机械并入 AnChip;copyDone 死键退役),AnRefPill/AnPathChip/AnScopeBadge 降**薄预设**(名字保留,壳全走 AnChip;RefPill 自有知识=kind 字形单源+a11y 类型词+交互闸,PathChip=basename 切法,ScopeBadge=枚举 slang 表)。法典族三增量(签名外小参数,随批签字):
- **AnChip +5**:`tooltip`(静息覆盖——path/value hover 全文)/`semanticLabel`(a11y 覆盖,**静态芯片也承载**[Semantics+ExcludeSemantics 单节点])/**空标签守卫**(icon-only 示能形不留孤儿间隙)/**outlined 形不透明白岛底**(hover 提亮;灰泡上透明芯片读作破洞,承 AnRefPill 岛面)/`dot: AnStatusDot?` **强类型点槽**(拒任意子树;吸收 AnBadge.dot 与 op ticker 双脸)。**i18n 惰性化**:slang 仅交互径消费,静态芯片不问宿主要 TranslationProvider。
- **AnStatusDot.raw**:直喂色+`hollow` 空心环+`size` 档(dot 7/dotSm 5/swatch 10 新铸)——珠串/色点/fire 记号唯一实现;raw 形纯静态零帧。六处手搓圆点清剿(run_ledger×3/handler·trigger_stage/notification _Dot[6→7px 归档]/workflow kind 方块→族圆点 swatch 档,刻意裁决)。
- **AnFollowPill.jump**:静态回场脸(label 站点自定+`elevated` 浮影[AnOpacity.shadow=0.12 新档])——绝不呼吸不挂钟;吃 an_term_viewport._backToLatest 与 chat_transcript._BackToLivePill 两处手搓;_PillShell 内两处 token 算术(dot-2/iconSm-2)清为 dotSm/iconXs。
- **拍板点记档(建造者裁决,帧供否决)**:①RefPill 字面 body13 w400→族 meta12 w300(全族一字面;帧核可读性,否决则退半降级);②copy 芯片族声=outlined(与 path chip 一致);③AnSize.capsulePadY=1 新档(行内药囊竖距,inline 脸用)。
- 新 variant 全部 gallery-first(raw 点四形/outlined·copy·icon-only·strikethrough·tooltip 五 specimen/inline 嵌文本/jump 双态)+ tonggui 电池 7 测(dot 槽/空标签/host-agnostic/a11y/raw 尺寸/空心零帧/jump 静态)。

### 批7b/c/d 落地(2026-07-13,B 轨扫尾·台账 72 行了结——唯余 B-021 签字[B-045 已随复审整改关账])

三组单作者顺序建(间距→色调·图标→动效·状态),逐站点手工+逐文件 diff 目检;批7 合计翻台账 72 行(61 fix+8 证伪+3 拍板记档),B-021 留签字(复审勘误:此前误书「70 行/11 证伪」「批7d 25 行」——7d 实 23 行,证伪 8 行):
- **批7b 间距/尺寸(24 行)**:悬挂缩进走 AnIndent(emit 16→13 可见);徽章行 Wrap 文法定档(spacing=inline/runSpacing=stackTight,三处 s2→s4 可见);settings 控件槽/表单宽全走档(mcp 两表单 −80/envs tab +120/若干 ±20~50 可见,拍板记档);编辑器弹层入菜单轴+estHeight 自报;entity/document 浮层头折叠阈=实测头高替魔数;贴底 followSlop/光学微调 opticalNudge/图框 graphStage。**建造发现记档**:tool_card_search 原不 import tokens(map 假设破,analyze 抓回);B-025 map 与 7a 铸档冲突以 7a 拍板为准(tocPaneWidth)。
- **批7c 色调/图标(11 行)**:**AnToastTone/NotificationTone 双枚举物理删除**(64+n 处改型,toast/通知全走 AnTone+AnToneColors 单源;dispatcher 保留 warn/danger 钳);**runStatusColor 平行色系删除**(fromRaw 补 started/timeout/claimed **三**别名+三钉['fired' 自 G0 已有,复审勘误],珠串/台账/exec 全走语义脸——实质语义色变**两处**:**timeout 琥珀→红** + **claimed 灰→琥珀**[对齐 entities 侧 observability 既有映射,claim 事务瞬态;复审补记档],帧核签字·轻);私 alpha 清(segmented 0.5→disabled/switch→accentHover/TTC→dangerLine);微尺寸减法八站点清(dotSm/iconXs/ring 档,honesty 勾 10→8/rundown 环 9→7 帧核);handler '⏱'/'~' 文本字形→AnIcons.timeout/activity。
- **批7d 动效/状态(23 行)**:全裸 Duration 入 AnMotion 档(stagger/revealCap/travel/wash/autosave[500→600 归并]/searchDebounce/typeahead/toast 双档;**tooltip 500→dwell 600 归并**=唯一带行为感项,帧后手感否决则退 hoverIntent);reduced 双闸落位(follow_pill/radar_sweep→orAssistive);chat_transcript 裸 MediaQuery 禁令违例修;状态件归位十二站点(手搓灰字/哨兵 '…' →AnState inset/AnDeferredLoading+骨架/AnRailStates[notifications 托盘整面化,回正];storage 哨兵串作 factory-reset 判据→null 化主刑);loadMore→retry 四处;软失败双站点→AnCallout(warn);runStatusWord 三份并一+flowrun 域词两份并一(顺带修 running-未停车 误显「等待审批」);通知名引号入 locale(en 「」→“”)。
- **i18n**:+notifications.errorHint/nameQuoted、settings.limits.errorTitle/retry;−settings.mcp.planLoading;slang 产物入库。
- **B-043 圆角选档立法(拍板记档)**:84 用点普查证实五档=**尺度阶梯**(半径随表面尺度爬升):行内嵌体=tag4 / 控件·行悬浮·微浮层=button8 / chrome 面·流内轻卡·中浮层=chip12 / 机器窗·图框·transcript 白岛=card16 / 模态·壳=island20;胶囊恒 pill;**同心嵌套=内半径+内缩距是唯一合法圆角算术**(an_segmented 先例);无边框洗亮覆层不入面族。唯一真出格 models_keys freeTier 手搓 card-16 白卡→AnCard(16→12+竖距 −4,帧核)。
- 棘轮基线 16→**10 条目/12 处**;唯余 B-021(标题上距三方分裂)交用户签字。

**B 轨立法四条(scout risks 收编,随批成文)**:
1. **时长档铁律限视觉层**:widget 动效/防抖/驻留时长只用 AnMotion 档;state 层节流(300 合帧/400 持久化防抖)与导演器行为时长(stage_director 四常量=W2 拍板值)**成文豁免**(行为语义非视觉动效,注释锚定)。
2. **曲线档**:曲线只用 AnMotion.easeOut/spring;滚动 ensureVisible 的 easeInOut 豁免(双端缓动语义);count-up/mini-graph 的**幅度缩放公式系数**原语内注释锚定豁免(防机械清零打死自适应)。
3. **reduced 双闸选档**:装饰循环(shimmer/呼吸/雷达/转圈/打字机)=reducedOrAssistive;功能性一次揭示(展开/洗亮/入场)=reduced。
4. **表单内联错误=label(13)+danger+top:s8;整面载入失败=AnState(error)**;行内空态=AnState inset;rail 整面四态=AnRailStates。

### 批9f 落地(2026-07-13,A 轨编辑器弹层几何 dedup·overlay 高危区纯函数安全解)

A-104 done:
- **caret 弹层翻转几何 dedup**:mention(:82-88)与 slash(:160-166)**逐字重复**「estHeight 估高→layerHeight 比较→下溢且上容则翻上」——抽 `AnMenuSurface.caretPlacement(anchor, rows, layerHeight)→(left,top)` **纯静态几何**;关键安全裁决:**「overlay 卡死高危区」指 overlay 层机制/时序,非这段纯数学**,故抽纯函数不碰高危部分(box/layerHeight 的 findRenderObject 读留在调用点,只搬计算);宽档统一批7 B-019/020 已做;3 几何电池(默认下挂/下溢上容翻上/上不容仍下挂)。

**A 轨仅剩 A-113 一行 substantive open**:doc 编辑器头(全用族原语 AnInlineEdit/AnTags/AnText,仅布局 bespoke)→AnOceanHeader reading 变体 或 新文档头原语——**头部词汇设计决策**(AnOceanHeader 大改会波及实体海洋;新原语需拍板),交用户/专项设计裁定;A-004/006 defer(单 feature widget 升格 core=A-056 过早)、A-007/009 exempt(决策容器/轻量轨迹)、A-056/069/085=documented。**批9a–9f 共清 27 A 行,A 台账 32→1 substantive(A-113 设计决策)+7 documented,视觉六族收敛实质完成**。### 批9e 落地(2026-07-13,A 轨窗族 raw-mono 收编 + 两豁免裁定)

A-003 done + A-007/A-009 工程判断豁免:
- **A-003 raw-mono 回落窗**:15 处散置 `AnWindow(child: Text(raw,code,maxLines:N,ellipsis))`→共享 `rawMonoWindow(context, text, {maxLines, color})`(tool_card_skins);散置行数 12/20/40/200→**AnCap 四命名档**(monoError/Compact/Body/FullLines);视觉零变(参数化保各站点行数/色),15 站点由既有工具卡电池覆盖+新 helper 电池(行档钉/null 无界)。
- **A-007 豁免**:深查人闸=决策容器(card-16 白面+tone 边+**嵌套 AnWindow**[_evidence 内含])——三约束锁死无当家件可承(含窗故非叶子 AnWindow[窗禁套窗 assert]/card-16 需与相邻工具卡一致非 chip-12 AnCard/单消费者铸新原语=A-056 过早抽象)。手搓 Container 于此一之无二决策面恰当。
- **A-009 豁免**:block_tree_view=右岛轻量 ReAct 轨迹,已正确用族原语(AnDisclosure/AnChip/AnIcons/AnText),收敛到 ChatToolCard=过度工程/到 transcriptBlockRow=丢保真(同 A-094)。台账 note 授「或明记豁免」。

**A 轨剩 4 substantive open**:A-004 GrepContentView 升格 gallery + A-006 ToolHitList 升格 core(widget-to-gallery 大迁移)+ A-104 编辑器 caret 弹层几何 dedup(overlay 卡死高危区)+ A-113 doc 头设计决策;A-056/069/085/007/009=5 documented。**批9a–9e 共清 25 A 行(21 done+1 追认+3 证伪/豁免),A 台账 32 open→4 substantive+5 documented,余 4 是全战役最大 widget 升格/高危区/设计裁定,需窗族专项批或用户拍板**。### 批9d 落地(2026-07-13,A 轨手搓卡/头收编)

A-001/010 done:
- **A-001 审批预览卡**:tool_card_control_approval 手搓白岛卡(Container+BoxDecoration surface+card 圆角+hairline)→AnCard(SizedBox 保满宽);流内卡=chip 圆角(可见变化 16→12,B-043 一致,帧供否决)。
- **A-010 run 终端头**:run_terminal._head 手搓双行(icon+名+✕ / verb+metaLine+相位徽)→AnInspectorHead;缺的相位徽(AnChip)槽=**新增 subTrailingWidget**(次行值后的可选件,通用槽);度量 pixel-identical(padding/s6/字样逐字同源);+AnInspectorHead 电池。

**A-009 豁免·批9d**:block_tree_view(右岛 agent ReAct 轨迹)台账 note 授「或明记豁免」——已正确用族原语(AnDisclosure/AnChip/AnIcons/AnText),语境恰当的轻量轨迹组合;收敛到 ChatToolCard 生态=过度工程,到 transcriptBlockRow=丢折叠/嵌套/danger 保真(同 A-094)。工程判断豁免。

**A 轨剩 6 substantive open**:窗族升格 A-003/004/006/007(raw-mono 窗×10 统一/GrepContentView 升格 gallery/ToolHitList 升格 core/人闸壳 card-16 tone-border 变体)+编辑器 caret 弹层几何 dedup A-104(overlay 卡死高危区)+doc 头 A-113(全用族原语但布局 bespoke→AnOceanHeader reading 变体,边界情形);A-056 defer/A-069 豁免/A-085 判断题=3 documented。**这 6 是全战役最大架构升格(窗族=codex「更高野心版待建」+ A-104 overlay 高危 + A-113 头部设计决策),需窗族批专项或用户拍板,扫尾批不草率并**。批9a–9d 共清 23 A 行,A 台账 32 open→6 substantive+3 documented。

### 批9c 落地(2026-07-13,A 轨审批门共件 + 活尾裁决)

A-011 done + A-094 证伪:
- **共享 ApprovalGate**(A-011):三处手搓审批门(run_terminal._approvalGate / run_cockpit parked 块 / flowrun_inbox._ApprovalCard)逐字同构(AnInfoCard[approvalTitle/approval/nodeId]>prompt+可选 reason+AnActionGroup[approve primary/reject danger])→抽一件 `features/entities/ui/approval_gate.dart`;差异做参数化:`framed`(卡壳 vs 裸接[驾驶舱内联])/`collectReason`(**仅收件箱径能送 reason 到后端**——终端·驾驶舱 decide 无 reason 参,留 false 免死输入)/`showHint`/`busy`;reason 控制器归共件、经 onDecide 次参回传。四电池(framed 切换/reason 门三态/verdict+reason 回传去空白/busy 压双钮)+既有集成测试(workflow_gate/flowrun_inbox)全绿。
- **A-094 证伪**:NestedRunPane 活尾=AnWindow 内结构化块行目录(复用 transcriptBlockRow)+末行 AnShimmerText 微光,两既有原语组合;非 AnLiveTail 裸文本活尾第三形(压成纯文本尾丢结构行/isOpen 微光/块型判别六能力)——建造者请求准,角色不同不并。

**A 轨剩 9 substantive open**:窗族升格 5(A-001/003/004/006/007=更高野心版待建)+run 轨迹树 A-009(block_tree_view 迷你 transcript→共享块行)+run 终端头 A-010(→AnInspectorHead)+编辑器弹层 A-104(overlay 高危区)+doc 头 A-113(→AnOceanHeader 变体);另 A-056 defer/A-069 豁免/A-085 判断题记档=3 documented-disposition。**这 8 行是全战役最大架构升格(窗族=codex 自框「更高野心版待建」),需窗族批专项或用户优先级裁定,不在扫尾批草率并**。

### 批9b 落地(2026-07-13,A 轨编辑器簇·引用条统一+按钮 toggle 态)

A-101/103/106 done:
- **引用块左条统一**(A-101+A-103):三处手写引用左条(人闸自由答复 ring 1.5+line / 编辑器 2+lineStrong / markdown gripLine+lineStrong)→新档 `AnSize.quoteBar`(=2)+色统一 lineStrong;人闸处 AnSize.ring 误用(强调环 token 当条宽)归位,可见变化=1.5→2 宽+line→lineStrong 色(略强,帧供否决)。
- **AnButton toggle 态**(A-106,强化地基):AnButton.iconOnly 长 `toggled`(开态=accent 字形+accentSoft 实底+a11y `toggled` 语义);顺手 **MergeSemantics 修全 AnButton 潜在双语义节点**(外层 label 节点与 AnInteractive tap 节点此前分叉,读屏摸到无 tap 的标签节点——批5 chip 教训同病);编辑器 `_FormatButton` 手搓 toggle 退役,5 格式钮(粗/斜/删/码/链)改 AnButton.iconOnly+补 a11y 键(fmtBold/Italic/Strike/Code/Link 双语);gallery 补 toggled 样张+电池(toggled 语义钉+off 态无 toggled)。

**A-085 判断题记档**:编辑器选区浮条(chip 圆角+shadowPop)与 AnFloatingBar(button 圆角+shadowFloat)角色可辨(overlay-popover vs 画布 chrome,shadowPop 是覆层阴影语义)——不硬套,留 open 待窗族批统一裁决。

### 批9a 落地(2026-07-13,A 轨扫尾·机械/小件波——15 行关账)

A-083/087/099/100/102/105/107/108/109/110/111/112/114 done + A-012/A-115 追认/证伪:
- **A-112 封顶散数收档**:chat_tool_card `_capChars`→AnCap.receiptTail(4000)/log_drawer 私有常量组→AnCap.logHead(2000)·logTail(4000)·stderrTail(8192)[整渲阈=头+尾派生,不留巧合第三字面量]/skins `_windowCapChars`→AnCap.window。
- **A-087 条族最后一处**:flowrun `_summaryBar` 手拼 ' · ' 链→AnStatBar(文法 #3 唯一合法处;可见变化=文本行→条脸,帧核)——RunStatBar/legend 批3 已并,收起行回执尾=行内尾注豁免。
- **A-099 a11y 缩放**:tool_card_ecosystem `_issue`/transcript_peek `line` 的 RichText→Text.rich(RichText 不继承环境 textScaler,a11y 缩放此前不生效)。
- **A-107/110 Tooltip 归一**:run_ledger 珠串+gate 的裸 Material Tooltip→AnTooltip(全仓再无裸 Tooltip,仅 AnTooltip 内部实现一处);path_chip/code_editor 早已 AnTooltip。
- **A-108/109 gallery dogfood**:_GridCell/_cell 手搓有边容器→AnCard(dev 壳吃当家卡皮)。
- **A-111 缩略图归一**:attachment_pedestal 手搓 ClipRRect+Image+私铸 maxHeight:180→AnAttachmentThumb.single(与用户泡同档单图界,解码错降级诚实板,文件名作 a11y alt)。
- **A-114 文字链→钮**:notification 全部已读 手搓 AnInteractive+Text→AnButton ghost/sm(可见变化:accent 链→中性 ghost 钮,帧核)。
- **A-102 折叠阈实测化**:settings_ocean `_collapseAt=64` 私值→实测大标题块高−islandHead(同 entity/document 海洋,批7b 范式,不再私铸魔数)。
- **A-105 编辑器输入归一**:_LinkInputBar 裸 Material TextField→AnInput.seamless(无边、供嵌浮条壳;autofocus/mono/onSubmitted 保留,Esc 键盘监听+外点取消保留)。
- **A-083 热力条档化**:_countHeat 裸 40 宽→AnSize.heatBar(相对热力短条,刻意非 AnMeter——后者是整行配额表带 warn/danger 阈,角色不同)。
- **A-012 追认**:_FreeTierCard 批7 随 B-043 圆角立法已改 AnCard,台账行陈旧,批9a 追认关账。
- **A-115 证伪**:notification 分组小标早已用 AnGroupLabel(_SectionLabel 已不存在)。
- **core i18n 命名空间迁移**(批8 记档系统性遗留):an_honesty_ribbon/an_cast_row/an_follow_pill/an_channel_strip 四 core 件引的 `chat.stage.*` 键(ribbon×3/gatePill/livePill/moreChannels/verb.×8/tombstone/goToEntity/jumpToScene 共 10 键)迁 `feedback.cast.*`(批6a 立法「core 禁引 chat.* 命名空间」落实)——共用键的 feature 消费点(scene_from_truth/attachment_pedestal)同步改径,slang 产物入库,受影响两测试文件同步。
- **半成品接管记档**:批9a 首建者(Fable)限额中断,留 16 文件净改动(编译过)——逐文件 diff 目检确认全部干净后接管,补完 core i18n 迁移+A-105+台账关账+门禁(接管者纪律:死 agent 半成品必须逐文件核验再建其上,不盲信)。

**A 轨剩 17 open**:窗族升格 5(A-001/003/004/006/007)+run 终端·审批门共件 3(A-009/010/011)+编辑器引用块/toggle/头 5(A-101/103/104/106/113)+浮条壳 A-085+活尾 A-094(建造者请求证伪待裁)+defer/豁免 2(A-056/069)——批9b/9c 大手术。

### 批8 落地(2026-07-13,全量扫尾——coverage 分母 pending 清零)

27-agent 扇出对 321 pending 文件逐个过审(法典全条款为准绳)+2 件漏检主线亲审:**264 converged + 47 reviewed(边角记档) + 8 violation 全修**;ledgered 100 件按台账关账状态推进(55→reviewed,45 保留=仍被 A/C/D open 行引用)。分母现状:**294 converged / 121 reviewed / 45 ledgered / 0 pending**。
- **8 处违规修**:settings_prefs 岛宽默认 320 双源→引 AnSize.sidebar/rightIsland(防 token 改档静默分叉);an_channel_strip row−s8 算术→controlSm+透明边→whenActive 惯用式;**an_layer_diff 灰底退役**(surfaceSunken→白面+发丝,拍板 #1;「旧层」语义由 stratum 淡墨承载——**可见变化帧核**:agent/function/document 三舞台旧真相节选);an_setting_row modified 边 2→gripLine;an_sidebar_list loadingMore 假转圈(静态 run 字形!)→AnSpinner(a11y.loading)+失败尾补 button 语义(新 core 键 feedback.retry 双语);**syntax_highlighter w600→w400**(两档字重铁律,arg 组字重微降可见,测试同步);specimen spacing 裸 6→AnGap.inline;mount 6000×2→AnCap.window。
- **reviewed 边角记档五类**(过审员如实存疑,不为清账放水):①core 四件(honesty_ribbon/cast_row/channel_strip/follow_pill)引 chat.stage.* 命名空间——与批6a「core 禁引 chat.*」相抵,系统性遗留,**批9 统一迁 feedback.***;②error_boundary 预 theme 自含件直读 AnColors.light/AnSpace(取舍注释锚定);③an_overlay 浮层宿主定位 token 算术(core 结构性,注释锚定);④os_notifier Linux defaultActionName 'Open'(插件装配层无 Translations 管线);⑤brand_icon lg=islandHead*2 派生(注释锚定)。
- 漏检二件(interaction/limits 契约 DTO)主线亲审 converged。

### 批7 对抗复审整改(32-agent 六维,26 findings 证伪后 24 confirmed 全修)

- **台账 done 诚实性四清**(MED×2+LOW×2):B-016 锚点站点自己没迁(network/workspaces ×3 裸 480→formMaxWidth 补落);B-069 width 240 残站(storage 磁盘槽→ctlSlot,与 sandbox 同源);B-032 分诊补记档(notification ×2=opticalNudge 恒等,an_setting_row desc=inlineHair 1→2 **+1px 可见**,语义正确[label→hint 微对既有档]、波及全 settings desc 行,帧供否决);B-013 补记 stderr 视口 360→320(−40 可见,原语默认)。
- **立法与物理对齐**(MED×2):立法2 曲线七残站全数入档(count-up/term_viewport/编辑器×2/settings_ocean/transcript 洗亮/hit list 级联→AnMotion.easeOut,**曲线特征微变帧核**;ensureVisible 豁免加锚注释);立法1 豁免站点补锚注释七处(stage_director+state 层 300/400 全带「豁免锚」);widget 层唯一残留 3s 读秒登场阈入档 AnMotion.elapsedReveal。
- **B-045 关账**:AnIcons.task(done:) 单源字形对,编辑器复选框+markdown 任务项双消费——「B 台账全清(唯余 B-021 签字)」自此为真。
- **AnSpinner 补语义承载**(LOW):+semanticLabel(裸站必填缝),两处裸脚(loadOlder/场次条)接 a11y.loading;attachment chip 手搓转圈收编 AnSpinner(顺带 reduced→orAssistive 修档);follow_pill/radar orAssistive 突变锁补钉(回退 reduced 即红)。
- **claimed 点章同源**(LOW):_firingWord/_firingTone 补 claimed 分支(i18n firingClaimed 双语),与 lead 琥珀点同源——批7c 曾致点琥珀章灰打架。
- **timeout 字形语义**(LOW):Icon(AnIcons.timeout) 补 semanticLabel(a11y.timeoutBudget)——'⏱' 换图标曾致读屏只剩裸数字。
- **nameQuoted 补全**(MED):toast/OS 通知 _flat 仍硬编码「」→随 locale(行面批7d 已改,同源补齐)。
- **状态面双补**(LOW×2):run_terminal workflow 分支 running 无节点=loading(镜像 agent 分支);sandbox _InstallForm :available 失败=AnState error+重试(曾永久骨架)。
- **Wrap 文法落地补**(MED):立法后 14 残站 runSpacing s4→stackTight(值恒等拼写归一,design-system 断言自此为真)。
- **证伪二条记档**:_EnvList 空态闪帧(AnTabs FILL keep-alive 证伪)/洗亮 reduced 立法自洽(立法3 明文洗亮=reduced 档)。

### 批7a 落地(2026-07-13,B 轨扫尾·铸档+原语地基)

四组 scout(spacing/tone/icon-radius/motion-state)手术图定稿后先落地基,61 fix 行的档位与件一次备齐:
- **铸档 26 枚**(复审勘误:此前误书 21;AnSize 实 13 枚):`AnIndent` 新语义类(dot=13/icon=22,悬挂缩进按记号命名——feature 层 token 算术的结构性替代);AnSize +12(formMaxWidth 480/formMaxWidthWide 640/ctlSlot 240/ctlSlotLg 320/ctlSlotXl 380[长标签三段]/numField/tabPane 480[拍板记档:sandbox 360→480 对齐 mcp,帧供否决]/followSlop 32/opticalNudge 1/tocPane 双档/graphStage 200[190·200 两近值归并]/linkField 280);AnOpacity +2(sending 0.55/veil 0.85);AnMotion +9(**防抖三档** typeahead 150·searchDebounce 250·autosave 600[500 归并,+100ms 不可感] + wash 2200·stagger 30·revealCap 3000·travel 1100·toast 4s·toastLong 8s[UI 反馈 vs 事件通知双档,语义真实不归并])。
- **AnColors.dangerLine**(0.30 light/0.40 dark,镜像 accentLine 七点管线)——线级 danger 需明暗分歧 alpha,透明档编码不了;不投机铸 warn/okLine(零消费者)。
- **AnMenuSurface.estHeight(rows)**:浮层估高归面板自报(rows×row+2×s4),editor mention/slash 两处漂移拼算术退役在即。
- **新原语三枚**(gallery-first+电池):`AnSpinner`(唯一小转圈,strokeWidth 2 原语自持;**a11y 门=orAssistive**——收编即顺手修 an_state 误门 reduced 与 transcript/toc 两处零门控裸 spinner,B-071 关账)/`AnFadeRiseIn`(入场淡升,chat landing 私件升格,B-056 关账;与命中列级联角色不同不并)/`AnDropVeil`(拖放面纱,veil 档+指针穿透,B-070 关账)。
- **AnIcons.timeout**(lucide timer,B-047 备件)。

### 批6 对抗复审整改(36-agent 六维,30 findings 证伪后 25 confirmed 全修)

- **sub 归一进原语**(MED,探针实证):_RunRow 迁移丢 trim 防线——线缆 sub 常带首换行(LLM finalText/后端 error),maxLines:1 下唯一渲染行全空白「数据在而屏上撒谎」;纯空白 sub 还切双行几何留幽灵道(渲染门 isNotEmpty 与五处几何判据 `sub==null` 不同源)。修在 AnLedgerRow 内部:`effectiveSub`(trim+空白归 null)同源喂渲染与全部几何分支,同治 flowrun/subagent/runlog 全用点;两枚回归钉(首换行渲可见文本/纯空白行高=无 sub 行)。
- **expandChild 缩进随 lead**(LOW):无 lead 行主文在 0,披露体曾仍缩 18px 违「与主文左对齐」自述;缩进条件化+lead-less 钉。
- **AnKvRow.flag 补族内距**(MED):flag 行曾裸壳,混排列表两缘各错 8px;补 h:s8/v:s4 同胞内距+同缘钉。
- **ToolHitList 尾格契约刚性**(LOW→实伤):Uri.tryParse 对畸形 URL 返 null→全原始 URL 进无弹性 trailing,280 宿主标题压 0+RenderFlex 溢出(批6 真回归:旧 _WebHits 自占一行有界)。**修在源头非槽**:host 解析不出(null/空)即**不渲尾格**——畸形串不是凭据,截断渲染也不诚实;槽只加 ellipsis 兜底。两版错解记档:槽级硬顶界(首版 180)被全量测揭穿砸中合法宽尾(conversation 徽+时间行=widget Row,任何宽帽都让其内部刚性子件溢出),词档截断(次版)被 Ahem 字体测揭穿 24 字 mono=288px 仍溢 280 宿主;「尾格契约刚性——喂不出短凭据就不喂」成文进槽注释。webSearchBody 280px 回归钉(无溢出+原始串绝不上屏)。
- **_ToolHitCard 展开藏 tease**(LOW):展开态副行与披露体全文同屏双显;`_open` 时 sub 归 null(信息后移不丢)。
- **AnLadder 约束成文**(LOW):级裹 IntrinsicHeight,级内容含 AnWindow/LayoutBuilder 布局期即抛——禁令写进 doc 注释。
- **A-059 落到实处**(MED):monoLabel 曾零消费者(其声明用途 McpInstallForm env 动态标签组仍手搓)——env 组迁 AnFormField(monoLabel+required 骑基线+desc 副行)。
- **A-064 补漏**(MED):sandbox envs 节漏配 quiet(同面板其余 12 处全 quiet,双头脸)。
- **memory pin 真控件**(LOW,承批5 ✕ 立法):裸 GestureDetector 键盘不可达且 setPinned 全仓唯一入口在此=功能锁死;换 AnInteractive+MergeSemantics(button+toggled+label)。
- **测试假钉五清**(HIGH×1+MED×3+LOW×1,全部 mutation 实证再修再验杀):①批4 bare 缝钉被值形二分掏空(Map 全数在 _jsonTree 之前出口)→List 夹具重钉+反向边;②值形二分两分支零直测→AnKv 路径(bool 走 flag、绝不裸渲 true)+长值逐键路径两钉;③AnLedgerList exactly-cap 断言空真(同槽 State 复用陈旧 _showAll)→独立 Key 双泵+cap/cap+1 双边界;④flag a11y RegExp contains 空真→精确整标签「listening: 是」;⑤AnLadder 末级无降线零断言→Expanded-Container 计数钉。修后 7 突变体全部杀死。
- **杂项**:双 import 同行×3 拆行(批量迁移手误)/todo 头注释断句复原+测试注释旧名清/ToolIOSection 头注释决策树重述(值形二分后)/docsync 六处(CLAUDE.md 批6 行重述/A-067 关账落台账/34 行加总 32 勘误/族四现状段重述/契约 §4 行族行标结/chat-sidestage 活运行卷换语义点/design-system 行族条目重述)。
- **证伪五条记档**:serverTruncated 未接线(web payload 无 truncated 字段,兄弟用点形不同)/marketplace cast 可炸(上游已 stringify)/raw JSON 逃生口单向(设计如此,pin 有档)/hover 进度环(可接受记档)/tool-cards.md §6=冻结历史台账非现行规范(批1–5 先例一致)。

### 批6c 落地(2026-07-13,settings 字段块面板批——行族 34 行全清)

A-057/059/060/061/062/063/065/066 关账,**行族 34 行台账全数了结**(32 done+A-056 defer+A-069 豁免):
- settings 五面板 ~24 个字段块全走 AnFormField(mcp_forms._label ×7 删/network._field ×3 删/models_keys ×5/sandbox ×2[pinned 下拉↔自由输入条件子树两分支同壳]/workspaces ×4/memory ×3[Cmd+S 贴身包不动])——**可见变化:标签 13/w300/muted→族脸 strong/ink**(台账定性「偏离回正」,真机帧关卡)。
- A-057:retry 开关/数值行→AnField child 槽(「标签左·控件右」唯一行;标签在上的开关=反模式)。
- A-060:memory rail pin 进 AnRow leadWidget 槽、描述走 hint 换行(与 mcp 工具行同脸);**顺手修 leadWidget 语义剥除**(ExcludeSemantics 会重蹈批5 缩略图 ✕ a11y 覆辙——交互 lead 自带语义,原语不剥)。
- **建造事故二记档**:字段块批量扫描器在条件子树(sandbox version)与注记行(models_keys rotateWarn)两处搅坏代码——**逐文件 diff 目检抓回**;含条件/多行子树的站点必须手工。
- **帧欠账已清偿**(0713 复审整改后真机九帧逐个目检):workspaces 建面(Name/Color+AnSwatch 选中环)/network 三框+橙注记/mcp 手动表五字段块(transport segmented 同壳+诚实注记)/memory 编辑器三字段块(mono slug placeholder)+建行 pin·hint·meta 行+pin 点击变金+hover 揭示 Delete/models scenario defaults AnField 四行+Add key 四字段块(secret 眼)/sandbox Runtimes·Environments 双节头同 quiet 脸(A-064 补漏可见生效)。标签族脸(strong/ink)全面板落地无一破版。sandbox version 条件子树帧受 fixture 限(demo 无 runtime),widget test 已锁两分支同壳。曾记档的锁屏阻断始末留此为凭。

### 批6b 落地(2026-07-13,行族迁移 23 行关账)

A-049/050/051/052/053/054/055/058/064/068/070/071/072/073/074/075/076/077/078/079/080/081/082 关账(A-056 defer 记档:map 编辑器=表单机器非键值陈列,单消费者过早抽象,AnKv.map 规格留档待第二消费者;A-069 主行豁免=契约 §7):
- **台账双件四并一**:RunLedger/_RunRow(A-070/071半/072)与 FlowrunNodeList/_nodeRow(A-071另半/076)全走 AnLedgerRow+AnLedgerList;flowrun 状态点**归左**(法典②,曾是族内唯一右点)、kind 字形降首枚 chip、错误行走 danger 副行;两处「展开全部」手搓删,flowExpandAll 键退役;lead 色续走 runStatusColor(fromRaw 缺 started/fired/timeout 别名,换源会变色——记档)。
- **命中门收编**:_WebHits(A-078:15 档越锚/私铸拼字体/420 魔数三宗随行退役)与 marketplace(A-049:目录枚举归门,外层 AnWindow 随撤防套窗)投 ToolHitList(onOpen 外链通道);_ToolHitCard(A-079)→AnLedgerRow(描述 3 行→1 行 tease+点行展开全文+schema 树,信息后移一击不丢)。
- **清单归一**(A-053 改道):TodoChecklist 渲染退役并入 AnRundownList(chat 泡与侧幕 Rundown 两副面孔归一,原则 #8);stage_panel._TodoRow(A-073)→AnRow leadWidget(度量重抄退役,chevron 随行惯用式 hover 换 lead=与同列舞台行同脸);_RunProgressSection(A-074)→AnLedgerRow(语义点替三态图标,iconSm-2 算术亡;' · ' 手拼亡)。
- **共件两枚**:ControlBranchRow(A-054:概览双行脸胜出——inspector 单行省略丢 CEL、emit warn 徽违文法 #6 随脸退役;独立小文件自带 i18n,detail_sections 成文 i18n-free 不进);control_stage 判别梯(A-075)迁 AnLadder(骨架归梯,级内容自持;chat 第二套梯 tool_card_control_approval 记扫尾批+法典防第三套)。
- **toolIntent 升公**(A-080):_intent/×2 私件+12 内联抄收编 17 用点;gap:false 唯一合法位=workflow edit(条自带上距);**建造事故记档:批量脚本在裸 Text 位吃掉 morph 块,diff 审查抓回手工复原**——批量文本手术后必须逐文件 diff 目检。
- 小点波:双空格中点×2(A-052)/托盘段头双件→AnGroupLabel(A-058,en 大写化记档)/documents 段标×2(A-081)/sandbox envs 节头→AnSection(A-064)/gallery _navRow 吃 AnRow 狗粮+侧栏面证伪(A-068:AnIsland=浮卡角色不符,dev 壳豁免)/bool flag 行×3(A-051)/handler 身份段去重(A-055)/model defaults→AnFieldSection+AnKv(A-050)/_MetaRow→AnKv dense(A-082,path wrap 保尾段)/**ToolIOSection 两刀**(A-077:节头 12→13 回正;逐键列值形二分——全短标量 map→AnKv dense+flag,长值→逐键 AnFieldSection;批4 bare 缝零接触)。

### 批6a 落地(2026-07-12,行族地基九件)

行族当家件长全后续迁移所需的槽,全部 gallery-first+电池:
- **A-067 关账**:AnKv/AnKvRow/_KvTagsRow 物理拆出 an_field.dart→`an_kv.dart`(API 逐字零变,埋件难寻即解);barrel 加 an_kv、**撤 an_lead_value**(几何引擎内化,feature 禁直用——全仓零 feature 消费已核);**族四排布选型查表入法典**:身份行/头=AnTwoZone|键值列表=AnKv|标签在上=AnFieldSection|台账·命中行=AnLedgerRow|AnLeadValue=core 内部键值几何引擎。三套并存=成文分工非收敛对象(几何角色互斥)。
- **AnLedgerRow 三槽**:`sub`+`subTone`(主文下副行,danger=错误码声;与主文左对齐——feature 层 iconSm+s8 缩进算术自动消灭)/`measure`(右簇 tabular 耗时,居 meta 铁线之左——拍板 #4 不破)/lead 定宽 iconSm 格(点/字形混列主文左缘不漂)/mono:false 标题脸→全墨(族内既有裁决)/expandChild 缩进原语自持(文法 #4 的禁令针对 feature 层算术)。
- **新原语 `AnLedgerList`**(法典族四④):唯一「展开全部 N」逃生口(cap 是列表级关切,行件无从知晓兄弟数;异构头件留壳外);i18n `feedback.showAll` 新键(core 件禁引 chat.* 命名空间),chat.tool.flowExpandAll 待迁移后退役。
- **新原语 `AnLadder`**(A-075 裁决:两 scout 相左,自裁=建):判别梯骨架(序号圆+发丝降线+内容槽),只 owns 骨架;与 AnStepper(横向进度器,有「当前步」)角色不同不并;「决策梯骨架=AnLadder」入法典防第三套。
- **AnRow `leadWidget` 槽**(A-073 前置):自定义 lead(进度环)进既有 icon 定宽格,collapsible 同法 hover 换箭头;assert=leadWidget 独占(icon+dot 合法共存为旧约,dot 优先——复审抓过紧 assert 破 12 测,放宽记档)。
- **AnKvRow.flag** 具名构造(A-051 前置):唯一 bool 渲法(✓ ok/— faint),a11y 念本地化 是/否(裸字形读屏念「对勾」;新 a11y.flagYes/flagNo 双语键)。
- **AnFormField `monoLabel`**(A-059 env 动态标签组前置)。**ToolHitRow `onOpen`** 外链通道(A-078 前置:web 命中当年绕门真因;优先于 kind/id 面板深链)。

### 批5c 落地(2026-07-12,settings 键帽/色板专批+尾项裁决)

A-027/A-028 关账 + A-031 尾项改判关账 + A-045 归属改判:
- **新原语 `AnKeycap`**(独立原语,刻意不进 AnChip——芯片=被动小标签,键帽=带 idle/recording/error 状态机的按钮级输入控件):mono kbd 板三态;**刻意不可聚焦**(不渲 Focus/AnInteractive,仅 MouseRegion+GestureDetector——settings 战役焦点序教训:录制 Focus 不容抢焦,回归钉断言子树零可聚焦节点);录制状态机/Focus/i18n 全留面板层。边宽默认 1→hairline 归档。
- **新原语 `AnSwatch`**(「色即内容」原语,与 AnStatusDot 语义状态色两类不并件):dot 10 身份点/pick 22 取色格(badge 档)+选中环(手搓 2px→**AnSize.ring 1.5 档位归一**,记档);可点格 AnInteractive+selected 语义(不透明色盘透不出 hover 墨,环即信号)。**kAvatarPalette 六色 hex 表+parseHexColor 从 workspaces feature 迁 core**(文法 #6:feature 不私铸色表);_ColorDot/_ColorPicker 手搓删。
- **A-031 尾项改判**:AnAttachmentChip=两行复合附件控件(字形+文件名+meta+✕+上传生命周期),非小标签芯片——几何自持合理(LTRB 全 token,右缩因 ✕ 自带命中距),判非族内,A-031 全项关账。
- **A-045 归属改判**:批5 后三套复制件已并两套;WindowCopyButton=窗 chrome 示能(与 AnCodeEditor copy 条同类),非芯片单元——芯片壳(即便 icon-only)会给每扇机器窗头加边框重量,违轻盈;剩余「窗头 vs 编辑器条」双 chrome 记 B 轨扫尾候选。

### 批5 对抗复审整改(37-agent 六维,29 findings 证伪后去重 20 修理点全修)

- **a11y 双修**(MED×2,探针实证):①AnAttachmentThumb.onRemove 曾把 ✕ 塞进像素的 ExcludeSemantics——读屏摸不到唯一移除口;重构为语义核先组、✕ 后叠 Stack 同胞活按钮,回归钉 bySemanticsLabel 锁死。②AnChip 交互径裸 Semantics 包 AnInteractive 分叉「死标签节点+丢词按钮」双节点→ MergeSemantics+ExcludeSemantics 并单节点(承旧 AnRefPill 契约)。
- **行内囊截断回归**(MED):AnInlineCapsule 曾 maxLines:1 强制省略——长 CEL/[[id]] 名在行内无 hover 逃生口;改**可换行禁截断**(被收编的手搓药丸本可换行),gallery 补超长换行压力样张。
- **hover 渐变回归**:AnChip 改 AnimatedContainer(AnMotion.fast,reduced 即时)——预设化曾静默丢掉 AnRefPill 的功能性微反馈动画。
- **A-024 关账不实**(HIGH):「6 处私抄」实清 1 处——补清其余 5 处(lifecycle×2/entity_get 头/search onRowTap/conversation),新增唯一导航闭包 `goToPanel` 进 tool_card_nav、toolNavPill 也骑它。**A-044 漏网 1 处**(HIGH 台账不符):runlog:241 三元式(本批亲手换过壳却留下)补迁;界外注记勘正。
- **测试诚实**:semanticLabel 测试同串空真→异串;「零帧/无挂钟」注释宣称→真断言(transientCallbackCount==0);gallery jump specimen Row 里 height-spacer 轴向笔误(三丸贴脸)修 width。
- **申报补录**:_PillShell 尾 chevron iconSm-2(10px)→iconXs(8px) 为档位收敛的刻意裁决(-2px,批5a 漏申报,此处补记);icon-only specimen 补齐(「五 specimen」宣称成真);AnInlineCapsule 补 gallery 专属条目(warn 琥珀囊脸首次可见);belt 死参(c/live)清;孤儿注释×2 删;design-system.md/entities.md 芯片族条目随批重述(批4 先例=reference 同提交)。
- 证伪 3 条记档:test/ 探针散件=并审 agent 瞬态非交付物;「六处圆点」计数按字面口径可复现;census 残留(该 verify agent 撞会话额度未完成,census/blueprints 的 AnBadge 残留经建造者自查:census 为快照文档带勘误横幅,blueprints 已有批4 读法勘误——批5 顺手在勘误横幅补 AnBadge/AnCopyChip 读法)。

### 批5b 落地(2026-07-12,手搓 chip 清剿+行内药丸+truncate)

A-024/025/026/029/030/035/037/039/040/041/042/043/047 + 顺手 A-005 关账(A-027 键帽/A-028 色板**缓到批5c 专批**——settings 焦点序高危区[快捷键录制链],不在马拉松尾部rush;A-044 迁 23 处、语义各异的 4/8/80/120 界外注记)。增量:
- **新原语 `AnInlineCapsule`**:唯一贴基线文内壳(WidgetSpan 专用;软 tone 底+tag 圆角+capsulePadY 发丝距+宿主字体 height 1.0);{{CEL}} 琥珀囊/[[id]] 散文药丸/cel-grow 引用三处手搓并入;**AnRefPill.inline 改骑它**(kind 字形作 icon)——文内壳一件一实现。
- **编辑器提及换皮**(A-029):LineHeight 基线壳留 core/editor(core/ui 禁 super_editor),内壳=AnRefPill.inline;纯展示无手势,光标命中/IME 不破;编辑器 53 测全绿。
- **op ticker 双脸同构**(A-043):AnChip dot 槽两脸恒在(live 空心中性/落定实心 ok,只翻填充=零跳变);_DiffBadge 并入当家条(runStatBarOf 长 `extraStats` 前置缝;**out==null 兜底渲 extraStats-only 条**——旧同胞徽不随回执缺席,复测抓获)。
- belt/morph/lock/current/provenance 五族手搓删壳:morph 半透边(alpha 0.5 私调)→全 tone 边、belt settled 满墨→族声、provenance 裸灰字→真复制芯片(旧注释谎称 mono copy-badges)、_navPill 私抄×2→toolNavPill(A-024);AnAttachmentThumb 长 `onRemove`/`removeLabel` 槽(composer 手搓 Stack 退役)。
- **truncate 迁移**(A-044):23 处三元式→`truncate(x, AnTrunc.*)`;10/12→id 档、24→word、40/48→line(10→12 与 40→48 档位归一=刻意收敛,测试期望随迁)。

## 批4 落地(2026-07-12,窗族整体替换)

A-002/A-008/A-016/A-017/A-018 五条关账:**ToolWindow 物理删除**(19 文件 44 用点机械换 AnWindow,含 12 处独用 import 清尽),ProseWindow/MemoryNoteCard 白卡壳并入 AnWindow(阈值进 AnCap 档),gate payload 窗/agent 舞台 prompt 窗/document 舞台活散文尾换窗,双日志抽屉合成唯一 `LogDrawer`(双端 2000+4000+stderr 分段为准,`dossierLogs` i18n 键退役并 execLogs 计行统一)。法典增量:
- **ToolIOSection 长 `bare` 槽**(复审 HIGH 的修法):台账行展开内容已居窗内,值渲染须作者态显式无壳——**叶子律禁嗅探兜底**,谁在窗内谁声明;runlog 回归测钉死(展开后全卡恒一扇窗)。
- **IntrinsicHeight×AnWindow 禁忌记档**:窗内有 LayoutBuilder,固有尺寸询问必炸——双列同高一律显式 SizedBox 档高(document 舞台脊+窗 = AnSize.proseStage 双侧同传)。
- **AnSunkenPanel header 槽随 ToolWindow 退役**:唯一住户=用户聊天泡(泡非窗,灰=「我说的」材质);gallery/capture 样张同步。
- **AnStickViewport/AnTermViewport 渐隐默认融白**(fadeColor ?? surface,灰井默认随族一退役);bash 命令回显交 header 槽单行省略(mono 声保留)。
- **新铸档**:AnSize.proseViewport=340(落定散文窗折叠高)/proseStage=220(侧幕活散文尾)/proseStageFail=260(失败救援视口);AnCap.proseFoldChars=480/proseFoldLines=10/noteFoldChars=900(三处同款长文折叠阈归一)。
- 批1 记档的**过渡态**(mount/exec 活白窗、settled 灰凹面)如期愈合——全 App 机器产物容器自此一脸。

### 批4 对抗复审整改(22-agent 六维,16 findings 证伪后 14 confirmed 全修)

- **单体窗约束直通**(HIGH,探针实证 RenderFlex 溢出+贴底钉死亡):AnWindow 夹层 content Column 给非弹性子**无界主轴**(Flex 布局规则)——紧高宿主(侧幕活散文尾的 proseStage SizedBox)的内视口失界即溢出 500px+ 且短内容钉头。修法=head/footer 皆空时**跳过夹层、约束直通 body**;回归钉入 convergence_primitives(40 行尾不炸+短尾贴底),mutation 亲测可杀。
- **假钉清算**(HIGH,mutation 实证):runlog「展开后恒一扇窗」回归钉的标量夹具走逐键内联路径、bare 从未被消费,删掉 bare:true 测试照样绿——夹具改**嵌套 Map**(≥2 键+非标量值)踩到 _jsonTree 出窗缝,两处 mutation(删 bare 用点/让 _jsonTree 无视 bare)均可杀。**教训:回归钉必须 mutation 验杀,「断言过了」不等于「钉住了」**。
- **bare 合同补洞**:①prose 分支曾无视 bare(ProseWindow 即窗,窗内 prose 值必套窗)→ bare 时渲裸 AnMarkdown;②bare 脸曾随壳丢掉全量 copy(显示可截、copy 永不截)→ 截断注记行尾补 WindowCopyButton;各有回归钉。
- **注记进 footer 槽贯彻**(规则④):io_section/_monoWindow、lifecycle activate、mount MCP 体三处窗外兄弟注记全部移入 AnWindow.footer。
- **bash 命令出口**:单行省略 header(族一律)后长命令无处看全 → copy payload 改**完整终端记录**(`$ 命令\n输出`)。
- **LogDrawer stderr 分段改 opt-in**:exec 日志是任意函数打印,无条件切分会给撞串行贴假「server stderr」红标——仅卷宗(splitStderr:true)开启,exec 侧回到合并前语义。
- skill 舞台落定散文折叠高 320 裸数→AnSize.proseViewport 同档;A-017 关账注记「三处」勘正为「两处」;契约 §4 窗族行/census 缺口 #1·#3·#12·活尾行随批关账。
- 证伪 2 条记档:LogDrawer 私有截断常量组=从 dossier 逐字迁入非新散置(A-112 open 在案);「19 文件 44 用点」按「原位机械换」口径机器可复现(51 用点全账=44 机械+3 迁 LogDrawer+4 壳并入)。

## 批3 落地(2026-07-12,条族四并一)

A-088/A-089/A-090/A-091 四条关账:_InvokeStatBar/_RunFooter/ExecResultBar/RunStatBar **物理删除**(注释层残留同批清尽),全部并入 AnStatBar;workflow legend 手链同批并入(stats-only 条);块级 ' · ' 渲染链只此一源(文法 #3;残余记 A-087 收窄:收起行回执尾=行内尾注豁免、flowrun _summaryBar=窗首表头待窗族批)。法典增量:
- **AnStatBar 长 `leading` 槽**(前导凭据=条的主语 pill,词徽之前;尾随凭据仍走 chips);gallery 补 leading 样张。
- **timeout 陷阱记档**:AnStatus.fromRaw 无 'timeout' 别名(会折 idle 丢危险色),invoke 站点显式 err 映射承重、有测钉死;runtime 'running'=驻留健康绿(域覆盖,非 fromRaw 在飞 accent)。
- runStatBarOf 适配器接 **18 用点**;envFix 缩进改**结构化悬挂**(icon 独立列+Expanded,文法 #4 裸算术清;icon 改顶对齐,光学差 ~3px 接受);exec 彩字→词徽、invoke 空格→' · ' 链、灰阶归一(restarted/stopped/tokens faint→muted;legend 节点计数 ink→muted)——刻意收敛。
- **间距记档**:条自带 top s6 为族节奏——replay 侧删手工 SizedBox 防双距;legend 侧 summary 去底距对齐 metaOnly 分支;**getFlowrunBody 体首多 6px 前导=接受**(统一节奏,不为单点加 flush 开关)。

## 批2 落地(2026-07-12,代码族)

A-019/020/021/022/023 + B-002 全关。法典增量裁决:
- **族二两脸一壳全落**:Write/builds/Edit/fn·hd 舞台全部 live↔settled 同一 AnCodeEditor/AnVersionDiff、同 AnSize 档(codeViewport=320;新铸 **codeViewportSm=160**≈8 行给 handler 方法架书脊)。**缺口 A 真 bug 修**:落定钳移到 body 层(bar 在钳外,与 live 视口同位)——旧整框钳让落定矮 44px,违零跳变;有测锁死。
- **live 脸 O(tail) 内建**:切尾(尾 AnCap.window 字符对齐行首)+**行号续排**(增量头行计数,行号从真实行号续、诚实示「上有更多」);MB 级 Write 流式期不再 O(全文)/帧。
- **AnLiveCodeWindow 四能力退役判决**(逐项记档):整行按住(对内容撒谎+行号错位)/尾窗物化(由切尾替代)/行数 CountUp(行号槽即诚实计数器,bar 加 live-only 件违零跳变)/逐行淡入(逐行 widget 与落定体结构分叉违同体律)。
- **AnFadeCollapse 在代码两脸场景退役**(展开即高度跳变,与同档钳互斥);实体页(settled-only,无 live 脸)保留折叠+**collapsedHeightFor(lines,reading)** 几何口(B-002:算术归族头,chromeHeight 降私有)。
- **langOf/langOfEntityKind 归 core**(族二规则④落地);memory_web 活便笺**归族改判**:散文非代码,走 AnLiveTail prose(与 doc/skill 稿同判)。

### 批2 对抗复审整改(23-agent,16 confirmed 全修)

- **diff 孪生件同病**(HIGH,探针 352↔320px):AnVersionDiff 落定钳同修到 body 层(bar 在钳外)——两族头钳位同构,diff 零跳变有测锁死。
- **有界宿主静默安全回归**(探针 72/152px 溢出):编辑器/diff 的 body 钳在有界宿主下骑 Flexible(矮宿主裁不炸),无界宿主才裸钳。
- **live 换源守卫强化**:仅比切点的守卫漏「同 State 等长/变长整替」(在途→close 快照字节可不同)→ 增 O(1) 头部采样探针+裸长度缩短门,任一失配全量重算;**多帧增量与换源有测**(突变 `+=`→`=` 可杀)。
- **handler 舞台落定脸补同档钳**(复审:落定不传 maxHeight=160→2100px 跳变,违自家新立文法)。
- **「落定仅解除钉底」措辞失实改判**:高度与 chrome 零跳变;**落定视口静置于顶**(档案从第 1 行读起)——记录在案的裁决,API 文档同步。
- coverage 诚实性:function/handler_stage 撤回 converged(基线仍挂活违规)→ ledgered;台账例证引用已删文件清理。

## 批1 落地与复审整改(2026-07-12,活尾族+描边卡)

批1 = 活尾族收敛 + stages 五处手搓描边卡。落地后 35-agent 全新上下文对抗复审(6 维)26 confirmed / 3 refuted,全修。法典增量裁决:

- **族六 API 增量**:①`bare` 无框脸——内容流内联尾(thinking)不披机器窗(拍板 #6「随窗白框」限机器产物尾,内联散文豁免);②**O(tail) 内建**——三脸先反向扫切尾(+`AnCap.window`=6000 字符帽,新铸档)再折叠/排版,调用方可直喂 MB 级缓冲(复审:调用侧契约必被忘,族头自己扛);③prose 脸补**溢出顶渐隐**(滚动 metrics 几何驱动,绝不 TextPainter 预排版);④**prose/mono/term 流式期只读不可滚**是族契约——回看=落定后展开(thinking 旧「可上滑回看」能力刻意退役,复审记档)。
- **族一 API 增量**:`child` 可空=**头独窗**(刚开播无话可说的卡不付头体死距);`footer` 语义放宽为**体下 muted 注记槽**(截断注+结算行——原「仅截断注」被同批 subagent 结算行用法证明过窄)。
- **新原语 `AnFocusRing`**:不透明可点面(AnWindow 同席卡)的 hover/键盘焦点示能——窗面不透明透不出背后着色,改画卡外 accent 环(WCAG 2.4.7);与 AnInteractive 配对;gallery 有形。
- **AnTermViewport 增 `fadeColor`**;run_terminal fn/hd 采用**两脸同件**(运行中回看不丢+落定不裸渲 ANSI+零换脸)——「有界回滚终端窗」确立为流式 log 的档案级形态,6 行尾只配 progress 级信号。
- **过渡态记档**:mount/exec 等活脸已白窗、settled 仍 ToolWindow 灰凹面——同卡两材质是批次序的过渡态,窗族批(ToolWindow 整体替换)愈合,不单修。

## 拍板记录(2026-07-11,用户看六族真帧后修订)

1. **灰底内容容器材质全废**:除**用户消息泡**(气泡语义,非窗)外,全 App 不再有灰底内容块——含 GitHub 式无边框浅灰。窗族从「两脸」改为**一脸:白底 + hairline 边**(业内白卡派:Linear/现代 macOS;与 AnCodeSurface 天然统一)。交互态灰(hover/输入框/选中)不在范围。
2. **代码 live = 全量 + 高亮 + 行号**(推翻「尾 8 行纯 mono」):点开=用户主动要看,给全部;装**有界贴底视口**(AnStickViewport:内容全在、可滚、默认钉底跟最新行——transcript 行不背无界墙)。live→settled 零跳变(同壳同高亮同行号,唯一区别=视口解除钉底)。高亮性能走逐行记忆化(C 轨)。
3. **diff 壳与编辑器壳同构**:顶部同一条 bar——左 copy + wrap,右上角 **+N −N**(替语言标);live 两幕住同一壳。
4. **台账行两端对齐铁线**:右侧 meta 右缘必须齐成一条垂直线(文法 #1 的应用)。
5. **窗禁套窗**:窗是叶子容器,窗与窗之间靠间距分隔、不靠嵌套(白上白双边线贴脸=丑)。
6. 活尾随窗变白;工具卡主行本战役不动(豁免,记契约 §7);芯片双形/条族四并一/文法其余各条照单。

---

## 族一 · 窗(机器产物容器)—— `AnWindow`

**现状(批4 后)**:一壳定于一尊——`AnWindow` 是全 App 唯一机器/内容容器;ToolWindow/双日志抽屉/ProseWindow·MemoryNoteCard 手搓白卡壳已物理删除或并入(approval 信笺/subagent 卡批1 已并;ProseWindow/MemoryNoteCard/LogDrawer 保留为族一之上的**具名薄投影**——排版/折叠/截断策略,不再自带壳)。

**当家件**(拍板修订:一脸):
```dart
AnWindow({
  Widget? child,             // 可空=头独窗(刚开播无话可说的卡)
  Widget? header,            // 左头槽(命令回显/标题行;强制单行省略)
  List<Widget> actions,      // 右动作槽(copy 等,chip 族件)
  double? maxHeight,         // 封顶(AnSize 视口档,禁裸数)
  bool collapsible,          // 超高 FadeCollapse(展开/收起文案内建)
  Widget? footer,            // 体下 muted 注记槽(截断注/结算行)
})
```
**规则**:①**唯一脸=白底+hairline 边+card 圆角**;灰底容器材质全 App 退役(用户消息泡唯一例外,气泡非窗)。②**窗禁套窗**(叶子容器;窗间距分隔,不嵌套)。③内容不嗅探——窗是纯壳,内容由 AnCodeEditor/AnMarkdown/AnJsonTree/AnLiveTail 等组合进 child;**代码/diff 自带 AnCodeSurface 壳,不再套窗**。④截断注记("已截断,N 字符")作为窗的内建 footer 形态。⑤日志抽屉 = `AnDisclosure + AnWindow` 固定组合,双端截断统一(head 2000 + tail 4000)。

## 族二 · 代码 —— `AnCodeEditor` 长 live 形态(强化地基的原型场景)

**现状(批2/批4 后)**:两脸一壳全落——live/settled 同一 AnCodeEditor/AnVersionDiff 同档零跳变;AnLiveCodeWindow/_editSeg/ToolWindow 已物理删除;langOf 归 core。

**当家件**(拍板修订:live 全量+高亮+行号):
```dart
AnCodeEditor(code, lang, reading: true,
  live: false,        // live=流式脸:全量内容+高亮+行号,装有界贴底视口(AnStickViewport 钉底跟最新行)
)
AnVersionDiff(before, after,
  live: false,        // 两幕手术脸——−old 段/+new 段随流生长(吃掉 _editSeg),同 diff 壳同 bar
)
```
**规则**:①代码内容(含流式期)永远住编辑器壳,**live→settled 零跳变**(同壳同高亮同行号;唯一区别=live 视口钉底跟随)。②**diff bar 与编辑器 bar 同构**:左 copy+wrap,右 **+N −N**(diff 不显语言标)。③`AnLiveCodeWindow`(侧幕)并入 live 形态后删除。④扩展名→语言映射归 core(删 feature 层两张私表)。⑤高亮流式性能=逐行记忆化(只重算正在生长的最后一行,C 轨落实)。

## 族三 · 芯片 —— `AnChip` 收拢五件+全部手搓

**现状(批5b 后)**:AnChip 当家件在位,AnBadge/AnCopyChip 已物理删除、AnRefPill(+inline 行内脸,骑 AnInlineCapsule)/AnPathChip/AnScopeBadge 为薄预设;手搓 chip(belt/morph/opTicker/lockChip/currentMarker)与文内伪药丸四处({{CEL}}/[[id]]/cel/编辑器提及)全清,截断三元式 23 处进 AnTrunc 档。剩:WindowCopyButton 缓议(A-045 窗头裸字形 vs 芯片壳待帧裁)、settings 键帽/色板(A-027/028 批5c 专批)、AnAttachmentChip 几何(A-031 尾项)。

**当家件**:
```dart
AnChip(label, {
  AnTone tone = AnTone.none,
  AnChipLook look = AnChipLook.filled,  // filled(软底,今 AnBadge) | outlined(细边,今 belt/morph)
  IconData? icon,
  bool mono = false,          // id/路径等等宽标签
  String? copyValue,          // 点击复制+✓一闪(吸收 AnCopyChip/WindowCopyButton 语义)
  VoidCallback? onTap,        // 导航(AnRefPill=kind glyph 预设)
  bool strikethrough = false, // morph 删除态
})
```
AnRefPill/AnPathChip 降级为 AnChip 的薄预设(保留名字,内部全走 AnChip)。色点统一 `AnStatusDot`(补直喂 color 形态)。**截断**:共享 `truncate(text, AnTrunc.id|word|line)` 三档 helper,删 15+ 处三元式。

(拍板 ✓:双形都留——描边形用于轻列表芯片,填充形用于状态徽,语义有别。)

## 族四 · 行(键值/标签-值/台账行)—— 台账最大族(34 条)

**现状(批6 收敛后)**:排布选型查表定分工——身份行/头=AnTwoZone、键值列表=AnKv(`an_kv.dart`,含 `AnKvRow.flag` 唯一 bool 渲法)、标签在上=AnFieldSection(工具卡值形二分:全短标量 map→AnKv dense)、表单字段=AnFormField(含 monoLabel)、台账/命中行=AnLedgerRow(+AnLedgerList 唯一「展开全部 N」)、判别梯=AnLadder;四套手搓台账行/双 escape/三套 intent 行已物理消亡(_RunRow/_nodeRow/_WebHits/_ToolHitCard→当家件,toolIntent 单源)。AnLeadValue=core 内部几何引擎,feature 禁直用。

**当家件**(行族三件 + 既有 AnDisclosure):
```dart
AnKv(rows)                    // 唯一键值对排布(已有,吃掉一切逐键私排)
AnFieldSection(label, child)  // 「13 灰标签在上 + 内容在下」的唯一实现(吃 ToolIOSection 骨架/intent 行/_section)
AnLedgerRow({lead, primary, chips, meta, onTap, expandChild, expanded})  // 唯一台账/命中行(吃四套;状态点一律居左;列表壳 escape deferred→P4)
```
**规则**:①键值=AnKv,标签-值=AnFieldSection,**禁第三种排布**。②台账行 lead(状态点/glyph)一律左侧。③**两端对齐铁线**:右侧 meta 右缘齐成一条垂直线(拍板 #4)。④「展开全部 N」escape 并入 AnLedgerRow 列表壳。⑤' · ' 元数据链禁手拼(归条族)。

(拍板 ✓:主行本战役**不动**,记契约 §7 豁免。)

## 族五 · 条(结果/状态条)—— `AnStatBar`

**现状(批3 后)**:一条 AnStatBar(leading/stats/chips/notes 槽)——RunStatBar/ExecResultBar/_InvokeStatBar/_RunFooter 已物理删除;' · ' 链只此一源(文法 #3);runStatBarOf 适配器 18 用点(+批5 extraStats 域外挂缝)。

**当家件**:
```dart
AnStatBar({
  AnStatus? status,          // 状态词徽(色随 AnStatus,删平行映射);statusLabel 域词覆盖
  List<AnStat> stats,        // ' · ' 链(text|tabular 数字),内建分隔
  List<Widget> chips,        // 尾随凭据(AnChip 预设:ref pill/copy)
  List<AnStatNote> notes,    // 下挂注记(可多条:envError 红 mono/restartNote 琥珀 label)
})
```
**规则**:①四条全并入,物理删除。②status→词→色只此一源(AnStatus)。③' · ' 链全 App 唯一实现在此。

## 族六 · 活尾 —— `AnLiveTail` 三形态

**现状(批1 后)**:AnLiveTail 三脸(term/mono/prose)+bare+O(tail) 内建——ToolLiveTail/AnTermTail 已物理删除;有界回滚=AnTermViewport/AnStickViewport。

**当家件**:
```dart
AnLiveTail(text, {
  AnLiveTailStyle style,   // term(ANSI+折叠,今 AnTermTail) | mono(纯等宽,吃 v1) | prose(阅读排版+底对齐 clamp)
  int tailLines = 6,       // term/mono;prose 走 maxHeight 档
})
```
**规则**:活尾只此一件;v1 删除;prose clamp 高度进 AnSize 档;**随窗族一脸白框**(灰底退役)。(代码流式尾**不在此族**——归代码族 live 形态,壳必须是编辑器壳。)

---

## 版式文法(十条;B 轨 75 条台账的立法面)

1. **对齐**:身份行(名 vs 元数据)=两端撑开(AnRow 形);内容流内部=左聚;回执/读秒尾=跟随动词后左聚,**不右浮**;唯一右浮=窗 header 的 actions 槽。
2. **键值/标签**:AnKv / AnFieldSection 二选一,禁第三种。
3. **meta 链**:' · ' 链只在 AnStatBar,禁手拼 InlineSpan。
4. **缩进**:体缩进/嵌套缩进用语义 token(P3 新增 `AnIndent.*`),禁 `AnSize.icon + AnSpace.s6` 式算术(台账 B 系 30 条间距的主刑)。
5. **截断**:文本截断走 `truncate` 三档;内容封顶走 `AnCap.*` 档(6000 散置 ×4 收编)+ 窗内建截断注记。
6. **色调语义**:ok=成功终态;warn=半成功/预期外非失败/权限让渡;danger=失败/破坏/危险确认;accent=进行中/选中/焦点;灰阶=元数据。透明度只用 AnOpacity 档,禁 `withValues(alpha:)` 私调;**feature 层禁私铸 hex 色**(settings 色盘迁 core)。
7. **状态渲染**:loading=AnSkeleton、empty/error=AnState,禁手搓(台账「状态」14 条)。
8. **动效**:时长只用 AnMotion 档;reduced-motion 统一惯用式(原语内建,feature 层不再各写各的 `reduced ? Duration.zero :`)。
9. **图标/尺寸档**:禁 token 算术;P3 按台账实际用值铸新档(如 iconXs/dotSm/视口高 termViewport·proseClamp·graphPreview),档位封闭。
10. **魔数清零**:一切裸尺寸(280/200/320/144/220/120/64…)进 token 或删;棘轮 guard 类别随 P3 扩到可静态判定的全部十条。
11. **窗禁套窗**(拍板增补):窗是叶子容器;窗与窗之间靠间距,不嵌套;代码/diff 自带壳不再套窗。
12. **灰底退役**(拍板增补):内容容器只有白框一种材质;用户消息泡是唯一灰底(气泡语义);交互态灰(hover/输入/选中)不属内容容器、不受此条约束。

(拍板 ✓:文法冻结,含增补 #11 窗禁套窗、#12 灰底退役。)

---

## 拍板结果(2026-07-11)

| # | 项 | 结果 |
|---|---|---|
| 1 | 窗族 | **改**:一脸白框(灰底材质全废,用户泡例外);窗禁套窗 |
| 2 | 代码 live | **改**:全量+高亮+行号,有界贴底视口 |
| 3 | 芯片 filled+outlined 双形 | ✓ |
| 4 | 工具卡主行本战役不动 | ✓(记契约 §7 豁免) |
| 5 | 条族四并一 | ✓ |
| 6 | 活尾三形态一件(随窗变白) | ✓ |
| 7 | 文法十条 + 增补(窗禁套窗/台账右缘铁线;diff bar 同构) | ✓ |
