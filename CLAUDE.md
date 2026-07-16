# Anselm — Claude 工作守则

> Claude Code 进入本项目自动加载本文件。**本文件是项目工程纪律的唯一事实源**。
> 项目愿景 / 架构 / 实体地图 / 引擎见 [`docs/concepts/architecture.md`](docs/concepts/architecture.md)；文档规范见 [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md)。
> 旧版（覆盖回 `backend/` 之前的快照）在 `version-0.2` git 分支——参考旧版 checkout 它即可，不在当前文档维护任何历史。
>
> **交流语言**：本项目的所有对话回复一律用**中文**（代码、标识符、commit message 等技术产物的语言约定不受此限）。

---

## 项目一句话

- **本地优先 Agentic Workflow Platform**，目标 **Flutter 桌面 app**（macOS/Linux/Windows，Go 后端作 sidecar）、**单进程单用户**、SQLite 落盘（**不做 SaaS**）。
- **核心心智**：**Quadrinity（四项全能）** 实体（Function/Handler/Agent/Workflow）+ **Durable Execution**（节点结果记忆化 + 解释器幂等重走）。
- **架构**：4 层 Clean Architecture，依赖单向 `transport → app → (domain ∪ infra/store) → infra/db`。地基自研：`pkg/orm`（去 GORM）+ `glebarez/go-sqlite`（纯 Go、无 CGO）。
- **当前状态**（快照——本条只留当前物理事实,逐 STEP 过程 / workflow ID / 历史 bug 修复从 git + working 文档取,见 #7）：
  - **后端 `backend/`**：全 Quadrinity 实体 + durable 引擎，编译/装配/启动/服务全通；loopback 加固（默认绑 `127.0.0.1` + `RequireBearerToken`[`ANSELM_AUTH_TOKEN`，空=关] + `RequireLoopbackHost` 防 DNS rebinding）；**touchpoint 对话触点台账**（右岛地基：对话碰过的一切按 (对话,物,动词) 聚合落盘，chat Send + loop 工具咽喉双水龙头 + 目录穷尽性门禁 + messages 流信号，见 `domains/touchpoint.md`）。契约成体系，见 `references/backend/`。
  - **前端 `frontend-rebuild`（当前活跃线）**：新设计系统 + **UI kit G0–G6**（原语 + gallery）+ **三岛 shell**（`AnShell`：可拖收左岛 / 敞开海洋 / 按需揭示 + 可拖宽右岛（280–640 持久化，海洋保底钳制）/ 浮层头面包屑 / 红绿灯对齐，Riverpod-free、状态由 app props 喂入）+ 窗口·缩放·i18n·浮层 + **Phase 4.0 运行时骨干**（`core/{contract,net,sse,process,perf,error}` + `runtime.dart` Riverpod 装配 + `app_startup_gate` 门控 + L0–L2 流式合并；loopback 安全在后端）。
  - **Phase 4.1 Entities 已落**：契约层 → 数据缝（`EntityRepository` Live/Fixture，`entityRepositoryProvider` override）→ 列表 state → rail → 详情海洋（单 `AnPage` 文档：头 + tab + 720 阅读列同滚）→ **执行 + 右岛 run 终端**（强链选区、autoDispose、`BlockTreeReducer` 渲 agent 树）；**go_router 路由化**（常量 key 壳永不重挂、选区单向派生自 URL）。
  - **Phase 4.2 Chat 纯聊天骨干已落**（V0–V2+V7半 模块 + 组装切片①–⑧，真后端免费模型端到端亲测）：rail（信号点 / 改名 / 置顶 / 归档 / 删除 / 搜索 / 排序 / 无限翻 / 空标题回落）+ 中心海洋（landing 首发懒建 → transcript **CustomScrollView+center 锚**［prepend 零位移；超屏贴 max / 未满屏钉 min 让浮层头］+ 三层合并模型［settled/live/pending FIFO 回声］+ composer send↔stop + 浮层头改名·模型菜单·自动命名活着双落 + 诚实终态横幅）+ demo 脚本流式。**基础聊天完整体已打磨**（landing 静态问候［业界定稿］+ 两态模型选择器［粘性+首发盖章］+ 自动命名假流式［head/rail 打字机同播］+ **@ 提及 picker**［combobox 标准+伪药丸+core MentionSource DIP］+ **附件三入口**［📎/粘贴/拖放 → chip → attachmentIds + 泡内元数据解析］）。**tool 卡完美态蓝图（WRK-056，113 工具逐个设计 + 50 新原语 + B1–B7 建造顺序）已拍板，V3a 底盘 + V3b shell·fs + V3c builds + B1 人闸 + B2 builds 旗舰 已落**（`ChatToolCard` 全生命周期纯 prop 裸行、**默认永远收起**[WRK-065 用户定调:运行中绝不自动弹窗——族体 `toolLive` 两张脸,点开在飞=流式舞台(活终端/生长秀/两幕手术/嵌套轨迹)、落定=档案,在飞扣住结果向段落不撒谎;仅失败(一次)与人闸自动展开] + **机器窗口身份**[`ToolWindow` 终端/diff/命中窗 + 活终端尾 + **活代码窗**(内容随 args 流入) + 结果条 id·vN·env + 回执解析器] + 注册表缝 + transcript 接线；**B1 人闸**=F16 全族[`pendingInteractionsProvider` 三源合一 + `ToolInteractionGate` 白岛门 danger/ask + ask_user 三段动词 + decide_approval 判词章 + list_approval_inbox 薄表]；**B2 builds 旗舰**=F4 全族深化[`partialJsonEvents` 流中 JSON 引擎 + `RunStatBar` 结果条唯一实现 + fn/hd 活代码窗·`EnvFixTimeline`·edit_handler 三径 + ★**`AnMiniGraph` + create_workflow 两幕生长 / edit_workflow 图 morph**(pivot 旗舰:纯可视化看见变化) + control 决策梯 + approval 表单预览 + document/skill `ProseWindow` + `TriggerConfigCard` 四 kind 脸]，规范 WRK-053 [`tool-cards.md`](docs/working/frontend/tool-cards.md) + 蓝图 [`tool-card-blueprints.md`](docs/working/frontend/tool-card-blueprints.md)）；**B3 目录感普查全落**（F05/F06/F07/F17 共 50 工具,transcript 读成目录:`panelLocationFor` 面板注册表[#8]+`ToolHitList`[#10 四族共享命中门]+`EntityGetBody` 四段陈列[#31]+`ToolDependentsBlock` 删除审计[#15]+`AnKvRow` 行级 mono[#9]+`resultFailed` 绿壳红事实缝;get×8/read×2/search×11/lifecycle×26/conversation×3 逐工具投影）；**B4 终端与文件手术全落**（F03 shell:termFold+ansiSpans 终端折叠+`AnTermTail`/`AnTermViewport` 有界回滚+Bash footer→底条+BashOutput 轮询诚实+KillShell;F01 fs-ops:fsError 九类+四象限 readReceipt+`AnPathChip`+Write 活窗生长秀+Edit 两幕手术+mount 三式名路由;F02 fs-search:`AnCountUp`+LS/Glob 目录感命中窗+Grep `GrepContentView` 编辑器式全局搜索面板）；**B5 执行与档案 / B6 嵌套对话 / B7 生态收尾全落**（B5=`FlowrunNodeList` 节点台账·`RunBeadStrip`/`RunLedger` 检索族·`RunDossier`+`ProvenanceLine` 卷宗·`ToolIOSection`·`transcript_hydration`+`TranscriptPeek` 存储树重放；B6=`NestedRunPane` 嵌套运行活窗+`transcriptBlockRow` 共享块行·Subagent/get_subagent_trace 卡；B7=`TodoChecklist`+`tool_card_ecosystem`［relations/capability/mcp-mgmt/model 9 卡收官，catalog 全覆盖无 generic 剩余］，规范同步 [`tool-cards.md`](docs/working/frontend/tool-cards.md) §6 B1–B7 ✅）；**蓝图更高野心版待建**（B6 `SubTranscriptFrame` 第三身份+`SubagentDigestTail`+reload 重水合缝 / B7 `sniffShape`·`ShapedView` generic 地板 / F08 `FlowrunSnapshotPane`＝后端版本图端点阻塞），见 [`tool-card-blueprints.md`](docs/working/frontend/tool-card-blueprints.md)；**WRK-059 审计台账全清 ✅**（2026-07-08，34-agent 审计 17 confirmed + 7 注释/polish 全修：**H2 六工具编目**[memory 三件 `MemoryNoteCard` 索引卡 / `WebSearch`·`WebFetch` **结局分类器 soft-fail 诚实**(status=completed 的失败句渲红不渲绿) / `search_tools` 薄卡 + `openExternalUrl` 外链 scheme 白名单闸] + M1–M9[琥珀点优先/max_tokens 琥珀横幅/FIFO 跳失败泡/410 resync 落盘泡对账/失败附件提示/人在环重连重拉/compaction·活人闸·loadMore 重试] + L1–L6 + demo 种齐[活人闸真线缆形=tool_call 关帧无 result/泡内附件 chip/记忆与网页展台]，归档 [`WRK-059`](docs/archive/chat-review-backlog/README.md)）；**V8 右岛「侧幕」W0–W7 全落 ✅**（WRK-061：`PartialJsonSession` 增量 JSON 引擎[O(delta)+带路径通道] + `StageDirector` 六态导演器[500ms 登台防抖/换台仲裁/pinned 永不自动收/R-10 poll 型 202 永不谢幕] + touchpoint ledger[R-2 (kind,itemId) 聚合] + **12/13 kind 逐个量身活舞台**[fn 地层→活窗→真 diff / doc 前缀快进 / workflow 真画布图生长+判别式抽屉 / control 决策梯 / approval 信笺 / trigger R-16 只信 GET / subagent 单席+群像 / handler 方法架 / agent R-9 渐进开区 / skill 装订台 / memory 记忆笺 / mcp 接线现场] + Rundown 整表任务板；**W6 导航已落**（后端 `?around=` 窗 envelope/`?dir=newer`/anchors 六 kind 锚/durable `run_terminal`/tick 带 `port` + 前端 transcriptJump「re-anchor」深跳[回到现场 pill+洗亮+绝不夺视口]/场次条 drawer/Cast hover 双动作/exhibit mode 点行登台[含 attachment 展品座]/R-14 回合锚）；**W7 polish 已落**（跟随三档持久化+侧幕头菜单 / R-15 收起态 activityBit / **R-10 退役**[poll 舞台按 flowrunId 匹配 durable `run_terminal` 自动落定] / 谢幕落账洗亮 / a11y 四播报+流式区静音 / i18n 零硬编码审查 + 遗留全清[活运行卷 flowrun tick 覆层·AnTooltip·[[id]] 真名·内联终端·场次条 560·归队贴底真 bug 修]）；每批真机逐帧截图验收；当前形态见 [`features/chat-sidestage.md`](docs/references/frontend/features/chat-sidestage.md)，建造史归档 [`WRK-061`](docs/archive/chat-right-island/README.md)）。
  - **WRK-066「同轨」全 App 收敛战役 ✅ 全部完成并归档**（0711 开战 → 0714 收官；建造史 [`archive/convergence/`](docs/archive/convergence/README.md),法典 distilled laws + 六族当家件 + 25 收敛原语已提取进 [`design-system.md`](docs/references/frontend/design-system.md)）：四轨一伞（A 视觉六族收敛/B 规范科学化/C 性能/D demo 全展示）+ harness（棘轮基线只减不增 + 覆盖分母台账逐个过审 + 每批全新上下文对抗复审 + 真机帧）。P0–P2 ✅（法典 WRK-068 拍板：窗族一脸白框灰底退役/代码 live 全量高亮行号有界贴底/diff bar 同构/台账右缘铁线/窗禁套窗）；**P4 批1–4 ✅**：活尾族（删 ToolLiveTail/AnTermTail→`AnLiveTail` 三脸+bare+O(tail) 内建）、代码族（删 AnLiveCodeWindow/_editSeg→`AnCodeEditor.live`/`AnVersionDiff.live` 两脸一壳同档零跳变+langOf 归 core）、条族四并一（删 RunStatBar/ExecResultBar/_InvokeStatBar/_RunFooter→`AnStatBar` leading/stats/chips/notes 槽）、**窗族整体替换**（删 ToolWindow→`AnWindow` 一脸白框 19 文件 44 用点；ProseWindow/MemoryNoteCard 壳并入+折叠阈进 AnCap 档；双日志抽屉合 `LogDrawer`；`ToolIOSection.bare` 防台账展开套窗；AnSunkenPanel header 槽退役、唯一住户=用户泡）；新原语 `AnFocusRing`（不透明卡焦点环）。**批5（芯片族）5a+5b 已落**：AnBadge/AnCopyChip 物理删除（131+8 用点并入 `AnChip`，+tooltip/semanticLabel/空标签守卫/outlined 白岛底/强类型 `dot` 槽五增量）、AnRefPill（+`inline`）/AnPathChip/AnScopeBadge 降薄预设、`AnStatusDot.raw` 清六处手搓圆点、`AnFollowPill.jump` 吃两处回场药丸、新原语 `AnInlineCapsule`（唯一文内壳：{{CEL}} 囊/[[id]] 药丸/cel 引用/编辑器提及四处并入）、belt/morph/lock/current/provenance 五族删壳、opTicker dot 槽双脸零跳变+_DiffBadge 并入 `runStatBarOf.extraStats`、truncate 23 处进 AnTrunc 档；**批5c 已落**：新原语 `AnKeycap`（三态键帽，刻意不可聚焦——录制 Focus 不容抢焦，真机复验录制链全通）+ `AnSwatch`（dot/pick+选中环 ring 档，色表 kAvatarPalette+parseHexColor 迁 core）；A-031 尾项（AnAttachmentChip=复合控件非芯片）与 A-045（WindowCopyButton=窗 chrome）改判关账。芯片族 25 行台账全清。**批6（行族）✅ 全落+复审整改毕**：行族 34 行台账全清（32 done+A-056 defer[map 编辑器=表单机器,过早抽象]+A-069 豁免）——三当家件长全槽（AnLedgerRow sub[原语内 trim 归一,渲染几何同源]/measure/lead 定宽格/expandChild 随 lead 缩进、AnRow leadWidget[交互 lead 不剥语义]、AnKvRow.flag[族内距+a11y 本地化是/否]、AnFormField monoLabel[MCP env 组消费]、ToolHitRow onOpen）+ 新原语 `AnLedgerList`（唯一「展开全部 N」）/`AnLadder`（判别梯骨架,IntrinsicHeight 禁窗约束成文）/`AnKv` 拆独立文件+排布选型查表入法典；台账双件四并一（flowrun 状态点归左）、命中门收编（_WebHits/marketplace/_ToolHitCard,畸形 URL host 解析不出即不渲尾格防挤垮标题[尾格契约刚性成文]）、TodoChecklist 并入 AnRundownList、ControlBranchRow 共件、toolIntent 收编 17 用点、ToolIOSection 两刀（节头 13 回正+值形二分[全短标量 map→AnKv dense+flag]）、settings 五面板 ~24 字段块→AnFormField（标签升族脸,A-057 retry→AnField child/A-060 memory pin→leadWidget 真控件[AnInteractive+toggled]）；36-agent 复审 25 confirmed 全修（含批4 bare 钉重钉+假钉五清,7 突变体验杀）。真机九帧逐面板核毕（含 pin 金色态/hover Delete/A-064 quiet 双节头可见生效）。**批7（B 轨扫尾)✅ 全落+复审整改毕**：B 台账 75 行全清（72 行了结=61 fix+8 证伪+3 拍板记档,唯余 B-021 标题上距三方分裂交用户签字;B-045 随复审关账）——批7a 铸档 21 枚（AnIndent 悬挂缩进类/表单·控件·视口尺寸档/防抖三档+toast 双档等九时长档/sending·veil 透明档/dangerLine 七点管线/AnMenuSurface.estHeight 自报估高）+新原语三件（AnSpinner[orAssistive 门]/AnFadeRiseIn/AnDropVeil）；批7b 间距 24 行（AnIndent 换算术/Wrap 文法/settings 全面板走档/弹层入菜单轴/折叠阈实测化）；批7c 色调图标 11 行（**AnToastTone/NotificationTone/runStatusColor 三平行体系物理删除**,全走 AnTone·AnStatus 单源[fromRaw 补三别名,timeout 琥珀→红+claimed 灰→琥珀双色变帧核]/私 alpha 清/微尺寸减法八站点清/文本字形→AnIcons）；批7d 动效状态 25 行（裸 Duration 全入档/reduced 双闸落位/状态件归位十二站点[哨兵 '…' null 化主刑/AnRailStates 回正]/loadMore→retry/状态词映射并源/引号入 locale）；**B 轨立法四条**（时长档限视觉层+豁免/曲线档/reduced 双闸选档/错误·空态选型）+ **圆角选档立法**（五档=尺度阶梯成文,唯一出格 freeTier 卡→AnCard）。32-agent 复审 24 confirmed 全修（台账 done 诚实性四清/立法-物理对齐[曲线七站入档+豁免锚七处]/AnSpinner 语义缝/claimed 点章同源/nameQuoted 补全/状态面双补/Wrap 文法 14 残站）。棘轮 10 条目/12 处。**批8（全量扫尾)✅**：321 pending 逐文件过审清零（27-agent 扇出+2 件亲审：264 converged/47 reviewed 边角记档/8 violation 全修[含 an_layer_diff 灰底退役帧核/syntax w600→w400 铁律/sidebar 假转圈→AnSpinner]），ledgered 55→reviewed；分母现状 294 converged/121 reviewed/45 ledgered（=A/C/D open 行引用件）/0 pending。**批9（A 轨扫尾）✅**：视觉六族收敛实质完成（清 27 A 行=21 done+追认/证伪/豁免/defer/判断题，core i18n 命名空间迁移 chat.stage.*→feedback.cast.*、AnButton toggle 态、ApprovalGate 共件、raw-mono 窗 helper、caret 弹层几何抽 `AnMenuSurface.caretPlacement` 纯静态）；A-113 **done·批A**（抽 `AnDocHeader` 阅读尺度文档头原语进 core/ui+gallery，与海洋头 chrome 尺度对位不合并，6 测锁契约）。**批D1–D7（D 轨 demo 全展示）✅ 全收官**：35 GAP 全落定=30 done + 5 exempt（0 open）——settings 三面板/实体五 GAP（自洽互锁世界）/chat 侧幕六 kind+墓碑/失败与终态六态/failedHold 失败 subagent/分页（20 历史越 rail·54 触点越台账）+文档全块型样章+活 toast+demo 挂快捷键/失败注入簇 H 逐条裁（cv_ask 活问闸·cv_flaky scoped override·DemoEntityRepository 坏实体=seed；D-001/003/004/017/030 硬技术豁免）；战术=**数据级电池取代真机帧**（fixture 纯数据非渲染，`*/demo_fixture_test.dart` 锁种子正确性）。fe-verify **3619+ 绿**。**P5 性能（C 轨，测量先行）✅ 全 43 条落定**：主面场景 build-side 预算套件常驻 fe-verify（7 场景 1:1）；C-025/016/030 实现+测量、C-001 证伪并顺手修真数据丢失 bug（Debouncer flush-on-dispose），余 exempt/证伪按反校验剧场 #6 测量裁定。**P6 二轮全新普查（18-agent 对抗，对空账）✅**：清确认缺陷——an_segmented/an_switch 暗色阴影→主题 `shadowIsland` 档（私 alpha 清、dark 不隐形）、删 3 死码（an_mini_graph 被 AnGraphCanvas 吸收 / an_toolbar 从未采纳 / sse_parser 死 getter；`nodeKindColor`/`nodeKindIcon` 迁 an_graph_canvas 单源）、design-system §1 补 `AnCap`+caret 勘正、**§5 整体重述**（删 2 死件 + 补 25 code-grounded 原语=完整投影）、§7 豁免登记诚实化。**landed-into ✅**（法典 WRK-068 distilled laws 全在 design-system.md）。fe-verify **3683 绿** + make docs 净。**用户 0714 定夺**:§7 豁免 21 条全批签字 ✅ + `an_channel_strip` 裁定删除（弃 flight-deck channel-tab 概念,git 留档);working 文档(契约/台账 WRK-067/法典 WRK-068/P5 playbook)已归档 [`archive/convergence/`](docs/archive/convergence/README.md)。**唯一 post-completion 常驻项**=批7~D 可见变化用户否决窗(视觉 QA,非完成阻塞)。
  - **左岛骨架完全体**：`AnOceanSwitcher`（海洋切换器：matched-geometry 滑动药丸 + `selectedIndex=-1` 无选中态）+ `AnSidebarFooter`（底栏：`AnWorkspaceButton` 等宽快捷菜单 + 设置格 + 通知格红点）；左岛两条独立轴 `selectedOceanProvider`（顶部 4 海洋 + 齿轮进的 `settings`，首启落 chat、此后恢复上次海洋）/ `notificationsOpenProvider`（铃接管左岛中段、不动中心、点任一海洋即收）；`chat`/`entities`/`documents` 三海洋已建、`scheduler`「即将推出」占位。海洋切换暂走 provider（未路由化，后续并入 go_router）。
  - **Phase 4.4 Documents 已落**（当前形态 [`features/documents.md`](docs/references/frontend/features/documents.md)）：documents（Notion 式页面树）+ skills（frontmatter SKILL.md）两类 file-like 知识一海洋——树 rail 全 CRUD + 拖拽重排（`planDocMove` 纯函数守卫）→ **原生编辑器**（`core/editor/AnEditor`，super_editor 钉 dev.40 仅经门面用，**基座已 vendor**［`third_party/super_editor/`，ADR 0009：上游 presenter 每键全文档重建=O(文档)/键，补丁布局管线三文件做**节点级增量**（事件归账+脏半径四依赖边+基底缓存+五相子集喂入；fail-safe 全量兜底）；护栏=测试全局 debugVerify 自校验+差分 rig+O(变更) 守卫（200 段打键 rebuild≤8/光标移动 0）］：**同滚页**［头 sliver+编辑器 sliver，大标题真滚走、浮层头折叠诚实］+ slash 11 命令［slang、分隔线/表格空段替换/非空下插］+ @ 药丸［MentionSource DIP］+ 划选条五键［含 **link** URL 输入：回车上链/外点取消/已带链去链］+ **markdown 即打即转**［`InlineMarkdownReaction`(占位符守卫包官方 `MarkdownInlineUpstreamSyntaxReaction`,dev.40 parser 遇内联占位会崩故守):inline `**粗**`/`*斜*`/`~删~`/`` `码` ``/`[名](url)`;block `#`–`######`/`-`·`*`·`+`/`1.`/`>`/`---`(默认 reactions)+ **`[]`→待办 / ```` ``` ````→代码块**(`an_editor_markdown_shortcuts.dart`,照 Notion 简化触发避冲突)+ **退格回退**(标题/引用行首·空待办退格→段落)］+ **代码块=嵌入的真 `AnCodeEditor`**［`CodeBlockNode`(super_editor `BlockNode` 原子块)包 seamless `AnCodeEditor`，与 entities/function 页逐像素同款：框+**行号 gutter**+copy+语言标+高亮，且就地可编辑(点→光标→打字、无铅笔)；`onInput` 逐键 `ReplaceNodeRequest` 整节点替换(每节点一把 `GlobalKey` 保 field State)］+ **行内代码=paint-beneath,与 chat `AnCodeChip` 逐像素 1:1**［`codeAttribution` **文本**下画圆角灰底(`an_editor_text_component.dart` 的 `AnTextComponent`/`_CodeBackgroundPainter`,vendor 自 super_editor)——实测对齐芯片:字形上下内距 4.00/3.67px、高 19.7、水平 4px 全吻合。**三招**:①内容区取 box 去两侧 NBSP 内距、4px 靠膨胀补;②**逐视觉行并 box**(`getBoxesForSelection` 在 script 边界断开返回多 box,CJK 代码注释旧版画成断裂药丸→同行并一,连续);③定高(mono 行盒 20px=芯片高)贴行底 + 1px `kInlineCodeBottomNudge` 校正(用 24px prose 行盒会头重);换行处逐行各补 4px。**水平内距靠真 NBSP 预留版位**(`an_editor_inline_code.dart` 的 `codeSpacerAttribution`+`padCodeRuns`+`CodePadReconcileReaction` 保两侧各一 NBSP·**满字号+负 letterSpacing 把步进缩到 ~4px**[不缩字号——缩字号会让光标落到码边占位符上变矮,用户实测「码边光标突变矮」根因]·幂等补回=删不掉,codec 载入注入/存出剥离),让 painter 的 4px 膨胀在紧贴邻居处正好齐平而非盖住(用户 0714 实机否决「直接画膨胀」——会盖 `d\`c\`` 的 `d`);行内代码**始终可换行可原地编辑、点击无跳变**。弃直接用芯片:`WidgetSpan` 芯片不能换行、点击要回切有跳变;paint-beneath 让换行/圆角/内距/无跳变+1:1 五者兼得］+ **可编辑表格**（0716 大修：上游 TableBlockNode 刻意只读[dev.52 未变]→按代码块先例自建 `an_editor_table.dart`——每格 SuperTextField 编辑 AttributedText 保真、纯网格函数+同 id 整节点替换、Tab/Enter/↑↓←→ 全格间导航[末格 Tab 加行/边缘退出/文档侧 Enter·↓·↑ 进表]、右键 AnMenuSurface 菜单增删行列删表[表头行保护]、列均分+格内换行弃 FittedBox 缩字）+ **codec 三保真+task 自愈**［`[[id]]` 逐字=后端 link 边契约 + 围栏语言标载盖存回 + `CodeBlockNode ⇄ code 段落`缝(行内代码=内置 parser 的 `codeAttribution` run 原样往返、不需缝,codec 仅载入注入/存出剥离 NBSP 内距 + 守卫码内 `[[id]]`-样文本不成药丸)］+ 大纲下标不变式［编辑器 h1–h6 六档全算对齐 `extractDocOutline`，有测锁死］+ **编辑体验 0716 大修**［**光标=内容尺寸**(An caret 层换上游默认:字符 tight 字形盒随块档走、ink 色,正文~15/H1~22,上游整行盒四档全挤 22.5–28.6 读作恒定巨大) · **选区一条色带**(逐视觉行并盒满行盒零缝零叠+跨块缝隙填充层+`AnColors.selection` token;码块/表格整块 tint 不开洞) · **引用可点**(wrapInQuote 壳补 IgnorePointer——裸 BoxDecoration 吞命中,点引用永不落光标而键盘能进的根因) · **task 退化级联根治**(空 task 尾空格被 trimRight 剪掉→重载退化 bullet+字面 `[ ]`→再存被上一 task 吞并勾框错位;存出豁免+载入自愈旧档双保险) · **卡死防护**(AnBlockTapGuard:原子块双/三击在上游 word-drag 毒态形成前拦下整块选中) · **序列化按闲**(逐键整篇 markdown 序列化改走 autosave 防抖+dispose flush)］）→ 右岛大纲/属性/backlinks → SSE 树自刷新（notifications 流 document.* 去抖 refetch）→ 路由化 `/documents/:id`。**编辑器史**：super_editor 首版 → Milkdown-in-webview（已废弃，死码删尽，归档 [`WRK-060`](docs/archive/doc-editor-webview/README.md)）→ 原生 super_editor（现行）。**后置**：图片（需后端图床）/数学（KaTeX）/`:iterate` 前端入口（待拍板）/IME 手动终验（用户）。
  - **Notifications 通知模块已落**（WRK-058，N0–N5 全落，见 [`features/notifications`](docs/references/frontend/features/notifications.md)）：**后端分径**（`notificationapp.Emitter` 拆 **Emit**［落收件箱行+推 durable 帧］/ **Broadcast**［只推帧不落行］——18 个高频对账回声 conversation.*/document 树刷新/memory pin/… 转仅帧，不落收件箱；实体生命周期 payload 补 `name` 可扫读；见 [`events.md`](docs/references/backend/events.md) ⊞/⤳）+ **左岛铃两段式托盘**（`FlowrunInbox` sectioned「待你处理」+ `NotificationFeed`「通知」时间流，点行深链顺手已读、已读灰留列表）+ **右上悬浮 toast**（`AnOverlayHost` 迁右上·cap 3·hover 暂停 WCAG；`ToastDispatcher` 事件→toast、只 important 弹·neutral 静默·tone 定时长·去抖防风暴·coalesce 只在 dispatcher）+ **OS 原生通知**（`OsNotifier` DIP：Noop 默认 / `LocalOsNotifier`=flutter_local_notifications；`appFocusedProvider` 焦点路由：聚焦→toast/未聚焦→OS 通知）。**关键裁决**：N0 后流上 Emit/Broadcast 帧形一致且 `memory.updated`(pin vs 内容)不可分 → 未读徽标**绝不据帧 +1**、靠权威 `unread-count` refetch。真壳 E2E + macOS build 验证。
  - **Settings 设置模块已落**（WRK-062，S0–S6 全落 + 后端工单①–⑩，见 [`features/settings`](docs/references/frontend/features/settings.md)）：齿轮进的设置海洋 = **双骨架 IA**（偏好/资源/系统三段 · **13 面板**：通用/通知/对话/模型与密钥/MCP/记忆/沙箱/工作区/存储/限额/网络/快捷键/关于）+ **机器域与工作区域两条持久化轴**（`AnScopeBadge` 三域徽；机器级偏好存本地 `SettingsPrefs` 中央键表、工作区级配置存后端 `settings.json`+DB）+ 三相等门禁（面板↔目录↔声明键 `ownedKeys` 恒等）+ 推入第三级详情（面包屑第三段+Esc）。**平台地基**（settings 触发、归 core）：热切换（脉搏在 `dioProvider` 层每切换新 Dio+onDispose，全 repo→全 server-state 级联重取）· master key 铸钥（[`ADR 0008`](docs/decisions/0008-master-key-keychain.md)：全新安装铸 256-bit 入 OS keychain+读回验证，旧装机走机器指纹旧径绝不变砖）· 出厂重置（前端编排：停 sidecar→删数据目录→resetAll→重启）· 更新检查（裸 Dio 查 GitHub Releases、绝不带 loopback 凭据出网、semver 比较）· **可改绑全局快捷键**（`core/shortcuts/` 目录三件 6 命令；`GlobalShortcuts` 从 `shortcutBindingsProvider` 生成 CallbackShortcuts、挂 app 根 autofocus **之上**使冷启动即生效；面板逐命令改绑热生效）。危险动作皆 `AnTypeToConfirm` 双闸。逐片真机 E2E（release+真 sidecar 逐面板截图核对）累计修出 hover 不可达/dio 层 disposed-Ref/Memory PUT 缺 source/快捷键录后吞键/快捷键冷启动焦点序等多处真 bug。
  - **关键约定**：app 与 demo 共用唯一 `app/app_shell.dart`，只差数据源 + 启动门控（`make app` 真后端 / `make demo` fixture 零后端）；冷启动 `core/workspace/workspace_bootstrap` 定 workspace；**字体两档**（正文 w300 / 加粗 w400，见「视觉灵魂」节）；组件 **gallery-first**（先进 gallery 再被 app/demo 组装、不手搓）。
  - **门禁**：`make verify`（后端）+ `make fe-verify`（前端）+ `make docs`（文档）各自全绿；前端当前 **3312 测绿**。
  - **文档**：前端**一站式 hub [`working/frontend/`](docs/working/frontend/README.md)**（协作 / 进展 / 路线 / 档案索引,先看它）；鸟瞰 [`overview.md`](docs/references/frontend/overview.md) · [`architecture.md`](docs/references/frontend/architecture.md)（文件图 + 路由 + 装配）· [`design-system.md`](docs/references/frontend/design-system.md)（G0–G6）· [`contract.md`](docs/references/frontend/contract.md)（DTO）· [`features/`](docs/references/frontend/features/)（各 feature 当前形态）；在建 [`chat.md`](docs/working/frontend/chat.md)；归档建造日志见 hub §4（含 [`WRK-046`](docs/archive/entities/README.md) Entities · [`WRK-045`](docs/archive/phase-4.0-runtime-backbone/README.md) 运行时骨干 · G2–G6 套件）；平台 backlog [`WRK-042`](docs/working/platform-foundation/README.md) · 发行 [`WRK-043`](docs/working/platform-foundation/release-distribution-playbook.md)。

## 文档地图

> 入口 = [`docs/INDEX.md`](docs/INDEX.md)（AI 会话先读它再循链接）。后端全域 reference 已成体系——overview 鸟瞰 + `api/database/error-codes/events` 四索引 + `domains/` 分域 + `foundation/` 地基，与代码逐字同步；前端 reference 随 features 落地填充。

| 用途 | 路径 |
|---|---|
| 文档入口（索引 + 结构） | `docs/INDEX.md` |
| 愿景 / 架构 / 实体 / 引擎 / 路线 | `docs/concepts/architecture.md` |
| 文档规范（类型 / 同步 / 执行） | `docs/GOVERNANCE.md` |
| 后端鸟瞰（第 0 篇） | `docs/references/backend/overview.md` |
| 契约四索引（端点 / 表 / 错误码 / 事件） | `docs/references/backend/{api,database,error-codes,events}.md` |
| 分域 / 地基详解 | `docs/references/backend/domains/` · `foundation/` |
| 架构决策（ADR） | `docs/decisions/` |

---

# 设计原则（9 条，#9 最高优先级）

1. **Quadrinity 实体化**：任何能力必须归属于 Function / Handler / Agent / Workflow 之一。
2. **Durable 为魂**：工作流执行基于**节点结果记忆化**（`flowrun_nodes` 行表 + record-once）+ **解释器幂等重走**实现崩溃恢复与确定性重放——**非**事件日志（Temporal 式 journal 已否决）。
3. **依赖自下而上**：`domain` 层**严禁 import 任何外部包**（含 ORM / cel-go）；`app` 层协调 domain 与 infra；跨实体协作走 DIP 端口、不硬依赖具体实现。
4. **后端契约是事实源**：`reference` 文档 = 代码的精确投影；前端按 [`ADR 0004`](docs/decisions/0004-frontend-flutter-architecture.md)（Flutter 3-tier feature-first）对接已定型的后端契约（运行时管道状态见「当前状态」节）。
5. **端到端推演先行**：开工前必走完整数据流 + 列出跨域依赖（relation 边）。
6. **反校验剧场**：只保留有物理价值的校验（JSON、必填、CHECK/UNIQUE）；不加多余 null-check。
7. **零历史包袱 + 状态即重述**：项目未上线，禁止维护兼容性、禁止历史演化描述，只留当前物理事实（历史从 git 取）。**状态文档**（本文件 / `architecture.md` / `GOVERNANCE.md`）改任何状态/事实 = **整体重述当前状态、非追加**——绝不在旧内容旁堆新句、不留旧状态痕迹（见末「文档纪律」节 + GOVERNANCE §1.7）。
8. **复用优先、不造轮子 + 最佳实践优先（遇问题先查、不手搓）**：动工前先盘点 `pkg/*` 与 `infra/*` 既有能力——能复用就复用。**遇到任何不确定的问题（工程 OR 视觉），第一反应是联网查成熟方案 / 官方文档 / 标准库 / 既有最佳实践，绝不一上来自己手搓**——本项目在红绿灯重定位、窗口 chrome 等问题上反复手搓、反复跌跟头，教训惨痛：手搓的"看似能跑"往往埋着边界 bug，成熟方案已替你踩过坑。有成熟包/标准 API 就用它（如 macOS 窗口用 `macos_window_utils`），而非抄它的实现。业务层手搓的样板本应由地基提供时 **强化地基**、非模块内重抄。错误抽象与重复样板比多写一行更糟。
9. **📌 文档与代码物理同步（最高优先级）**：每个代码改动必须在**同一提交**伴随对应文档的 1:1 更新——**文档落后于代码 = 严重 Bug，与编译失败同级**。完整执行规则见本文件末「**文档纪律（强制）**」节 + [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md)。

---

# Standards — 契约宪法

## HTTP API（N 系列）

- **N1 统一 Envelope**：成功 `{"data": ...}`；失败 `{"error": {"code", "message", "details"}}`。
- **N2 状态码**：202 Accepted（异步流）/ 204 No Content / 410 Gone（SSE 淘汰）。
- **N3 命名规约**：API 线缆 camelCase；数据库物理列 snake_case。
- **N4 分页**：**无界集合** List 接口必须支持 `?cursor=...&limit=...`（api-keys/function/handler/agent/workflow/flowrun/trigger/control/approval/mcp/conversation/relation/notification/search/touchpoint 及各版本·执行·调用日志）。**有界可枚举资源**（单用户少量或系统级固定集：workspaces / skills / memories / documents 树 / sandbox runtimes·envs / todos / model-capabilities）豁免——返全集不分页、无 `nextCursor`，分页参数按标准 HTTP 忽略而非报错。
- **N5 动作后缀**：非 CRUD 逻辑用 `:action`。
    - **`:run`**(fn) / **`:call`**(hd) / **`:invoke`**(ag) / **`:trigger`**(wf) 为标准执行动词。
    - **`:iterate`**（AI 编辑实体）/ **`:triage`**（AI 诊断执行）统一返回 `conversationId` 开启对话。

## 数据库（D 系列）

- **D1 软删除**：业务表用 `deleted_at DATETIME`；**Log 表**（`flowrun_nodes` / trigger 的 firing·activation / messages 块 等内容/执行日志）**无 `deleted_at`、严禁逻辑删除**——唯一物理删例外：`:replay` 经 `DeleteFailedNodes` 清 `flowrun_nodes` 的 failed 行（failed 是非结果、清掉让幂等重走重跑，record-once 真相不损；与 `database.md` 对齐）。
- **D2 物理隔离**：所有表（除全局配置外）必须持 **`workspace_id`** 物理列；`pkg/orm` 据 ctx 自动双向隔离。
- **D3 唯一性铁律**：`idx_frn_once`（flowrun 记忆化 `UNIQUE(flowrun_id,node_id,iteration)`）与 `idx_trf_dedup`（trigger firing 去重）必须保证幂等。

## SSE 协议（E 系列）

- **E1 三条流限制**：全系统仅 `messages` / `entities` / `notifications` 三条 SSE，**永不再加**。前端启动即常驻全连；三流 **workspace 级、后端不过滤**（发完整 delta、前端自滤）；订阅统一在 `StreamHandler`（`GET /api/v1/{messages,entities,notifications}/stream`）。
- **E2 Ephemeral 帧**：delta / tick（如 flowrun 节点推进）标 `seq=0`，**不入 buffer、不产生背压**；open/close/signal 为 durable（close 带快照供 replay）。
- **E3 嵌套递归**：messages 流支持 `parentBlockId` 嵌套，前端据此渲染 subagent 树。

---

# 代码规范（S 系列）

- **S5 物理文件对齐**：handler 文件名对应 API 资源域；domain 文件名对应 Repository 接口。
- **S9 确定性上下文**：每个跨层调用强制传 `ctx`；异步 Finalize 必须用 **Detached Context**（保留 workspace 种子、脱离请求取消）。
- **S11 注释双语化**：`// English \n\n // 中文`。**只写 Why、不写 What**。
- **S13 导入别名**：所有 `internal/` 包导入带 `<name><role>` 别名（如 `apikeydomain`、`chatapp`、`workflowstore`）。
- **S15 ID 宪法**：`<prefix>_<16hex>`。前缀全集必须在 `references/backend/database.md` 登记（infra 侧 ID 用自己的前缀，不从消费实体 ID 派生）。
- **S18 Tool 规范**：Tool 实现 **5 方法接口**（`Name`/`Description`/`Parameters`/`ValidateInput`/`Execute`）；`summary` / `danger`（三级 safe/cautious/dangerous，LLM 逐次自报）/ `execution_group` 三字段由 Framework 强制注入 schema 并从 args 剥离。**无中央权限门控**：危险靠 LLM 自报 + 逐次内存阻塞确认（active skill 的 `allowed-tools` 预授权可免确认）。
- **S20 错误构造（全量统一）**：所有**命名 sentinel 错误**一律 `errorspkg.New(kind, code, msg)`（`pkg/errors`——错误类型是纯机制、放地基、全层可用，无反向依赖）；带 Kind（→HTTP status）+ 稳定 `<ENTITY>_<REASON>` wire code。**无"是否冒泡 HTTP"之分**——同一错误两种出口：HTTP 读 Kind/Code 走 Envelope，LLM tool 读 Message。**禁止**用标准库 `errors.New` 造命名 sentinel；`fmt.Errorf("…: %w", err)` 包裹照常（保留 `errorspkg.Error` 链供 `errors.Is/As`）。泛型原语（如 `orm.ErrNotFound`）带兜底码、由 domain 翻译成具体码。`errors.Is`/`errors.As` 用标准库。见 [`decisions/0002`](docs/decisions/0002-unified-error-type.md)。
- **S22 工作区卫生 + 事实同步**：仓库只留源码 + 必要配置——**散落二进制 / 构建产物 / OS·编辑器生成物一律不入库**（`go build` 出 `bin/`、日常用 `go run`；`.DS_Store`·`mise.local.toml`·`backend/<cmd>` 散件 gitignore，stale 产物随手删）。改 `cmd/` 子命令 / 工具 / 目录结构 → **同提交把 `.gitignore`·`Makefile`·`mise.toml` 同步到当前物理事实**（删尽对已不存在之物的忽略 / 引用 / 目标——同 #7「状态即重述」、把 gitignore·Makefile 也当状态）。删前先辨：产物（可删）vs 源码 / 版本钉文件（如 `mise.toml`，不动）。

---

# 测试与门禁（T 系列）

- **T5 验收双层**：单元/集成测试随包；**全功能黑盒验收在 `testend/`**（独立 module、零 backend import、拉真二进制打纯 HTTP/SSE）——`make testend`（llmmock 零 token，分钟级）+ `make evals`（真模型金标，EVALS=1 门控烧钱）。两者不进 `make verify`。见 [`references/testend/overview.md`](docs/references/testend/overview.md)。
- **T6 Fake LLM**：默认测试用 `fake_llm`，0 Token 消耗。
- **`make verify`（pre-push 门禁，host 平台）**：`gofmt` 净 + `go vet` + `go build` + 单测 + 文档门禁全绿。并发/取消测试带 `-race`。
- **`make docs`（文档门禁）**：`cmd/docs` 跑 GOVERNANCE §11 全套（frontmatter / 类型 / 生命周期 / INDEX≤50 / 孤儿链接）。
- **跨平台 release**：任意平台 `cd backend && GOOS=x GOARCH=y go build ./cmd/server` 直接出二进制——**无内嵌、无预拉**（运行时由自研 `directInstaller` 在目标机首用按需下，见 [`decisions/0001`](docs/decisions/0001-sandbox-runtime-direct-install.md)）。
- **`make fe-verify`（前端门禁，mise flutter）**：codegen（freezed/json/slang）+ `flutter analyze` 净 + `flutter test` 绿。与 `make verify`（后端）分列、各自 pre-push。

---

# 前端开发守则（Flutter 桌面端，按本节 + [`decisions/0004`](docs/decisions/0004-frontend-flutter-architecture.md)）

- **技术栈**：Flutter 桌面端（Dart）。状态 **Riverpod**（经典 provider 写法，非 codegen——此 Dart SDK + freezed 3 太新，riverpod_generator/lint 生态未跟上，见 ADR 0004 取舍）；**freezed + json_serializable + slang** 经 build_runner codegen；**dio**（HTTP）/ **go_router**（导航）/ **window_manager**（窗口尺寸·最小·居中·resize,逻辑点 scale 正确）+ **macos_window_utils**（仅 macOS 窗口外观:无边框 + 加高标题栏让红绿灯居中可点）/ **scaled_app**（应内 Cmd +/- 整体缩放）——窗口三件套都用成熟包、**不手搓**,见原则 #8。工具链经 **mise**（`go` + `flutter`，真·可写官方 SDK；devbox/nix 已弃——只读 store 构建不了 macOS app，见 [`decisions/0005`](docs/decisions/0005-toolchain-mise.md)）。
- **进程模型**：Go 后端作 **sidecar**，客户端经 localhost HTTP+SSE 对接——Dart 抢临时端口 → `ANSELM_ADDR` 拉起 → `/api/v1/health` 门控（零后端改）。dev 用 `ANSELM_BACKEND_URL` 挂已跑后端（`make server`）。
- **分层（3-tier feature-first，对齐 Clean 不照搬）**：`shared/core`（contract/net、SSE gateway、design、i18n、router、process）→ `features/<域>`（各自管 data+state+ui）→ `app`（装配根 + shell）。**无 use-case 层**（客户端零业务规则，Go 二进制即用例）。features **互不依赖**（跨 feature 走 shared provider / nav intent）。唯一框架无关纯模型层：`BlockTreeReducer` / `GraphModel`（承载性正确、须脱 widget/socket 单测）。
- **状态 + 实时**：Riverpod 托管 server-state（`AsyncNotifier` 分页 `loadMore`）+ 三条 `keepAlive` SSE 流。SSE 经 `SseGateway` 的 plain-Dart **`Map<Scope,Stream>` demux 自滤**（**不**在 Riverpod 里逐帧 `.where`）。铁律 **DB 行是真相、流只为实时**：`seq>0` 才 durable / 推进续传游标；ephemeral（delta/tick）只改瞬时视图态、不进耐久缓存。
- **DIP 注入**：`shared` 不依赖上层；**workspace**（=唯一鉴权轴，header `X-Anselm-Workspace-ID`）+ **baseUrl** 由 `app` 经 `ProviderScope` override 注入；401（`UNAUTH_NO_WORKSPACE`→清选区重选）/ 410（`SEQ_TOO_OLD`→重取 REST 再续）在此拦截。
- **契约层 = 后端投影**：freezed DTO 逐字镜像 `references/`；**仅 seal 真封闭集**（4 frame 动词 / 6 block 型 / 5 图节点 kind / 4 trigger 源），协议级 SSE `node.type` 与 ~261 错误码**保持开放 + `unknown` 兜底**。改后端字段 → **同提交**改 Dart DTO（文档纪律延伸到前端契约）。
- **视觉灵魂**：明亮、通透、轻盈。`Tokens.rowHeight = 32` 紧凑；`tool_call` 与 `reasoning` 默认折叠。颜色/度量走 design token，禁内联硬编码。**字体只两档字重**——正文 `AnText.bodyWeight`(w300)、加粗 `AnText.emphasisWeight`(w400),**禁 w500/w600/SemiBold**(加粗一律 `.weight(AnText.emphasisWeight)`;层级靠字号+颜色,不靠更重字重)。
- **i18n**：严禁在 Dart 硬编码中英文；文案走 slang `context.t.<key>`、登记在 `lib/i18n/<locale>.i18n.json`。
- **门禁**：`make fe-verify`（codegen + `flutter analyze` 净 + `flutter test` 绿）。codegen 产物入库（源等价、deterministic，fresh checkout 直接 analyze）。层依赖暂用目录约定 + review 守（custom_lint 待生态跟上 SDK 再接）。桌面真跑 `flutter run -d <平台>` 需完整 Xcode/CocoaPods 等机器层面工具，不入门禁。
- **启动面（规范，三个、永不增 per-feature 入口）**：`make gallery`（组件视觉目录）· `make app`（真壳 + 真后端 sidecar）· `make demo`（真壳 + 假数据、零后端）。**app 与 demo 共用唯一壳 `app/app_shell.dart`（`AppShell`，哪个 feature 在哪个岛只写一次）**，只差两点 ①数据源（app 接 Live repository / demo `ProviderScope` override 成 `features/*/data/*_demo_fixture`）②启动（app 走 `AppStartupGate` 等后端 / demo 跳门控）。**新 feature 接进 `AppShell` 一次、app+demo 同时拥有；绝不为单 feature 加 `make <feature>` 入口或 per-feature 截图**（碎片化必不 sync；截图统一 `test/dev/capture_demo.dart` 截整 `AppShell`）。详见 [`architecture.md`](docs/references/frontend/architecture.md) §6。
- **🔁 迭代流程铁律（Phase 4 起,每个 feature/任务强制)**：① **对接后端前先吃透后端**——凡涉及后端契约的任务,**开工前先多 agent 扇出详读相关后端代码 + `references/backend/`**,产出精确"集成契约"(端点/帧/DTO/错误码/SSE 语义)再动手,**绝不照猜后端**。② **必要时改后端**——前端需要而后端缺的(如 loopback 鉴权、新端点、契约缺口),**允许给后端加端点/中间件**,但须同提交守后端纪律(N/D/E/S/T 系列 + `make verify` + 文档 1:1 同步 #9)。③ **每步执行前大规模扇出调研(两段,缺一不可)**——**(a) 读码吃透相关后端**(见①,产出精确集成契约),**紧接 (b) 联网详调该解决方案的 best practice**(怎么把这套建好:成熟包 / 业界模式 / 已知坑,原则 #8——例:Dart SSE 断线续传、dio 拦截器、Riverpod 分页、子进程托管的标准做法);两段均过对抗验证;再 → working 规范 → **用户拍板** → 单一作者建 → 对抗复审 → 真机截图验 → landed-into docs。④ **超强覆盖测试**——feature 落地配 widget-test 矩阵(空/超长/海量/极值/注入五电池)入 `make fe-verify`;涉后端改动配 `testend` 黑盒(llmmock 零 token);两端门禁各自全绿才算完。

---

# 文档纪律（强制 —— 完整规范见 [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md)）

> 本节是文档规范的**常驻执行层**：CLAUDE.md 每次会话自动加载，故下列规则你**每次都已读到、无「不知道」借口**。详尽规则（6 类型 / frontmatter / 生命周期 / 命名 / 质量门禁）在 `GOVERNANCE.md`——它是 binding。**本节与 GOVERNANCE §0/§7/§12 必须一致**（改一处即同步另一处）。

## 三条铁律（违反 = 严重 Bug，与编译失败同级）

1. **同步**：改代码 → **同一提交**改对应文档。文档落后于代码 = 这次改动**未完成**。
2. **触发即停**：发现文档与代码不符 → 立刻停下修文档（记 `[doc-fix]` dev log），再续原任务。
3. **存疑即查**：不确定 → 查 `GOVERNANCE.md`；它没覆盖 → 按设计原则推导 + 回头补一条进 GOVERNANCE。

## 同步触发表（改左列代码 → 同一提交改右列文档）

| 代码改动 | 必须同步 |
|---|---|
| 新增/改 API 端点 | `references/backend/api.md` + 对应 `domains/<域>.md` |
| 新增/改 DB 表/列 | `references/backend/database.md` + 对应 `domains/<域>.md` |
| 新增/改 error code | `references/backend/error-codes.md` + 对应 `domains/<域>.md` |
| 新增/改 SSE 事件 | `references/backend/events.md` + 对应 `domains/<域>.md` |
| 架构决策（选型/取舍） | `decisions/` 新建一篇 ADR |
| 架构 / 实体 / 引擎 / 路线状态变更 | **整体重述** `concepts/architecture.md` 相关节（非追加） |
| 工程规则 / 设计原则 / N·D·E·S·T 变更 | **整体重述** 本文件相关节（非追加） |
| 前端契约层（DTO / envelope / 错误码）变更 | `references/frontend/contract.md` + 对应 `domains/<域>.md` |
| 前端架构 / 分层 / SSE gateway 规则变更 | `references/frontend/{architecture,sse-gateway}.md` + 本文件前端节 + [`ADR 0004`](docs/decisions/0004-frontend-flutter-architecture.md) |

非穷举。**两种 mode 不混**：`reference` 文档 = 精确同步（逐字吻合代码）；`architecture.md` / 本文件 = **整体重述**（相关节重写到当前状态、删尽旧状态，绝不追加堆叠）——见 GOVERNANCE §1.7。

## 收尾清单（声明任何代码改动「完成」前逐条勾，任一未过 = 未完成）

1. ☐ 碰了上表的东西？→ 对应文档**同提交**更新了？
2. ☐ 改的 `reference` 文档与代码**逐字**对得上（端点/字段/码/事件 一一吻合）？
3. ☐ 改的是状态文档（architecture / 本文件 / GOVERNANCE）？→ 是**整体重述到当前状态**（没在旧内容旁追加、没留旧状态痕迹）？
4. ☐ 新文档 frontmatter 合法（`type`/`status`/`id`）、放对目录（GOVERNANCE §5）？
5. ☐ 删/移文档后无孤儿链接（`INDEX.md` 及他处指向它的都修了）？
6. ☐ 没编辑 `decisions/` 里的 ADR（不可变，只能新建 supersede）？
7. ☐ working 文档落地了（结论提取进 concepts/references + 填 `landed-into` + 移 `archive/`）？

> 工作区卫生（散落二进制 / 产物 / OS 垃圾 + `.gitignore`·`Makefile`·`mise.toml` 同步到当前事实）见 **S22**——每次提交前一并自检（非文档纪律范畴，不入本清单）。
