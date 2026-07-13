---
id: WRK-067
type: working
status: active
owner: "@weilin"
created: 2026-07-11
reviewed: 2026-07-11
review-due: 2026-10-01
audience: [human, ai]
---

# WRK-067 「同轨」P1 普查台账 —— 四轨全量清单

> [`convergence.md`](convergence.md)(WRK-066)§6 的台账本体。**条目只能三种方式关闭:完成(证据=commit)/证伪(复审确认)/用户签字豁免(契约 §7)——AI 无权单方关闭。**
> 普查:11 区 finder + 20 条抽样对抗审计,**假阳率 0/20**。棘轮基线另有机器账(`frontend/test/guards/convergence_baseline.txt`,62 处五类硬违规);本台账是定性全集,二者相交不相等。
> 状态图例:`open` / `done(commit)` / `refuted` / `exempt(§7)`。

## A 视觉收敛台账(115 条,按族分组)

| # | 位置 | 族 | 问题 | 修法 | 量 | 状态 |
|---|---|---|---|---|---|---|
| A-001 | `lib/features/chat/ui/tool_card_control_approval.dart:145` | 窗 | 审批表单预览手搓白岛卡:裸 Container+BoxDecoration(surface+line hairline+radius.card) | 换卡/窗当家件 white-island 变体 | S | done·批9d(审批表单预览手搓白岛卡→AnCard[SizedBox 保满宽];流内卡=chip 圆角,可见变化 16→12,B-043 一致) |
| A-002 | `lib/features/chat/ui/tool_card_document_skill.dart:33` | 窗 | ProseWindow 手搓白卡壳:裸 Container+BoxDecoration(surface+Border.all+radius.card),convergence §4 点名被窗族吃掉 | 换窗壳 prose 内容模式,gallery 先行,删本件 | M | **done·批4**(壳并入 AnWindow[maxHeight+collapsible];件名保留为 prose 薄投影;折叠阈进 AnCap.proseFold 档) |
| A-003 | `lib/features/chat/ui/tool_card_entity_get_bodies.dart:49` | 窗 | raw-mono 回落窗 ToolWindow+Text 遍布本族 ×10+ 处,maxLines 各异(12/20/40/200)、色调各异(muted/danger) | 窗族 raw-mono 变体统一 cap 与色调档 | M | done·批9e(raw-mono 回落窗 15 处散置→共享 `rawMonoWindow` helper[tool_card_skins];行数 12/20/40/200→AnCap.monoError/Compact/Body/FullLines 四命名档;color/maxLines 参数化,视觉零变;+电池) |
| A-004 | `lib/features/chat/ui/tool_card_fs_search.dart:285` | 窗 | GrepContentView 手搓编辑器式命中窗(行号槽+行内点亮+···缝+cap 200),当家件级视觉件住 feature 层 | 升格窗族 hits/code 内容模式进 gallery | M | defer·批9e(GrepContentView 单消费者[仅 tool_card_fs_search],正确用 AnWindow+A-083 已档热力条;升格 gallery/core 对单 feature widget=A-056 式过早抽象[无跨 feature 消费者,移无收益],待第二消费者) |
| A-005 | `lib/features/chat/ui/tool_card_trigger.dart:134` | 窗 | 未知 kind 的 config 用 JsonEncoder 缩进 mono 文本窗,他处原始 JSON 一律 AnJsonTree 有界树 | 改投 AnJsonTree(有界高) | S | **done·批5b 顺手**(未知 kind config→AnWindow 内有界 AnJsonTree) |
| A-006 | `lib/features/chat/ui/tool_hit_list.dart:66` | 窗 | ToolHitList 四族共享命中窗当家件住 feature 层:行 hover 容器/级联/双截断脚注全自实现,未进 core/ui+gallery | 升格 core/ui 窗族命中模式,行壳交行族 | M | defer·批9e(ToolHitList 仅 chat 用[icons.dart 那处是注释非用点],**已有 gallery 样张**[tool_hit_list_specimens],正确组合 AnWindow/AnInteractive/AnChip/token;「升格 core」对单 feature widget=A-056 过早[移无收益]、「行壳交行族」=命中行[content-value 标题+面板门控 nav+当前记+级联+双脚注]≠AnLedgerRow[mono-id 台账行],不同行语义拟合不清;待跨 feature 消费者或专项设计) |
| A-007 | `lib/features/chat/ui/tool_interaction_gate.dart:156` | 窗 | 人闸白岛壳裸 Container+BoxDecoration+Border.all(tone 边),即「四种描边容器」之一 | 卡族 tone-border 槽变体吃掉 | M | 豁免·批9d(深查:人闸=决策容器,card-16 白面+tone 边+**嵌套机器窗**[_evidence:223 内含 AnWindow]——三约束锁死无当家件可承:①含 AnWindow 故不能是叶子 AnWindow[窗禁套窗 assert]②card-16 需与相邻工具卡[AnWindow]一致,非 AnCard chip-12③「card-16 白容器+tone 边+可嵌套」单消费者[自由答复块是 blockquote 非此面],为单件铸新原语=A-056 式过早抽象。手搓 Container 于此一之无二决策面恰当。工程判断豁免) |
| A-008 | `lib/features/chat/ui/tool_interaction_gate.dart:224` | 窗 | 机器 payload 窗用 AnSunkenPanel(带 header),tool 卡同角色一律 ToolWindow——同角色双件并存 | 窗族收敛为一壳,header 作槽位 | S | **done·批4**(→AnWindow header 槽;AnSunkenPanel header 槽随批退役) |
| A-009 | `lib/features/entities/ui/run/block_tree_view.dart:18` | 窗 | agent 轨迹树整文件手搓迷你 transcript(tool_call=AnDisclosure、tool_result=手拼 Row icon+mono ×2 处),与 chat 的共享块行/工具卡族同角色两套系统 | 收敛到 chat 共享 transcriptBlockRow/块行地基,或明记豁免 | L | 豁免·批9d(台账 note 授「或明记豁免」;block_tree_view 已正确用族原语[AnDisclosure/AnChip/AnIcons/AnText],是右岛轻量 ReAct 轨迹的语境恰当组合——收敛到 ChatToolCard 生态=过度工程[113 卡/活舞台机器],到 transcriptBlockRow 紧凑 peek=丢折叠/嵌套/danger 徽保真[同 A-094];_toolResult 的 icon+Expanded(mono) 行=平凡组合非原语级图案。工程判断豁免) |
| A-010 | `lib/features/entities/ui/run/run_terminal.dart:125` | 窗 | run 终端右岛头带 _head 手搓(icon+名+✕ 行 + 动词/meta/badge 次行),而当家件 AnInspectorHead 已存在且编辑器检查器自称其「视觉孪生」 | 换 AnInspectorHead,给它长 badge/trailing 槽承接相位徽 | M | done·批9d(run 终端头手搓双行→AnInspectorHead;新 subTrailingWidget 槽承相位徽[AnChip],度量 pixel-identical;+电池) |
| A-011 | `lib/features/entities/ui/run/run_terminal.dart:286` | 窗 | 审批决断门三处各自手拼:run_terminal._approvalGate、run_cockpit_tab.dart:213 parked 块、flowrun_inbox.dart:139 _ApprovalCard,内容/hint/reason 输入各有差异 | 抽一件共享 ApprovalGate(prompt+reason?+approve/reject)三处复用 | M | done·批9c(抽共享 ApprovalGate 件:framed 卡壳/collectReason 门[仅收件箱送 reason]/showHint/busy;三处 run_terminal._approvalGate·run_cockpit parked 块·flowrun_inbox._ApprovalCard 收编,gallery+电池) |
| A-012 | `lib/features/settings/ui/panels/models_keys_panel.dart:136` | 窗 | _FreeTierCard 裸 Container+BoxDecoration(surface+card 圆角+hairline 边)手搓卡壳 | 换 AnCard(其注释明言收口 settings 卡皮) | S | done·批7(随 B-043 圆角立法改 AnCard,批9a 台账追认) |
| A-013 | `lib/features/chat/ui/stages/approval_stage.dart:50` | 窗 | 手搓带边容器 ×2:信笺纸卡(:50)与理由栏(:75),Container+Border.all+圆角——§4-A 点名的「approval 信笺」窗族对象 | 窗族当家件 prose/tone 槽吃掉 | M | **done·批1**(信笺+理由栏=同胞双 AnWindow;stages_w3_test 钉双窗) |
| A-014 | `lib/features/chat/ui/stages/skill_memory_mcp_stage.dart:41` | 窗 | 手搓带边卡 ×2:skill 装订台卡(:41,AnRadius.card)与 memory 记忆笺(:132,AnRadius.button),同文件两种圆角档;:76 再手搓 hairline 分隔线 | 窗族当家件 prose 模式吃掉,分隔用 AnDivider | M | **done·批1**(skill/memory 双卡→AnWindow 圆角归一 card;分隔线→AnDivider;流式体→prose bare 尾) |
| A-015 | `lib/features/chat/ui/stages/subagent_stage.dart:95` | 窗 | _SubagentCard 手搓带边卡(Container+Border.all+圆角)——§4-A 点名「subagent 卡」窗族对象;:134 又见 AnSize.iconSm - 4 | 窗族当家件 header/tone 槽吃掉 | M | **done·批1**(→AnWindow header/actions/footer 槽;iconXs 铸档清 iconSm-4 ×3;peer 卡 AnFocusRing 激活环[复审:窗面不透明丢 hover/焦点];活终端=同胞 AnLiveTail) |
| A-016 | `lib/features/chat/ui/tool_card_exec.dart:269` | 窗 | _LogsDrawer 与 run_dossier._LogDrawer 两套日志抽屉:尾截 6000 vs 双端 2000+4000+stderr 分段,同角色两做法 | 合成一个 log drawer 件(双端截断为准) | S | **done·批4**(唯一 `log_drawer.dart`:双端 2000+4000+stderr 分段+全量 copy;两私件删;dossierLogs 键退役、计行标签统一 execLogs) |
| A-017 | `lib/features/chat/ui/tool_card_memory_web.dart:105` | 窗 | MemoryNoteCard 手搓描边卡壳(§4-A 指名):自拼头行+裸 Container 发丝线(132,AnDivider 已有)+折叠阈 900/400 魔数 | 窗族卡壳吃掉;发丝线换 AnDivider;阈值进档 | M | **done·批4**(壳→AnWindow;发丝线→AnDivider;400→AnSize.proseViewport、900→AnCap.noteFoldChars[同批 480/10 散文阈两处(ProseWindow+skill 舞台)归一进 AnCap.proseFold]) |
| A-018 | `lib/features/chat/ui/tool_card_skins.dart:31` | 窗 | ToolWindow=窗族收敛对象(§4-A 指名):feature 层薄壳自拼 header/actions 包 AnSunkenPanel,全 chat 机器窗身份压其上 | P3 窗壳(header/actions/tone+term/code/prose/json/diff 内容模式)落地后整体替换并物理删除 | L | **done·批4**(19 文件 44 用点机械换 AnWindow+import 手术;类物理删除;bash 回显进 header 槽;截断注进 footer 槽;ToolIOSection 长 bare 槽防台账展开套窗[复审 HIGH 修法,回归测钉死]) |
| A-019 | `lib/features/chat/ui/tool_card_entity_get.dart:115` | 代码 | EntityCodeWindow 手拼代码窗组合:ToolWindow 塞 AnCodeEditor+窗外灰标签+截断注,正是 #8 批评的形态 | AnCodeEditor 窗形态长 label/截断槽吃掉 | S | **done·批2**(双壳拆除[编辑器即框];标签→AnFieldSection 13 档;渐隐融白面;copyPayload 保全量) |
| A-020 | `lib/core/ui/an_live_code_window.dart:98`(已删) | 代码 | 活代码窗骑 AnSunkenPanel(陷底、chip 圆角),落定代码骑 AnCodeSurface(framed、card 圆角)——live→settled 换脸也换壳,违「同壳同框」蓝图 | 按 §4-A 给 AnCodeEditor 长 live 形态,吃掉 AnLiveCodeWindow | L | **done·批2**(fn/hd 五用点+gallery 换 live 脸;整行按住/行数 CountUp/逐行淡入四能力经逐项判决弃[记法典];AnLiveCodeWindow 物理删除;codeViewportSm=160 铸档) |
| A-021 | `lib/features/chat/ui/tool_card_skins.dart:435` | 代码 | _editSeg 裸 Container+BoxDecoration 拼 ±diff 色块段(Edit live 两幕手术) | 归入代码族 diff 的 live 形态(AnVersionDiff live 面) | M | **done·批2**(_editSeg 物理删除;两幕走 AnVersionDiff.live 同管线同 bar) |
| A-022 | `lib/features/chat/ui/tool_card_skins.dart:396` | 代码 | Write/builds live 脸=ToolWindow 塞裸 mono Text ×2(396/728;同模式 memory_web:172)——§0 批评#4 原型场景 | AnCodeEditor 长 live 形态(同壳同框同 copy 位)后替换 | M | **done·批2**(Write/builds 两脸一壳同档零跳变;live O(tail) 族头内建[切尾+行号续排];memory_web:172 归族改判→AnLiveTail prose[便笺是散文,与 doc/skill 稿同判]) |
| A-023 | `lib/features/chat/ui/tool_card_skins.dart:657` | 代码 | _langOf 扩展名→语言映射手搓于 feature 层(707 _buildLang 又一张表),属地基能力 | 归 AnCodeEditor/core 侧 langOf,删两处私表 | S | **done·批2**(core langOf/langOfEntityKind;两私表删;ts→typescript 改判有测钉死) |
| A-024 | `lib/features/chat/ui/tool_card_entity_get_bodies.dart:107` | 芯片 | 导航 pill onTap 闭包(panelLocationFor+context.go)重抄 ×6 处跨 5 文件,tool_card_nav.toolNavPill 已存在 | 全改用 toolNavPill,删私抄 | S | **done·批5b+复审补清**(6 处私抄全并:_navPill×2/lifecycle×2/entity_get 头/search onRowTap/conversation;新增唯一导航闭包 goToPanel 进 tool_card_nav,toolNavPill 同骑) |
| A-025 | `lib/features/chat/ui/tool_card_trigger.dart:138` | 芯片 | _lockChip 手搓芯片:Container+Border.all+radius.tag+icon+label,chip 族分外私铸 | 换 chip 族当家件 icon+label 变体 | S | **done·批5b**(→AnChip outlined+icon;墨 faint→muted 族提档) |
| A-026 | `lib/features/chat/ui/tool_hit_list.dart:256` | 芯片 | _currentMarker「当前」手搓芯片:Container+accentSoft+radius.tag+label 文本 | 换 chip 族 tone=accent 变体 | S | **done·批5b**(→AnChip(tone: accent) filled 族声;字面 13 label→12 meta 随族) |
| A-027 | `lib/features/settings/ui/panels/shortcuts_panel.dart:164` | 芯片 | 键帽/录制态 chip 用 GestureDetector+Container 手搓;Border 默认宽 1 非 AnSize.hairline | 芯片族长 keycap/recording variant 进 gallery | M | **done·批5c**(新原语 AnKeycap 三态[不可聚焦,焦点序回归钉];边宽 1→hairline 档;状态机留面板) |
| A-028 | `lib/features/settings/ui/panels/workspaces_panel.dart:104` | 芯片 | _ColorDot(size 10 裸数)与 _ColorPicker(:204,22×22+选中边宽 2 裸数)手搓圆点色板 | 收成 swatch/色点原语,尺寸走 AnSize 档 | M | **done·批5c**(新原语 AnSwatch dot/pick+选中环 ring 档[2→1.5 归档];色表+parseHexColor 迁 core[文法 #6];两手搓类删) |
| A-029 | `lib/core/editor/an_editor_mention.dart:112` | 芯片 | _MentionPill 手搓行内提及药丸(Container+accentSoft+tag 圆角+icon+名),复刻 AnRefPill(芯片族当家件)职责;内含裸数字 margin 1px、gap 3px、height:1.0 私调 | 给 AnRefPill 长 inline/baseline 变体(贴文字基线),药丸改用之 | M | **done·批5b**(内壳→AnRefPill.inline[骑 AnInlineCapsule];LineHeight 基线壳留 editor;纯展示,IME/光标不破,53 测绿) |
| A-030 | `lib/core/ui/an_cel_grow.dart:77` | 芯片 | CEL 文内 [[ref]] 渲成手拼 accentSoft 圆片,实体引用另有 AnRefPill(边框药丸)——同一「引用」角色两张脸 | ref 视觉归 AnRefPill 家族(inline 形态) | S | **done·批5b**(→AnInlineCapsule;compact 2px 内距归族 4px 档) |
| A-031 | `lib/core/ui/an_copy_chip.dart:49` | 芯片 | chip 族几何各自为政:AnBadge=pill+badge 高、AnRefPill=pill+s6/s2、AnCopyChip=tag 圆角+s8/s2、AnScopeBadge=chip 圆角+v:1 裸数、AnAttachmentChip=chip+LTRB(8,4,4,4)——3 种圆角 4 种内距 2 种定高法 | P2 chip 当家件定单一几何,tone/icon/mono 热插拔 | M | **done·批5c**(四件归一[批5a]+尾项 AnAttachmentChip 改判:两行复合附件控件非小标签芯片,几何自持合理[LTRB 全 token],判非族内) |
| A-032 | `lib/core/ui/an_path_chip.dart:15` | 芯片 | AnCopyChip 与 AnPathChip 同角色(mono 值+复制+✓ dwell 复位)双件:一个带边框药丸壳、一个裸 Row 无壳,同手势两张脸 | 并成一件 copy-chip,path 是 variant(basename+tooltip) | M | **done·批5a**(AnCopyChip 物理删除 8 用点→AnChip outlined+mono+copyValue+tooltip;AnPathChip 薄预设[自有知识=basename 切法];copyDone 死键退役;族声=outlined) |
| A-033 | `lib/core/ui/an_term_viewport.dart:124` | 芯片 | _backToLatest 手搓浮动药丸 CTA(border+pill+icon+label),与 AnFollowPill(呼吸浮丸)同为「回到现场」类 offer 两套壳 | 浮丸 CTA 归一件,follow/backToLatest 做 variant | M | **done·批5a**(AnFollowPill.jump 静态脸——绝不呼吸不挂钟;elevated 浮影档 AnOpacity.shadow) |
| A-034 | `lib/dev/gallery/gallery_app.dart:252` | 芯片 | 「压力」标签手搓 chip(Container+warnSoft+AnRadius.tag),AnBadge(warn) 现成 | 换 AnBadge('压力', tone: warn) | S | **done·批5a**(→AnChip('压力', tone: warn),AnBadge 已并入 AnChip) |
| A-035 | `lib/features/chat/ui/chat_composer.dart:490` | 芯片 | 缩略图角上 ✕ 的 surface 圆底用 DecoratedBox+BoxShape.circle+Border.all 手搓,附件件本应自带该 affordance | AnAttachmentThumb 长 onRemove 槽,删此手搓 | S | **done·批5b**(AnAttachmentThumb 长 onRemove/removeLabel 槽,composer 手搓 Stack 退役) |
| A-036 | `lib/features/chat/ui/chat_transcript.dart:386` | 芯片 | _BackToLivePill 手搓浮层药丸(Material+StadiumBorder+elevation 2+ink 0.12 私调阴影),与 core 已有 AnFollowPill 同角色两做法 | AnFollowPill 加 jump-to-present variant 吃掉它 | M | **done·批5a**(→AnFollowPill.jump(elevated:true);0.12 阴影入 AnOpacity.shadow 档;类删除) |
| A-037 | `lib/features/chat/ui/run_dossier.dart:231` | 芯片 | 出处行非导航坐标注释称「mono copy-badges」实为裸 AnText.meta 灰字(非 mono 非 chip),与 ProvenanceLine 内 toolNavPill 排布两做法 | 改 AnCopyChip(mono+copy 热插拔) | S | **done·批5b**(四坐标→真复制芯片 AnChip outlined+mono+copyValue;_mono/_short 删,截断走 AnTrunc.id) |
| A-038 | `lib/features/chat/ui/run_ledger.dart:61` | 芯片 | 手搓状态圆点 Container+BoxDecoration circle ×3(61/164/167),AnStatusDot 已有 | 换 AnStatusDot(补 color 直喂形态) | S | **done·批5a**(AnStatusDot.raw 直喂色+hollow 空心;三处换装[空心环边宽 1→hairline 归一]) |
| A-039 | `lib/features/chat/ui/run_ledger.dart:61` | 芯片 | 手搓状态点 Container+BoxShape.circle ×3(:61 珠/:164 空心/:167 实心),同型再现 handler_stage:111、trigger_stage:81、function_stage:133,全绕开 AnStatusDot | AnStatusDot 长任意色/空心 variant,六处统一 | M | **done·批5b**(六处全清:批5a 五处+function_stage opTicker 内点随 A-043 进 dot 槽 dotSm 档) |
| A-040 | `lib/features/chat/ui/stages/agent_stage.dart:104` | 芯片 | _beltChip 手搓芯片(Container+Border.all+AnRadius.chip)——WRK-066 §4-A 点名的 chip 族清剿对象 | 换 chip 族当家件(tone/mono 插拔) | S | **done·批5b**(删壳留脑:_beltLabel 解析自有,壳→AnChip outlined;live/settled 同声零跳变) |
| A-041 | `lib/features/chat/ui/stages/approval_stage.dart:101` | 芯片 | 琥珀插值药囊手搓 chip,margin/padding 用裸 1px(非 4 网格任何档) | 抽内联 capsule chip 原语,1px 入档 | S | **done·批5b**(→AnInlineCapsule(tone: warn);裸 1px 入 capsulePadY 档) |
| A-042 | `lib/features/chat/ui/stages/document_stage.dart:196` | 芯片 | _PilledProse 手搓 [[id]] 内联药丸(Container+accentSoft+裸 vertical:1),AnRefPill 已存在;与 approval 药囊各写各的伪药丸 | AnRefPill/内联 capsule 原语统一 | S | **done·批5b**(→AnInlineCapsule;与 approval 囊同壳) |
| A-043 | `lib/features/chat/ui/stages/function_stage.dart:124` | 芯片 | _OpTicker 手搓芯片(Container+Border.all)+内点 AnSize.dot - 2 裸算术 ×2(:133);_DiffBadge(:165) +n−m 也是手拼——§4-A 点名「op ticker 点」 | chip 族当家件吃掉,dot 档补空心/小号 | M | **done·批5b**(opTicker→AnChip+dot 槽双脸同构零跳变[live 空心/落定实心];_DiffBadge 并入 runStatBarOf extraStats 缝[out==null 兜底];dot-2 算术→dotSm 档) |
| A-044 | `lib/features/chat/ui/tool_card_catalog.dart:149` | 芯片 | id/文本截断三元表达式手搓 ×15+,截断档随手定(10/12/24/40/48)无共享 helper | 共享 truncate helper+标准档,target chip 统一走它 | S | **done·批5b+复审补清**(24 处三元式→truncate(AnTrunc)[复审抓获 runlog:241 漏网 1 处];10→12/40→48 档位归一刻意收敛;界外注记勘正:120 预览/4 keyMasked 为「length>N?」形豁免,sha 前缀/80 rundown 为非三元式语义) |
| A-045 | `lib/features/chat/ui/tool_card_skins.dart:63` | 芯片 | WindowCopyButton 手搓复制钮(✓一闪状态机),与 AnCopyChip、AnCodeEditor copy 条三套复制件并存 | 并入 chip 族 copy variant,一件三形态 | S | **证伪·批5c**(批5 后三套复制件并两套;WindowCopyButton=窗 chrome 示能与编辑器 copy 条同类,芯片壳会给每窗头加边框重量违轻盈;「窗头 vs 编辑器条」双 chrome 记 B 轨扫尾候选) |
| A-046 | `lib/features/chat/ui/tool_card_workflow.dart:129` | 芯片 | op ticker kind 色点=裸 Container+BoxDecoration 方块(§4-A 芯片族指名「op ticker 点」) | chip 族 dot/tone variant 吃掉 | S | **done·批5a**(→AnStatusDot.raw swatch 档;方块→族圆点=刻意裁决[一点一族],帧核) |
| A-047 | `lib/features/chat/ui/tool_card_workflow.dart:268` | 芯片 | _morphChip 手搓描边 chip(§4-A 指名),且 tone.withValues(alpha:0.5) 私调透明档 | chip 族 tone+strikethrough variant;透明走 AnOpacity 档 | S | **done·批5b**(→AnChip outlined+tone+strikethrough;半透边→全 tone 边刻意裁决) |
| A-048 | `lib/features/notifications/ui/notification_row.dart:150` | 芯片 | _Dot 手搓圆点(Container+BoxDecoration circle),且用 AnSpace.s6 当尺寸;点族已有 AnStatusDot 一源 | 点原语加纯色 tone 形态,尺寸走 AnSize.dot | S | **done·批5a**(→AnStatusDot.raw;6px 杂号→dot 档 7px,刻意归档) |
| A-049 | `lib/features/chat/ui/tool_card_ecosystem.dart:169` | 行 | marketplaceBody 手搓目录行(icon+名+徽章+缩进描述)于 ToolWindow 内,同形枚举本该投 ToolHitList | 改投 ToolHitList(subtitle+trailing 徽章) | S | **done·批6b**(→ToolHitList 目录枚举;外层 AnWindow 随撤防套窗) |
| A-050 | `lib/features/chat/ui/tool_card_ecosystem.dart:229` | 行 | get_model_config 默认模型 label-value 渲成裸 mono Text 行,全族同角色一律 AnKv | 换 AnKv(dense: true) | S | **done·批6b**(→AnFieldSection+AnKv dense mono) |
| A-051 | `lib/features/chat/ui/tool_card_entity_get_bodies.dart:261` | 行 | bool 值渲 '✓':'—' 字面量,conversation.dart:86-87 同样重抄——bool KV 无当家渲法 | AnKvRow 加 bool 变体 | S | **done·批6b**(AnKvRow.flag 唯一 bool 渲法×3;a11y 念本地化是/否) |
| A-052 | `lib/features/chat/ui/tool_card_fs_search.dart:89` | 行 | 尾注分隔用 '  ·  '(双空格)×2 处(89/150),他处 meta 分隔一律 ' · ' 单空格 | 统一 meta 分隔符,入版式文法 | S | **done·批6b**(单空格归一×2;全仓 grep 已核尽) |
| A-053 | `lib/features/chat/ui/tool_card_todo.dart:83` | 行 | TodoChecklist._row 手搓清单行:Padding+Row+Icon+删除线文本,行族分外私铸 checkbox 行 | 行族当家件长 checkbox 变体吃掉 | S | **done·批6b·改道**(TodoChecklist 渲染退役并入 AnRundownList——泡与侧幕两副面孔归一,原则 #8;不给 AnLedgerRow 长 checkbox) |
| A-054 | `lib/features/entities/ui/detail/overview/control_overview.dart:49` | 行 | control 路由分支行两处两做法:_branchRow 双行(when mono + emit label)vs workflow_editor_inspector.dart:433 _ControlBranches._row 单行(when + emit warn 徽) | 抽一件共享 BranchRow,两处同脸 | M | **done·批6b**(共件 ControlBranchRow=概览双行脸;inspector 单行省略丢 CEL+emit warn 徽违文法 #6 退役) |
| A-055 | `lib/features/entities/ui/detail/overview/handler_overview.dart:38` | 行 | handler 身份段手拼 AnSection+AnField+kvList,而 identitySection 助手自述「agent+handler 共用」且 agent/control/approval/trigger 四处都在用 | handler 改用 identitySection | S | **done·批6b**(→identitySection 共享助手,逐字重抄删) |
| A-056 | `lib/features/entities/ui/detail/workflow_editor_inspector.dart:213` | 行 | _InputMapEditor 手搓可编 KV 行:SizedBox(AnSize.inspectorKeyCol) mono 键 + AnInput + 删钮,行族 AnKv 已有 editable 模式却未承接 map 编辑 | AnKv 长 map 编辑 variant(键列+值输入+增删),吃掉此手搓 | M | open·**defer 记档**(批6 scout 裁决:map 编辑器=表单机器[焦点保活/live-commit/增删行]非键值陈列,单消费者过早抽象[原则 #8:错误抽象比重复糟];AnKv.map 规格留 batch6-row-map.json 待第二消费者) |
| A-057 | `lib/features/entities/ui/detail/workflow_editor_inspector.dart:297` | 行 | _RetryEditor 用「标签左·控件右」Row 排布(×2 行),与本文件自述并全 inspector 遵守的「标签上·块控件下」_Field 语汇相悖 | 开关/数值行归入 AnFormField 语汇或成文豁免开关行式 | S | **done·批6c**(→AnField child 槽:「标签左·控件右」唯一行;标签在上的开关=反模式) |
| A-058 | `lib/features/entities/ui/flowrun_inbox.dart:49` | 行 | sectioned 模式「待你处理」段头手拼 Padding+Text(meta·emphasis·inkFaint),托盘段头角色未走 AnSection/共享段头件 | 用 AnSection quiet 标签或与通知托盘段头共件 | S | **done·批6b**(两处像素级同款→AnGroupLabel 共件;_SectionLabel 删;en 大写化记档) |
| A-059 | `lib/features/settings/ui/panels/mcp_forms.dart:147` | 行 | _label 私铸「标签在上」字段块 ×9 调用;样式 label+inkMuted 偏离 AnFormField 规范 strong+ink | 全部换 AnFormField | S | **done·批6c**(_label ×7 删→AnFormField;标签 13/muted→族脸回正,帧核) |
| A-060 | `lib/features/settings/ui/panels/memory_panel.dart:132` | 行 | 行描述内联塞 labelWidget Row,mcp/市场同角色走 AnRow.hint,两种排布 | 描述改走 AnRow.hint,pin 留 lead 槽 | S | **done·批6c**(pin→AnRow leadWidget[批6a 槽]+描述走 hint;顺手修 leadWidget 语义剥除防批5 ✕ 覆辙) |
| A-061 | `lib/features/settings/ui/panels/memory_panel.dart:266` | 行 | MemoryEditor 内联标签字段块 ×3(266/282/287),同一手搓模式第四处复制 | 换 AnFormField | S | **done·批6c**(×3→AnFormField;Cmd+S 贴身包原位) |
| A-062 | `lib/features/settings/ui/panels/models_keys_panel.dart:404` | 行 | KeyForm 内联 Text 标签+SizedBox(s4)+输入 手搓字段块 ×5(404/420/424/440/446) | 换 AnFormField | S | **done·批6c**(×5→AnFormField;rotateWarn 注记保 sibling 非 desc) |
| A-063 | `lib/features/settings/ui/panels/network_panel.dart:100` | 行 | _field 私铸「标签+输入」字段块 ×3,与 mcp_forms._label 是同角色第二实现 | 换 AnFormField,删 _field | S | **done·批6c**(_field ×3 删→AnFormField,同角色第二实现亡) |
| A-064 | `lib/features/settings/ui/panels/sandbox_panel.dart:110` | 行 | envs 节头手搓 Text(readingH3)+SizedBox,同面板与全 settings 其余节均用 AnSection | envs 节改 AnSection(quiet) | S | **done·批6b**(→AnSection;孤例手搓头+两 s24 spacer 退役;360 魔数留 B 轨) |
| A-065 | `lib/features/settings/ui/panels/sandbox_panel.dart:190` | 行 | _InstallForm 内联标签字段块 ×2(190/201) | 换 AnFormField | S | **done·批6c**(×2→AnFormField;version 条件子树两分支同壳) |
| A-066 | `lib/features/settings/ui/panels/workspaces_panel.dart:175` | 行 | _CreateForm/WorkspaceEditor 内联标签字段块 ×4(175/179/304/311) | 换 AnFormField | S | **done·批6c**(×4→AnFormField) |
| A-067 | `lib/core/ui/an_lead_value.dart:1` | 行 | 标签-值排布三套文法并存:AnTwoZone(label 占满+meta 右封 45%)/AnLeadValue(lead 贴左+value 贴右吃余)/AnKv,且 AnKv+AnKvRow 埋在 an_field.dart 里难寻 | 选型查表入法典(三套=成文分工);AnKv 拆出 `an_kv.dart`;AnLeadValue 内化(barrel 撤export) | M | done·批6a |
| A-068 | `lib/dev/gallery/gallery_app.dart:112` | 行 | _navRow 手搓可选中行(AnimatedContainer+BoxDecoration hover/selected 填充),_nav 手搓侧栏面(Container+右边线)——gallery 自家壳没吃 AnRow 狗粮 | nav 行换 AnRow,面换 AnIsland/既有侧栏原语 | S | **done·批6b**(行=AnRow 狗粮;面=证伪:AnIsland 浮卡角色不符,dev 壳脚手架豁免记档) |
| A-069 | `lib/features/chat/ui/chat_tool_card.dart:309` | 行 | 工具卡主行手搓:ConstrainedBox(minHeight:AnSize.row)+自拼 icon/动词/target/回执尾/AnimatedRotation chevron | 行族 disclosure 行当家件承载(chevron 含在内) | M | open·**豁免复核**(契约 §7 主行豁免有效;AnShimmerText 活动词/三声调回执均在 AnLedgerRow 契约外) |
| A-070 | `lib/features/chat/ui/run_ledger.dart:142` | 行 | _RunRow 手搓台账行(dot·mono·chips·elapsed·stamp 排布);217 expandContent 缩进 AnSize.iconSm+AnSpace.s8 裸算术 | 行族台账行当家件;缩进收档 | M | **done·批6b**(_RunRow→AnLedgerRow 一行调用;:214 缩进算术随迁物理消失) |
| A-071 | `lib/features/chat/ui/run_ledger.dart:129` | 行 | 「展开全部 N」escape 手搓 ×2(run_ledger:132/flowrun:215),AnInteractive+accent 加重文本重复实现 | 抽 show-all escape 小件或并入台账行件 | S | **done·批6b**(两处逐字同形 escape→AnLedgerList[批6a 新件];flowExpandAll 键退役) |
| A-072 | `lib/features/chat/ui/run_ledger.dart:171` | 行 | _RunRow 手搓台账行(点·mono id·chips·耗时·时戳 全手拼),feature 层私有视觉件不进 gallery | 并入行族当家件或升格 gallery 原语 | M | **done·批6b**(与 A-070 同源同刀——同一 widget 两条台账记录) |
| A-073 | `lib/features/chat/ui/stage_panel.dart:456` | 行 | _TodoRow 用 ClipRRect+AnimatedContainer+Row 手搓复刻 AnRow 度量(注释自认「Composed to the AnRow metrics」),进度环 lead 逼出整行重抄 | AnRow 长出自定义 lead 槽,todo 行改用 AnRow | M | **done·批6b**(AnRow leadWidget 槽[批6a]承 AnTaskRing;度量重抄删;chevron 随行惯用式) |
| A-074 | `lib/features/chat/ui/stage_panel.dart:805` | 行 | _RunProgressSection 手搓运行台账行(icon+mono+badge 逐行拼),内嵌 AnSize.iconSm - 2 裸算术(:834) | 并入 RunLedger/行族当家件,图标走档位 | M | **done·批6b**(→AnLedgerRow+语义点[fromRaw 语义更真];iconSm-2 算术与 ' · ' 手拼亡) |
| A-075 | `lib/features/chat/ui/stages/control_stage.dart:71` | 行 | 判别梯的序号圆圈(Container circle+border+数字)+求值丝线(Container hairline)全手搓,似 AnStepper 角色 | 抽 ladder/stepper 原语进 gallery | M | **done·批6b**(骨架抽 AnLadder[批6a]迁 control_stage;AnStepper 角色不同不并;chat 第二套梯记扫尾+法典防第三套;:109 alpha 私调记 B 轨) |
| A-076 | `lib/features/chat/ui/tool_card_flowrun.dart:240` | 行 | FlowrunNodeList._nodeRow 与 RunLedger._RunRow 同角色两种排布(状态点一右一左);263 错误行缩进裸算术 | 同一台账行件承载两处 | M | **done·批6b**(状态点归左[法典②]、kind 字形降首枚 chip、错误行 danger 副行;:256 算术亡) |
| A-077 | `lib/features/chat/ui/tool_card_io_section.dart:59` | 行 | ToolIOSection 逐键标签-值排布手搓(§4-A 行族指名「ToolIOSection 标签排布」),AnKvRow 已有 | AnKv+对齐文法吃掉逐键列 | M | **done·批6b**(节头→AnFieldSection 12→13 回正;逐键列值形二分:全短标量→AnKv dense+flag/长值→逐键 AnFieldSection;bare 缝零接触,回归钉保绿) |
| A-078 | `lib/features/chat/ui/tool_card_memory_web.dart:346` | 行 | _WebHits 手搓命中行(裸 Container+BoxDecoration hover 圆角)绕开 ToolHitList 共享命中门;377 私铸 meta+mono 拼字体;collapsedHeight 420 魔数 | 迁 ToolHitList/行族命中行;字体档进 AnText | M | **done·批6b**(→ToolHitList+onOpen 外链通道[批6a];15 档越锚/私铸拼字体/420 魔数三宗随行退役) |
| A-079 | `lib/features/chat/ui/tool_card_memory_web.dart:543` | 行 | _ToolHitCard 手搓工具箱薄卡(baseline Row 名+参数摘要+描述+schema 抽屉) | 行族薄卡/命中行当家件吃掉 | S | **done·批6b**(→AnLedgerRow:名+摘要 chip+描述副行 tease;点行展开全文+schema 树) |
| A-080 | `lib/features/chat/ui/tool_card_skins.dart:171` | 行 | intent/summary 行三套实现:_intent(171)/memory_web _summaryLine(239)/exec·workflow·flowrun 内联 Padding+Text ×7 处 | 一个共享 intent 行件,全族复用 | S | **done·批6b**(toolIntent 升公收编 17 用点[现场增殖:内联 12+私件 5];gap:false 唯一位=workflow edit;chat_tool_card:382 带标签段证伪不并) |
| A-081 | `lib/features/documents/ui/documents_inspector.dart:120` | 行 | 右岛段标题手搓 ×2(:120 大纲、:214 反链):Text meta+emphasis+inkFaint 不用 AnGroupLabel;两处下间距还不同(stackTight vs stack)且不大写、与 AnGroupLabel 版式分叉 | 两处换 AnGroupLabel,间距归一 | S | **done·批6b**(两处→AnGroupLabel;两种下距归一件) |
| A-082 | `lib/features/documents/ui/documents_inspector.dart:235` | 行 | _MetaRow 手搓标签-值行(SizedBox 定宽标签+Expanded 值),正是收敛契约点名该由 AnKv 吃掉的手搓 label-value | 换 AnKv/AnKvRow | S | **done·批6b**(→AnKv dense;path mono+wrap 保尾段;定宽列→家族几何) |
| A-083 | `lib/features/chat/ui/tool_card_fs_search.dart:387` | 条 | _countHeat 手搓热力条:裸 40*(count/maxN) 宽 Container+accentSoft,40 为裸数字 | 收进条族 meter 变体,宽入 token | S | done·批9a(AnSize.heatBar 档,相对热力短条刻意非 AnMeter) |
| A-084 | `lib/features/settings/ui/panels/sandbox_panel.dart:38` | 条 | bootstrap 失败横幅裸 Container+BoxDecoration(dangerSoft+圆角)+Row 手搓 | 换 AnCallout(danger)+actions 槽 | S | **done·批3.5**(→AnCallout danger+actions;手搓壳删) |
| A-085 | `lib/core/editor/an_editor_toolbar.dart:227` | 条 | _AnFormatBar(:227)与 _LinkInputBar(:303)×2 手搓浮岛壳(surface+chip 圆角+hairline+shadowPop),与 AnFloatingBar 近逐字同款却分叉(button 圆角/shadowFloat) | 两条浮条壳换 AnFloatingBar(或给它长 shadow/radius 槽) | S | 判断题记档·批9f(编辑器选区工具条=**overlay-popover**[浮在文本选区上方,按需出现]——shadowPop 是覆层阴影语义,对此浮层比 AnFloatingBar 的 shadowFloat[画布 on-content chrome]更对;chip 圆角同理;共享的 surface+hairline+padding+Row 壳结构平凡,为语义真差异[overlay vs chrome]给 AnFloatingBar 加 radius/shadow 槽=不值。判断题裁:留手搓,shadow/radius 反映真语义) |
| A-086 | `lib/features/chat/ui/chat_context_mark.dart:65` | 条 | 手搓带标签分隔线:Container(hairline)×2 夹居中 icon+文字,AnDivider 已存在但无 label 形态 | AnDivider 长 labeled variant 吃掉 | S | **done·批3.5**(AnDivider.labeled(label,icon) 新形态;ChatContextMark 只剩 marker 解析+i18n) |
| A-087 | `lib/features/chat/ui/chat_tool_card.dart:289` | 条 | ' · ' InlineSpan 手拼元数据链模式,同型散布(skins RunStatBar:864/workflow legend:227/flowrun _summaryBar:235) | 出一个 meta 链小件(spans+分隔符统一) | M | done·批9a(flowrun _summaryBar→AnStatBar 关最后一处;RunStatBar/legend 批3 已并;收起行回执尾=行内尾注豁免) |
| A-088 | `lib/features/chat/ui/tool_card_exec.dart:192` | 条 | _InvokeStatBar 第三条结果条(§4-A 指名):badge+steps+↑↓token+elapsed+pill+copy Wrap 自拼 | 并入 AnStatBar 槽位化 | S | **done·批3**(→_invokeStatBar 映射 helper;timeout 显式 err[fromRaw 无别名折 idle 丢危险色,注释钉死];空格分隔→' · ' 链) |
| A-089 | `lib/features/chat/ui/tool_card_flowrun.dart:145` | 条 | _RunFooter 第四条同角色状态条(badge+重放数+workflow pill+copy),§4-A 初表未列、普查补录 | 并入 AnStatBar 收敛清单 | S | **done·批3**(→_runFooter 映射 helper;fromRaw 单源+域词;replay 侧删双距 SizedBox) |
| A-090 | `lib/features/chat/ui/tool_card_io_section.dart:100` | 条 | ExecResultBar 第二条结果条(§4-A 指名),状态词+耗时+trailing 自拼 | 并入 AnStatBar 槽位化 | S | **done·批3**(物理删除[trailing/failLabel 死参随葬];exec 站点=词徽域词+耗时 stat) |
| A-091 | `lib/features/chat/ui/tool_card_skins.dart:827` | 条 | RunStatBar=条族三合一对象(§4-A 指名),手拼 ' · ' InlineSpan 链;envFix 行 797 还带 AnSize.iconSm+AnGap.inline 裸算术缩进 | 并入槽位化 AnStatBar;缩进收 token 档 | M | **done·批3**(物理删除→runStatBarOf 适配器[18 用点];AnStatBar 长 leading 槽[凭据 pill 领跑];envFix 缩进结构化悬挂[裸算术清];_RunFooter/workflow legend 同批并入;收起行回执尾豁免记档) |
| A-092 | `lib/features/chat/ui/chat_thinking.dart:202` | 活尾 | _scrollWindow 手搓限高钉底边缘渐隐流窗(TextPainter 量行高+jumpTo 钉底),活尾第三形 | 并入活尾族 flow-window 变体 | M | **done·批1**(→AnLiveTail prose bare;与 A-096 同修) |
| A-093 | `lib/features/chat/ui/tool_card_document_skill.dart:86` | 活尾 | document/skill 活脸=ToolWindow+tailLines(draft,8) mono 尾 ×2 处(86/142),手搓活尾非当家件 | 换活尾当家件(AnTermTail 类)统一活流形 | S | **done·批1**(→AnLiveTail prose[贴底=最新字可见,复审改判 prose 非 mono];O(tail) 族头内建) |
| A-094 | `lib/features/chat/ui/transcript_peek.dart:139` | 活尾 | NestedRunPane 活尾自实现(末行换 AnShimmerText 微光),与 ToolLiveTail/AnTermTail 并存成活尾第三形 | 活尾族收敛时并入统一微光尾 | S | 证伪·批9b(建造者请求准:NestedRunPane=AnWindow 内结构化块行目录[复用 transcriptBlockRow]+末行 AnShimmerText 微光,两既有原语组合;非 AnLiveTail 裸文本活尾第三形——压成纯文本尾丢结构行/isOpen 微光/块型判别六能力,角色不同不并) |
| A-095 | `lib/features/entities/ui/run/run_terminal.dart:238` | 活尾 | fn/hd 流式输出 s.text 每帧整体塞静态 AnCodeBlock(_mono,行341)重渲,无活尾;chat 已有 AnTermTail/AnTermViewport 有界回滚活尾 | 接活尾族当家件(AnTermTail 收进 core 后),流动期只渲尾部 | M | **done·批1**(两脸同件 AnTermViewport[复审改判:6 行尾丢运行中回看+落定裸渲 ANSI→有界回滚终端窗两脸零换脸];running 期有测) |
| A-096 | `lib/features/chat/ui/chat_thinking.dart:202` | 活尾 | _scrollWindow 手搓限高·钉底·上下边缘渐隐的活散文流窗(TextPainter 量行+双 edge fade),与 AnTermTail/活尾族同角色 | 活尾当家件长 prose 模式,ChatThinking 换装 | L | **done·批1**(prose bare 脸+溢出顶渐隐[族头新能力];删 _scrollWindow/双向渐隐/ScrollController 全套;**流式期改只读不可滚**[族契约,回看=落定展开],刻意裁决记档) |
| A-097 | `lib/features/chat/ui/tool_card_skins.dart:98` | 活尾 | ToolLiveTail(v1) 与 AnTermTail(v2) 两个活尾并存(§4-A 指名二合一),v1 仅剩 mount:69/109 两处在用 | mount 两处换 AnTermTail 后物理删 v1 | S | **done·批1**(mount ×2→AnLiveTail.mono;v1 物理删除) |
| A-098 | `lib/features/chat/ui/tool_card_skins.dart:124` | 活尾 | AnTermTail(§4-A 活尾族当家件)定义在 feature 层 tool_card_skins.dart 而非 core/ui,逃出原语库治理;AnDocumentEditor 同病(features/documents) | 迁 core/ui 独立文件,与 ToolLiveTail 二合一 | M | **done·批1**(feature 版 AnTermTail 物理删除;core AnLiveTail.term 即合体;gallery 反向 import 顺手斩) |
| A-099 | `lib/features/chat/ui/tool_card_ecosystem.dart:95` | 其它 | _issue 用 RichText(不继承 textScaler/DefaultTextStyle),fs_search:334 同类用 Text.rich;transcript_peek:85 同病 | 统一 Text.rich(a11y 缩放才生效) | S | done·批9a(RichText→Text.rich,a11y textScaler 才生效;ecosystem+transcript_peek) |
| A-100 | `lib/features/chat/ui/tool_card_lifecycle.dart:149` | 其它 | activate_skill 6000 字符顶再度硬编码,entity_get.kEntityContentCap 已有同值共享常量 | 复用 kEntityContentCap | S | done·批9a(activate_skill 6000→kEntityContentCap 复用) |
| A-101 | `lib/features/chat/ui/tool_interaction_gate.dart:322` | 其它 | 自由答复引用块手搓:左 BorderSide 用 AnSize.ring(强调环描边 token)当引用线宽,语义误用 | 造/复用 blockquote 原语,ring 归位 | S | done·批9b(引用块左条 ring 误用→AnSize.quoteBar 新档,色归 lineStrong;与编辑器/markdown 三处统一) |
| A-102 | `lib/features/settings/ui/settings_ocean.dart:31` | 其它 | 浮层头折叠阈值 _collapseAt=64 私定,documents ocean 同角色用 120,每海洋自铸 | 折叠阈值收进共享常量/由 AnPage 提供 | S | done·批9a(settings_ocean _collapseAt 私值→实测头高,同 entity/document) |
| A-103 | `lib/core/editor/an_editor_components.dart:222` | 其它 | 编辑器引用块左条(BorderSide width:2 裸数字+lineStrong)与 an_markdown.dart:355 只读引用条是同一视觉规则的两处手写实现 | 立 quote-bar 宽 token+共享条壳,编辑/只读同源 | S | done·批9b(编辑器引用条 width 2→AnSize.quoteBar,markdown gripLine→quoteBar,三处一档) |
| A-104 | `lib/core/editor/an_editor_mention.dart:82` | 其它 | caret 锚定弹层的翻转落点几何(estimate 高→层高比较→above/below 翻转)在 mention(:67-89)与 slash(an_editor_slash_menu.dart:142-169)重复两份,且两者宽档不同(232/320 vs 208/268);toolbar 还有第三套翻转变体(:127) | 抽一个共享 caret-anchored 弹层落点 helper+统一宽档 | M | done·批9f(caret 弹层翻转几何[mention:82-88/slash:160-166 逐字重复]抽 AnMenuSurface.caretPlacement 纯静态[anchor+rows+layerHeight→left/top,内部 estHeight+下挂/翻上];纯几何不碰 overlay 时序[高危区安全];box/layerHeight 读留调用点;宽档批7 B-019/020 已统一;+3 几何电池) |
| A-105 | `lib/core/editor/an_editor_toolbar.dart:328` | 其它 | _LinkInputBar 用裸 Material TextField+InputDecoration 做 URL 输入,绕开 AnInput 当家输入件 | 换 AnInput(或其 bare/inline 变体) | S | done·批9a(_LinkInputBar 裸 TextField→AnInput.seamless,Esc 键盘监听保留) |
| A-106 | `lib/core/editor/an_editor_toolbar.dart:351` | 其它 | _FormatButton 手搓图标开关钮(AnimatedContainer+BoxDecoration+active 态),AnButton.iconOnly 无 toggle 态所以现场造 | 给 AnButton 长 active/toggle 态,格式钮改用(强化地基非模块重抄) | S | done·批9b(AnButton 长 toggled 态[accent 字形+accentSoft 底+a11y toggled+MergeSemantics 修双节点],_FormatButton 退役;5 格式钮改用+补 a11y 键) |
| A-107 | `lib/core/ui/an_copy_chip.dart:44` | 其它 | an_copy_chip:44/an_path_chip:52/an_code_editor:338 用裸 Material Tooltip(默认黑皮),an_cast_row:176 用 AnTooltip——同库两种提示条皮 | 三处换 AnTooltip | S | done·批9a(run_ledger/gate Tooltip→AnTooltip;path_chip/code_editor 早已 AnTooltip) |
| A-108 | `lib/dev/gallery/catalog.dart:1157` | 其它 | _GridCell 演示块手搓有边容器(Container+Border.all+chip 圆角) | 换 AnCard/AnSunkenPanel 演示 | S | done·批9a(gallery _GridCell→AnCard) |
| A-109 | `lib/dev/gallery/gallery_app.dart:229` | 其它 | _cell specimen 卡手搓(Container+Border.all+AnRadius.chip+surface),即 AnCard 的职责 | 换 AnCard(或注记 gallery 壳豁免) | S | done·批9a(gallery _cell→AnCard) |
| A-110 | `lib/features/chat/ui/run_ledger.dart:58` | 其它 | 珠串用原生 Material Tooltip(waitDuration 手配),全 App 其余用 AnTooltip | 换 AnTooltip | S | done·批9a(珠串 Material Tooltip→AnTooltip) |
| A-111 | `lib/features/chat/ui/stages/attachment_pedestal.dart:35` | 其它 | 缩略图手搓 ClipRRect+Image+裸 maxHeight:180(私铸档,thumbMaxH=240 已存在),绕开 AnAttachmentThumb | 复用 AnAttachmentThumb/thumbMaxH token | S | done·批9a(attachment_pedestal 手搓缩略图→AnAttachmentThumb.single,私铸 180 退役) |
| A-112 | `lib/features/chat/ui/tool_card_skins.dart:181` | 其它 | 内容封顶常数散置无档:6000 ×4(skins:181/404、mount:73、exec:283)+8192(dossier:180)+4000(chat_tool_card:57) | 收敛为具名显示预算常量组 | S | done·批9a(封顶散数收 AnCap.receiptTail/stderrTail/logHead/logTail+AnCap.window) |
| A-113 | `lib/features/documents/ui/an_document_editor.dart:174` | 其它 | _header 手搓文档页头(crumb Text+AnInlineEdit 标题+描述+AnTags),与 AnOceanHeader(crumb+大标题+meta)同角色两种做法;元件是原语但排布文法现场发明 | 给 AnOceanHeader 长 reading 变体(描述/tags 槽)或立文档头原语进 gallery | M | open |
| A-114 | `lib/features/notifications/ui/notification_feed.dart:178` | 其它 | _Header 的「全部已读」文字链用 AnInteractive+Text+accent/accentHover 手搓,绕开按钮原语 | 换 AnButton ghost/sm 或立文字链 variant | S | done·批9a(notification 全部已读 手搓文字链→AnButton ghost/sm;可见变化记档) |
| A-115 | `lib/features/notifications/ui/notification_feed.dart:194` | 其它 | _SectionLabel 手搓分组小标(Padding+meta+emphasis 墨),与 AnGroupLabel 单源职责完全重合 | 删 _SectionLabel 换 AnGroupLabel(padding 可覆) | S | 证伪·批9a(notification 早用 AnGroupLabel,_SectionLabel 已不存在) |
| A-116 | `lib/features/chat/ui/tool_card_memory_web.dart:463` | 活尾 | (批1 复审补录)WebFetch 活蒸馏手搓 Align(bottomLeft)+钳=段落钉头,最新字不可见——正是族头修的 HIGH 同病 | 换 AnLiveTail prose | S | **done·批1** |
| A-117 | `lib/core/ui/an_term_viewport.dart` | 活尾 | (批1 复审补录)AnTermViewport 渐隐色写死灰井,白宿主发灰 | 增 fadeColor 透传 | S | **done·批1** |

## B 规范科学化台账(75 条,按域分组)

| # | 位置 | 域 | 问题 | 修法 | 量 | 状态 |
|---|---|---|---|---|---|---|
| B-001 | `lib/features/chat/ui/tool_card_document_skill.dart:19` | 窗 | collapsedHeight 默认 340 裸数字视觉高度,无尺寸档 | 收进 AnSize 折叠高档位 | S | 证伪·批7(前批已修,scout 现场核实) |
| B-002 | `lib/features/entities/ui/detail/overview/function_overview.dart:38` | 代码 | 收合高度 feature 层算术:_maxCollapsedLines(50)× codeReading.fontSize × height + chromeHeight——AnFadeCollapse 只收 double 高度,缺行数 API 逼出补偿 | AnFadeCollapse/AnCodeEditor 长 collapsedLines 参数,feature 不算高度 | M | **done·批2**(AnCodeEditor.collapsedHeightFor(lines,reading) 几何口+chromeHeight 降私有;几何锁死有测;features 零字体算术[rg 归零]) |
| B-003 | `lib/features/chat/ui/chat_thinking.dart:170` | 间距 | token 裸算术 ×2:缩进 AnSize.dot+AnSpace.s6(170)/rail 定位 dot/2-hairline/2(181) | 定 rail 缩进/对轴语义 token | S | done·批7b |
| B-004 | `lib/features/chat/ui/tool_card_control_approval.dart:105` | 间距 | emit 行悬挂缩进用 AnSize.icon(图标尺寸 token)当左 padding,尺寸档挪作间距 | 定悬挂缩进语义 token 并成文对齐文法 | S | done·批7b |
| B-005 | `lib/features/chat/ui/tool_card_ecosystem.dart:189` | 间距 | 描述行悬挂缩进 EdgeInsets.only(left: AnSize.iconSm+AnSpace.s6) token 裸算术 | 定悬挂缩进语义 token | S | 证伪·批7(前批已修,scout 现场核实) |
| B-006 | `lib/features/chat/ui/tool_card_entity_get_bodies.dart:136` | 间距 | 徽章行 Wrap 间距三样并存:inline+s4(此处/ecosystem 85)/inline+s2(trigger 103/control 108)/s6+s4(ecosystem 143) | 定徽章行 Wrap 文法一档,或造 badge-row 件 | S | done·批7b |
| B-007 | `lib/features/chat/ui/tool_card_search.dart:101` | 间距 | 尾徽章排 Padding(left: 4) 裸数字,conversation.dart:122 同位用 AnSpace.s4 | 换 AnSpace.s4 | S | done·批7b |
| B-008 | `lib/features/entities/ui/entity_ocean.dart:54` | 间距 | 浮层头折叠阈值裸数字:种子 _threshold = 64,行 144-147 clamp(8.0, 600.0) 三个裸几何值 | 种子用 AnSize.islandHead 派生,clamp 界限入 token 或具名常量 | S | done·批7b |
| B-009 | `lib/features/entities/ui/run/run_terminal.dart:68` | 间距 | 贴底判定裸数字 (maxScrollExtent - pixels) < 32,滚动 stick 阈值现场发明 | 阈值入具名常量/token,与 chat 贴底判定共享 | S (复审记档:chat _pinSlack=48 刻意不共享——泡列几何不同) |
| B-010 | `lib/features/settings/ui/panels/chat_panel.dart:53` | 间距 | 控件槽裸宽 300/260/240 ×3(53/75/103),同面板三行三个宽 | 统一走控件宽 token 档 | S | done·批7b |
| B-011 | `lib/features/settings/ui/panels/general_panel.dart:51` | 间距 | 控件槽 SizedBox 裸宽 280/200/320 ×3(51/80/195),无控件宽度档 | 定控件宽 token 档(segmented/dropdown) | S | done·批7b |
| B-012 | `lib/features/settings/ui/panels/mcp_forms.dart:89` | 间距 | maxWidth 560/640/560(89/200/342)+ transport 槽 width 380 裸数 ×4 | 表单宽收敛成 token 档 | S | done·批7b |
| B-013 | `lib/features/settings/ui/panels/mcp_panel.dart:238` | 间距 | tab 区 SizedBox(height:480) + stderr maxHeight 360(343)裸数;与 sandbox tab 区 360 不一 | 定 tab 面板高度档,两面板对齐 | S (复审补记:stderr 视口 360→320 −40 可见) |
| B-014 | `lib/features/settings/ui/panels/memory_panel.dart:66` | 间距 | 过滤 segmented width 200 + 编辑器 maxWidth 640(264)裸数 ×2 | 走控件/表单宽 token 档 | S | done·批7b |
| B-015 | `lib/features/settings/ui/panels/models_keys_panel.dart:401` | 间距 | 表单 maxWidth 480 + 场景下拉 width 320 ×2(510/574)裸数 | 表单宽/控件宽走 token 档 | S | done·批7b |
| B-016 | `lib/features/settings/ui/panels/network_panel.dart:81` | 间距 | 推入表单 maxWidth 三种:480(network/ws/keys/sandbox)/560(mcp)/640(memory/import) | 定一档表单阅读宽,全 settings 对齐 | S (复审补落:network/ws ×3 锚点站补迁 formMaxWidth) |
| B-017 | `lib/features/settings/ui/panels/notifications_panel.dart:47` | 间距 | 级别 segmented 槽 SizedBox(width:280) 裸数 | 改控件宽 token 档 | S | done·批7b |
| B-018 | `lib/features/settings/ui/panels/sandbox_panel.dart:112` | 间距 | env tab 区 height 360 + 磁盘槽 240(62)+ GC 输入 90(355)+ maxWidth 480(188)裸数 ×4 | 尺寸全走 token 档 | S | done·批7b |
| B-019 | `lib/core/editor/an_editor_mention.dart:103` | 间距 | @ 提及弹层 BoxConstraints minWidth:232/maxWidth:320 私铸宽档;:82 同款行高估算裸算术 | 与 slash 弹层共用同一 popover 宽档 token | S | done·批7b |
| B-020 | `lib/core/editor/an_editor_slash_menu.dart:210` | 间距 | slash 弹层 BoxConstraints minWidth:208/maxWidth:268 私铸宽档(AnSize 仅有 menuMaxHeight/menuMaxWidth);:159 行高估算 count*AnSize.row+AnSpace.s8 裸算术 | 弹层宽档入 AnSize token | S | done·批7b |
| B-021 | `lib/core/editor/an_editor_stylesheet.dart:103` | 间距 | token 裸算术私铸间距档 ×3:AnSpace.s24+s4=28(:103)、s16+s4=20(:117)、s24*3=72(:201) | 入 AnFlow/AnSpace 语义档(标题上距/文档尾余量) | S | open·签字(AnFlow.headingTop/subheadingTop 死 token+编辑器 28/24/20 梯+AnMarkdown≈24 三方分裂;统一=编辑器标题节奏可见变化,交用户拍板) |
| B-022 | `lib/core/editor/an_editor_stylesheet.dart:94` | 间距 | Styles.maxWidth 裸写 720.0,不用 AnSize.content(=720);且实际阅读文列是 672(an_document_editor _measure),独立宿主下编辑器文宽与各海洋分叉 | 改 AnSize.content 引用并核对是否该对齐 672 文列 | S | done·批7b |
| B-023 | `lib/core/editor/an_editor_toolbar.dart:316` | 间距 | URL 输入条 width:280 私铸宽档;:48 _barHeight=AnSize.row+AnSpace.s4*2 token 裸算术估高 | 宽入 AnSize 档;条高由原语自报而非估算 | S | done·批7b |
| B-024 | `lib/core/ui/an_cel_grow.dart:79` | 间距 | 裸 EdgeInsets 数字散点:cel_grow h:1 margin+v:1 padding、segmented:60 all(2)、switch:56 all(2)、scope_badge:45 v:1——AnSpace.s2 在手不用 | 统一换 AnSpace.s2/立 1px 微调档 | S | done·批7b |
| B-025 | `lib/features/chat/ui/chat_toc.dart:114` | 间距 | 场次条面板 BoxConstraints(maxHeight:560,maxWidth:340,minWidth:280) 三个裸数,私铸浮层尺寸档(menuMaxWidth=360 旁另立 340) | 入 AnSize 语义轴(tocPanel 专号) | S | done·批7b |
| B-026 | `lib/features/chat/ui/chat_tool_card.dart:146` | 间距 | 体左缩进 AnSize.icon+AnSpace.s6 裸算术 ×2(146/185)——token 算术私铸档位 | 派生缩进封进语义 token 或行族 API | S | done·批7b |
| B-027 | `lib/features/chat/ui/stages/document_stage.dart:119` | 间距 | 裸视口高 ×2:活窗 height:220(:119)、失败卷 maxHeight:260(:137),私铸档(jsonViewport=240 旁另立两号) | 视口高入 AnSize 语义轴 | S | 证伪·批7(前批已修,scout 现场核实) |
| B-028 | `lib/features/chat/ui/tool_card_memory_web.dart:465` | 间距 | maxHeight:144 魔数视口高(注释≈6 行),私铸尺寸档(同角色 AnSize.jsonViewport 已有先例) | 进 AnSize 视口档 | S | 证伪·批7(前批已修,scout 现场核实) |
| B-029 | `lib/features/chat/ui/tool_card_workflow.dart:90` | 间距 | _graphHeight=200 私铸卡内图高常数 | 进 AnSize 档(与 jsonViewport 同列) | S | done·批7b |
| B-030 | `lib/features/documents/ui/an_document_editor.dart:72` | 间距 | _activeBand=72 私铸活动带阈值;:147 AnSpace.s24*2 裸算术;:113 target-AnSpace.s16 现场减法 | 几何阈值入语义常量/token,算术收进原语 | S (复审补记:活动带 72→64 −8px 行为变化,帧供否决) |
| B-031 | `lib/features/documents/ui/document_ocean.dart:76` | 间距 | _collapseAt=120 私铸浮层头折叠阈值(注释称=头高,实为拍脑袋数,头高本可实测) | 用 _headerKey 实测头高替代魔数,或入 token | S | done·批7b |
| B-032 | `lib/features/notifications/ui/notification_row.dart:73` | 间距 | EdgeInsets.only(top: 1) 裸 1px 光学微调 ×2 处(73/133),an_setting_row.dart:104 同款——无光学微调档 | 立 opticalNudge 档或统一进行原语 | S (复审补记:an_setting_row=inlineHair 1→2 +1px 可见,分诊正确) |
| B-033 | `lib/features/settings/ui/panels/workspaces_panel.dart:41` | 色调 | kWorkspaceColors 6 枚私铸 hex + parseWorkspaceColor 裸 Color(0xFF…) 构造(126)在 feature 层 | 色盘挪 core design token/常量层 | S | 证伪·批7(前批已修,scout 现场核实) |
| B-034 | `lib/core/ui/an_segmented.dart:108` | 色调 | withValues 私调透明:segmented 0.5 禁用暗化(≠AnOpacity.disabled 0.4)×2 处、an_switch:59 hover 0.9、an_type_to_confirm:66 边框 0.35——皆绕 AnOpacity 档 | 对齐/扩 AnOpacity 档,删私值 | S | done·批7c |
| B-035 | `lib/core/ui/an_toast.dart:141` | 色调 | an_toast 私设 AnToastTone{neutral,ok,warn,danger} 并自写 tone→色 switch,tone.dart 宣称唯一映射源且命名对不上(neutral vs AnTone.none) | AnToastTone 删掉,直接吃 AnTone+AnToneColors | S | done·批7c |
| B-036 | `lib/features/chat/ui/chat_turn.dart:41` | 色调 | _sendingOpacity=0.55 私铸整件透明档,AnOpacity 无此档(disabled=0.4/stratum=0.4) | 入 AnOpacity.sending 或复用 disabled | S | done·批7c |
| B-037 | `lib/features/chat/ui/run_ledger.dart:22` | 色调 | runStatusColor 平行「状态→色」映射,与 AnStatus.fromRaw().tone 双系统并存(同族 _RunFooter 用 AnStatus、珠串/台账用它) | 统一进 AnStatus,删平行映射 | M | done·批7c |
| B-038 | `lib/features/chat/ui/run_ledger.dart:22` | 色调 | runStatusColor 本地维护 status→色映射,与 run_dossier.dart:93 走的 AnStatus.fromRaw().tone 平行两套语义色系统 | 统一进 AnStatus.fromRaw,删本地映射 | M | done·批7c |
| B-039 | `lib/features/chat/ui/stages/control_stage.dart:109` | 色调 | 「透传」幽灵墨 inkFaint.withValues(alpha: a*0.7) 私调透明系数 | 定 ghost 档入 AnOpacity 或用 inkFaint 直渲 | S | done·批7c |
| B-040 | `lib/features/chat/ui/stages/workflow_stage.dart:60` | 色调 | R-5 旧真相地层用裸 opacity 0.55,同角色 agent/control 舞台用 AnOpacity.stratum(0.4)——同语义两透明度;:61 framedHeight:190 裸数(graphPreview=380 旁私铸) | 统一 AnOpacity.stratum;190 入 AnSize | S | done·批7c |
| B-041 | `lib/features/notifications/ui/notification_row.dart:141` | 色调 | _toneColor 本地重推 tone→色(NotificationTone 三分支×unread),tone.dart 自称唯一 tone→色处被绕开 | NotificationTone 映射 AnTone,走 AnToneColors | S | done·批7c |
| B-042 | `lib/features/chat/ui/tool_interaction_gate.dart:160` | 圆角 | Border.all 未给 width(默认 1.0 逻辑像素),他处描边一律 AnSize.hairline | 补 width: AnSize.hairline 或按边框档选档 | S | done·批7c |
| B-043 | `lib/core/ui/an_code_surface.dart:43` | 圆角 | framed 容器圆角分裂:AnCodeSurface 用 AnRadius.card,AnCard/AnMenuSurface/AnSunkenPanel/AnIsland 皆 chip,AnTooltip 面又用 button——同族面三档圆角无选档规则 | P2 成文圆角选档规则,窗族归一 | M | done·批7(法典增补拍板记档:五档=尺度阶梯成文;唯一真出格 models_keys freeTier 手搓卡→AnCard[16→12 帧核];同心嵌套=内半径+内缩距唯一合法算术) |
| B-044 | `lib/features/settings/ui/panels/memory_panel.dart:122` | 图标 | 金 pin 行内开关裸 GestureDetector+Icon,无 hover/焦点态、点击域仅图标 | 用/新增 icon-button 原语(带命中域+焦点态) | S | 证伪·批7(前批已修,scout 现场核实) |
| B-045 | `lib/core/editor/an_editor_components.dart:162` | 图标 | 任务勾字形规则(done→taskDone/ok,open→taskOpen/inkFaint,AnSize.icon)在编辑器组件与 an_markdown.dart:313 两处各写一遍 | 抽共享 AnTaskGlyph 微件,两处消费 | S | done·批7复审(AnIcons.task 单源字形对) |
| B-046 | `lib/core/ui/an_cast_row.dart:119` | 图标 | 微尺寸减法私铸成风:AnSize.dot-2 ×3 文件(cast_row:119/channel_strip:89/follow_pill:115)、iconSm-2 ×3(follow_pill:127/honesty_ribbon:52/rundown_list:122)、iconSm-4(cast_row:152)、dot+2/iconSm+2(rundown_list:129/97)、hairline*1.5(mini_graph:333) | 立 dotSm/iconXs 档,全库替换禁减法 | M | done·批7c |
| B-047 | `lib/features/chat/ui/stages/handler_stage.dart:143` | 图标 | 用文本字形当图标:'⏱ '(:143)与流式波浪 '~'(:139),绕开 AnIcons 精确表 | 换 AnIcons 对应字形 | S | done·批7c |
| B-048 | `lib/features/chat/ui/stages/skill_memory_mcp_stage.dart:210` | 图标 | AnSize.iconSm - 4 裸算术(=私铸 8px 图标档,战役原文案例);:87 AnFadeCollapse collapsedHeight:320 裸数 | 补 iconXs 档;折叠高入 AnSize | S | 证伪·批7(前批已修,scout 现场核实) |
| B-049 | `lib/features/chat/ui/chat_thinking.dart:55` | 动效 | _fadeLineFraction 0.55 裸视觉常量(边缘渐隐高度比) | 入 token 或 AnEdgeFade 默认值 | S | 证伪·批7(前批已修,scout 现场核实) |
| B-050 | `lib/features/chat/ui/tool_hit_list.dart:106` | 动效 | 级联动效裸值 ×3:stagger 30ms(106)/总长上限 3000ms(120)/升距 4px(184),均不在 AnMotion 档 | 收进 AnMotion 档位(stagger/上限/升距) | S | done·批7d |
| B-051 | `lib/features/entities/ui/detail/workflow_editor_page.dart:329` | 动效 | AnimatedContainer 用裸 Curves.easeOutCubic,而 AnMotion.easeOut 曲线档存在且同文件他处(entity_ocean:75)已用,曲线值还不同 | 换 AnMotion.easeOut | S | done·批7d |
| B-052 | `lib/features/entities/ui/entity_rail.dart:35` | 动效 | 搜索防抖裸 Duration(250ms);与 chat rail 同值但全仓防抖时长(150/250/500/600)无档位,各处现场发明 | 防抖时长入 AnMotion 档(如 searchDebounce),全仓统一 | S | done·批7d |
| B-053 | `lib/core/ui/an_code_editor.dart:186` | 动效 | 裸 Duration:copy-✓ 复位 1200ms(同手势 AnCopyChip/AnPathChip 用 AnMotion.dwell 600ms,一个动作两种速度)、tooltip 500ms、graph_canvas comet 1100ms、toast 4s | copy 复位收单一 AnMotion 档,余者入令牌 | S | done·批7d |
| B-054 | `lib/core/ui/an_state.dart:77` | 动效 | reduced-motion 双闸门混用:an_skeleton/an_shimmer_text 用 reducedOrAssistive,an_state/breadcrumb 等用 reduced(例证 an_live_code_window 已于批2 删除)——何时用哪档无成文规则 | B 轨成文:装饰循环用 orAssistive,过渡用 reduced | S | done·批7d |
| B-055 | `lib/features/chat/ui/chat_composer.dart:77` | 动效 | 裸 Duration 防抖:composer 150ms 与 conversation_rail.dart:51 250ms,同角色(搜索防抖)两个私值 | 防抖档入 AnMotion(或 core Debouncer 默认档) | S | done·批7d |
| B-056 | `lib/features/chat/ui/chat_ocean.dart:162` | 动效 | _FadeRiseIn 私有入场动效件(淡入+6px 上移)在 feature 层手搓,不进 gallery 不受审 | 抽 AnEntranceReveal 类原语入 core/ui | S | done·批7a |
| B-057 | `lib/features/chat/ui/chat_transcript.dart:360` | 动效 | 跳转洗亮:裸 Duration 2200ms ×2(:172/:360)不在 AnMotion;:357 直读 MediaQuery.disableAnimationsOf(tokens.dart 明令禁止,应走 AnMotionPref) | 洗亮时长入 AnMotion,改用 AnMotionPref.reduced | S | done·批7d |
| B-058 | `lib/features/documents/ui/document_ocean.dart:138` | 动效 | 同角色自动存防抖两档:正文/skill 存 600ms(:138,:239)vs 右岛 frontmatter 存 500ms(documents_inspector.dart:305),裸 Duration 各写各 | 统一 autosave 防抖档为一常量 | S | done·批7d |
| B-059 | `lib/features/notifications/state/toast_dispatcher.dart:91` | 动效 | 裸 Duration(seconds: 8) 定 toast 时长,与 an_toast 的 anToastDefaultDuration(4s) 并存两处私铸 | toast 时长档收进 AnMotion/toast 令牌 | S | done·批7d |
| B-060 | `lib/features/chat/ui/tool_card_document_skill.dart:96` | 状态 | document 软失败手搓 Row(Icon.info+warn 文本),同族 read_document/attachment 软失败用 AnCallout(warn) | 统一 AnCallout(severity: warn) | S | done·批7d |
| B-061 | `lib/features/entities/ui/detail/log_tab.dart:41` | 状态 | 错误态重试按钮文案两派:log_tab:41/trigger_observability_tab:146/run_cockpit_tab:62/entity_ocean:128 误用 state.loadMore('Load more'),version_tab:46/flowrun_inbox:71 才用 retry | 错误态动作统一 d.state.retry,×4 处改键 | S | done·批7d |
| B-062 | `lib/features/entities/ui/run/run_terminal.dart:343` | 状态 | _hint 手搓灰字空态(noTrace 等),而本 feature 自述的唯一空态惯用法是 AnState inset(insetEmpty) | 换 insetEmpty/AnState inset,或成文豁免流式面轻空态 | S | done·批7d |
| B-063 | `lib/features/settings/ui/panels/about_panel.dart:26` | 状态 | 版本值 '…' 兜底当 loading ×2(26/27),手搓状态非 AnState/skeleton | 换 AnSkeleton 或显式 loading 态 | S | done·批7d |
| B-064 | `lib/features/settings/ui/panels/chat_panel.dart:130` | 状态 | 行内错误用 AnText.meta+danger,其余表单错误用 AnText.label+danger(models_keys:461 注释自证) | 定一种行内错误行文法(或 AnState) | S | done·批7d |
| B-065 | `lib/features/settings/ui/panels/limits_panel.dart:105` | 状态 | loading 手搓 Text('…')(105)+ 错误裸 Text(102)非 AnState;输入槽 width 140 裸数(197) | 换 AnState(loading/error);宽走档 | S | done·批7d |
| B-066 | `lib/features/settings/ui/panels/mcp_forms.dart:353` | 状态 | :plan loading 与市场空结果手搓 Text(353/279)非 AnState ×2 | 换 AnState(loading/empty, inset) | S | done·批7d |
| B-067 | `lib/features/settings/ui/panels/mcp_panel.dart:273` | 状态 | tools/calls/stderr 三 tab 空态手搓 Text ×3(273/303/336),名册却用 AnState | 换 AnState(empty, inset) | S | done·批7d |
| B-068 | `lib/features/settings/ui/panels/sandbox_panel.dart:181` | 状态 | '…' Text 当 loading(181)+ AnMeter '…' 兜底(64)+ noEnvs 空态手搓(278)×3 | 换 AnState/AnSkeleton,禁 '…' 哨兵 | S | done·批7d |
| B-069 | `lib/features/settings/ui/panels/storage_panel.dart:31` | 状态 | '…' 哨兵串当 loading 且用 dir=='…' 判可用(31/52/58/71/159)+ width 240 裸数(67) | AsyncValue 显式判 loading,禁哨兵串 | M (复审补落:width 240→ctlSlot) |
| B-070 | `lib/features/chat/ui/chat_ocean.dart:93` | 状态 | _DropOverlay 手搓拖放面纱(ColoredBox+icon+text),surface.withValues(alpha:0.85) 私铸透明档 | 抽 drop-veil 原语进 gallery,alpha 入 AnOpacity | S | done·批7a |
| B-071 | `lib/features/chat/ui/chat_transcript.dart:277` | 状态 | 手搓 loading:SizedBox(icon)+CircularProgressIndicator.adaptive(strokeWidth:2),chat_toc.dart:138 同型 ×2 | 抽 AnState/loader 原语统一小型加载点 | S | done·批7a |
| B-072 | `lib/features/chat/ui/tool_card_skins.dart:528` | 状态 | decideApprovalBody NOT_PARKED 提示行手搓(warn Icon+Text Row),该用 AnState/note 类原语 | 换共享 note/callout 原语 | S | done·批7d |
| B-073 | `lib/features/notifications/ui/notification_feed.dart:79` | 状态 | feed 首屏 loading/error/empty/list 四态在 async.when 里手拼(AnDeferredLoading+AnRailSkeleton+AnState 逐个摆),AnRailStates 正是为此而生 | 换 AnRailStates(strings+onRetry+builder) | S | done·批7d |
| B-074 | `lib/features/chat/ui/run_dossier.dart:33` | i18n | status→本地化词 switch 手搓 ×4(dossier:35/123、flowrun:154、exec:202),同一映射四处重复 | 收进共享 statusWord helper(挂 AnStatus) | S | done·批7d |
| B-075 | `lib/features/notifications/ui/notification_row.dart:101` | i18n | 宾语名两侧「」全角引号硬编码进 TextSpan,英文 locale 下同样渲 CJK 引号 | 引号入 slang 键随 locale | S | done·批7d |

## C 性能嫌疑台账(43 条;**嫌疑非定罪**,P5 测量后转正式/赦免)

| # | 位置 | 危 | 嫌疑 | 机制 | 受害场景 | 状态 |
|---|---|---|---|---|---|---|
| C-001 | `lib/core/editor/an_editor.dart:224` | high | 每键 markdownFromDocument 序列化整篇文档 | _onDocumentChanged 同步在 document listener 里全文序列化,只有『存』防抖、序列化本身不防抖;大文档打字=每键 O(doc) 主线程 | 编辑器打字 | open |
| C-002 | `lib/core/ui/an_markdown.dart:119` | high | GptMarkdown 每 tick 全量重解析流式 markdown,无任何增量/记忆化 | live text 块逐 tick 换更长串→整段正则解析+span 重生成,O(n)/帧→全程 O(n²);且开回合内已闭合的 text 块也一并重解析(粒度=整回合) | 流式 | open |
| C-003 | `lib/features/chat/model/stage_director.dart:305` | high | 并行工具流式时非主角 unread++ 每 delta 破坏 StageState 值相等 | StageActivityView.== 含 unread(:114);channel 每 delta unread++ → updateShouldNotify 过 → _AccordionList(watch :347)整列表每帧全重建+_computeRows 重跑 | 手风琴 | open |
| C-004 | `lib/features/chat/ui/chat_thinking.dart:206` | high | 流式 thinking 每 tick 用 TextPainter 全文 layout 测高,再由 ScrollView 二次全文 layout | _scrollWindow 每 build 建 TextPainter.layout(全文)只为判溢出;窗只显 5 行却双份整段落 shaping,reasoning 长文时每帧两次 O(全文) 排版 | 流式 | **done·批1**(两半皆灭:TextPainter 探针删除+族头 O(tail) 切尾[复审抓获只杀一半后补];P5 场景套件复测钉预算) |
| C-005 | `lib/features/chat/ui/chat_tool_card.dart:168` | high | spec.receipt 每 build 重算,内部 jsonDecode(resultText) 无记忆化 | tool_receipts.dart:249 _obj / tool_card_workflow.dart:33 等逐 build 全量 jsonDecode 结果 JSON;开回合内的已落定卡每 tick 重建→每帧 N 次 KB~百KB 级 decode | 流式 | open |
| C-006 | `lib/features/chat/ui/chat_tool_card.dart:210` | high | 收起卡体每帧陪跑构建:spec.body 函数在 open=false 时也全量执行 | 族体是函数非 widget 类,bashToolBody/decideApprovalBody/subagentBody 等在函数内立即做正则/jsonDecode/argStringPartial;live 回合内每张卡逐 tick 重建,N 张收起卡×每帧全量体构建 | 流式 | open |
| C-007 | `lib/features/chat/ui/stages/scene_from_truth.dart:259` | high | StageBodyFromTruth 每次 rebuild 全量 jsonEncode 真身+全量重 parse | sceneFromTruth 每次造全新 BlockNode,故意绕开 revision memo;ToolCardState.of→argsSessionOf 整段 JSON 重扫。展开的 workflow/doc/fn 行在手风琴每帧重建时按 O(内容) 重付 | 手风琴 | open |
| C-008 | `lib/features/documents/ui/document_ocean.dart:110` | high | feedOutlineOnEdit 每键 extractDocOutline 全文重扫+provider set | 每次编辑同步 split('\n')+逐行 regex O(doc) 再 set docOutlineProvider(新 List 必 notify)→右岛大纲每键重建;与 #3 叠加成每键双份 O(doc) | 编辑器打字 | open |
| C-009 | `lib/app/app_shell.dart:209` | med | 海洋切换=ternary 整树 remount,autoDispose 级联拆装 | 切走即 dispose 该海洋全部 autoDispose provider(transcript/树/truth 缓存全丢),切回全量重 fetch+重建;documents 回来还要整篇 markdown 重 parse 重挂编辑器 | 切海洋 | open |
| C-010 | `lib/core/editor/an_editor.dart:398` | med | AnEditor 每 build 造新 Stylesheet+componentBuilders/keyboardActions/overlay 列表 | slash/@ 菜单每次 setState(方向键导航)与 LayoutBuilder resize 都重建 AnEditor → SuperEditor 收到全新 stylesheet 实例,可能全文档重跑 style pipeline | 编辑器打字 | open |
| C-011 | `lib/core/editor/an_editor_syntax.dart:40` | med | style 过每次对每个代码块 toPlainText+copy+重挂 attribution(即使 token 缓存命中) | 分词已 memo,但 vm.text.toPlainText() O(len) 与 colored copy+addAttribution 每个 style pass(每键/каret/选区变化)都重跑,大代码块多时每键 O(代码总量) | 编辑器打字 | open |
| C-012 | `lib/core/ui/an_code_editor.dart:262` | med | highlightCode 每 build 全量重 tokenize,无 memo(262/380 两处) | markdown 围栏码块与展开的 Write/builds 落定卡在 live 回合内每 tick 重建→整文件逐帧重高亮;大文件时是重 CPU 项 | 流式 | open |
| C-013 | `lib/core/ui/an_code_editor.dart:262` | med | AnCodeEditor 每 build 全量 highlightCode 重新分词,无记忆化 | 自身文档承认 full re-highlightCode(:35);侧幕展开的 fn/handler 舞台行随手风琴每帧重建 → 整段代码每帧重 tokenize;settled 工具卡随 1s ticker 也每秒重跑 | 手风琴 | open |
| C-014 | `lib/core/ui/an_code_editor.dart:445` | med | _HighlightController.buildTextSpan 每次文本/选区变化全量重高亮 | 编辑态每击键(乃至选区移动)整文件重 tokenize 无缓存,大文件编辑击键延迟线性放大 | 编辑器打字 | open |
| C-015 | `lib/core/ui/an_graph_canvas.dart:1219` | med | _CometPainter 每动画 tick 重建 rounded Path+computeMetrics | 60fps × 每条 live 边:_rounded 折线+quadratic 重算 + PathMetrics native 对象重造,无 per-route 缓存;RepaintBoundary 只隔离了重绘范围,没省计算 | 图渲染 | open |
| C-016 | `lib/core/ui/an_graph_canvas.dart:567` | med | 节点/连接拖拽与 hover 走画布级 setState,整场景全量重建 | _updateNodeDrag/_updateConnect 每 pointer-move setState → _scene 全部节点卡/端口药丸 widget 重建;onHoverChange(:476) 进出节点也全场 setState | 图渲染 | open |
| C-017 | `lib/core/ui/an_status_dot.dart:49` | med | 每个 run 点一只 AnimationController.repeat,且无 RepaintBoundary | 未接 PulseClock 共享钟;呼吸环逐帧脏到最近祖先边界=整条回合行/手风琴行 60fps 重绘,工具静默运行期(无 token)也持续 | 流式 | open |
| C-018 | `lib/features/chat/model/tool_receipts.dart:420` | med | argStringPartial/argString 每 build O(argsText) 重扫(target/命令/prompt 提取) | spec.target 与多族体逐 build 调用;键不存在或值在尾部时 indexOf+逐字符扫全片段,MB 级 args(Write content)下每帧 O(MB) | 流式 | open |
| C-019 | `lib/features/chat/state/flowrun_progress.dart:36` | med | 非 autoDispose family + ticks 列表每 tick 全量拷贝无上限 | withTick 造 [...ticks,t] O(n) → 长 run O(n²) alloc;UI 只显末 12 行但列表全留,provider 声明为 app 生命周期,poll 块越多驻留越多 | 流式 | open |
| C-020 | `lib/features/chat/state/stage_director_provider.dart:167` | med | _publish 每个 FrameDelta 执行:Timer cancel+新建 + StageState 全量重造 | _onFrame 对每 delta 调 _publish→_schedule 换闹钟 + state getter 为每个 live 活动 alloc StageActivityView;数百次/秒,不走 coalescer | 流式 | open |
| C-021 | `lib/features/chat/state/touchpoint_ledger.dart:185` | med | 每条 durable touchpoint 信号全 map 拷贝+全量 aggregate 重算重排 | _onFrame→_emit→aggregate(rows.values) O(N log N)+字符串键拼接;工具密集回合每次落账都重付,且随台账翻页增长;每次还连带手风琴整列表重建 | 手风琴 | open |
| C-022 | `lib/features/chat/ui/chat_tool_card.dart:122` | med | 每张 live 卡一个 1s Timer.periodic setState 重建整卡 | N 个并行 live 卡=N 次/秒整卡重建,展开体内 jsonDecode/argString 全量重跑;convergence 已点名的『常驻 Timer 群』形态 | 流式 | open |
| C-023 | `lib/features/chat/ui/chat_transcript.dart:336` | med | 流式重建粒度=整个开回合:回合内全部块逐 tick 重建 | _rowFor 对 isOpen 回合每 tick 造新 _TurnRow,其下所有已落定 tool 卡/text 块/thinking 全部陪跑;30 工具卡的 agent 回合=30 卡×每帧 build | 流式 | open |
| C-024 | `lib/features/chat/ui/stage_panel.dart:200` | med | _sigOf 每个 coalescer tick 全树深走 subagentBlocks | _onTranscript 逐帧(流式中≤60/s)递归遍历 settled+live 全部节点并拼串(conversation_transcript.dart:96);长对话数千节点×每帧,即使零 subagent 也照走 | 手风琴 | open |
| C-025 | `lib/features/chat/ui/stage_panel.dart:649` | med | 每个展开的 live 舞台挂 conversation 级 coalescer,别块的帧也令其每帧重建 | ValueListenableBuilder 监听整会话 transcript;并行多舞台展开时各自每帧重建,_body 每帧重扫 session.events 造 KV 行 | 手风琴 | open |
| C-026 | `lib/features/chat/ui/stages/scene_from_truth.dart:261` | med | sceneFromTruth 每 build 造新 BlockNode+jsonEncode 全真身+全量重解析 args | 新节点使 revision memo 失效,argsSession 走 Expando 兜底对整段 truth JSON(文档/图可很大)重跑 PartialJsonSession;director/ledger 任何变化都触发展开行重建 | 手风琴 | open |
| C-027 | `lib/features/chat/ui/tool_card_skins.dart:240` | med | _bashFooterStrip 嵌套量词正则每 build 跑全输出(收起态也跑) | \n*(\[[^\]]*\]\n?)*\[exit code…] 形回溯型 pattern,多括号行且无 footer 的大输出可灾难回溯;bashToolBody 是函数体、每帧执行 | 流式 | open |
| C-028 | `lib/features/chat/ui/tool_card_skins.dart:541` | med | 族体每 build 全量 jsonDecode(state.resultText) 无 memo(全 chat ui 30 处) | settled 结果 JSON 每次重建重解码;transcript 有身份缓存护住 settled 行,但侧幕行/live 回合内/ticker 重建路径每帧或每秒重付 O(结果体) | 流式 | open |
| C-029 | `lib/features/documents/ui/an_document_editor.dart:126` | med | _emitActiveHeading 每滚动帧遍历全文档节点+逐标题 layout 查询 | headingNodeIds O(全部节点) + 每个标题 getRectForPosition 布局查询,挂在 scroll listener 上每帧执行;长文多标题时滚动掉帧 | 滚动 | open |
| C-030 | `lib/main.dart:37` | med | 冷启动串行链:prefs→initWindow(≈10 个串行平台 await)→initLaunchAtLogin→首帧→才 spawn 后端 | backendStartupProvider 首读(gate 首 build,runtime.dart:74)才 start(),spawn+keychain 读+200ms 步长健康轮询与窗口初始化完全不重叠;之后 workspace GET(workspace_bootstrap.dart:26)再串一段 | 冷启动 | open |
| C-031 | `lib/core/model/partial_json.dart:111` | low | inFlightString 每次读都 List.unmodifiable(_path) 新分配 | 活窗每帧读;文本有长度 memo 但 path 每帧新造小对象,纯 GC 噪声 | 流式 | open |
| C-032 | `lib/core/ui/an_graph_canvas.dart:1266` | low | _GridPainter O(视口面积) 逐点 drawCircle | 24px 网格全屏双重循环 drawCircle,无 drawPoints/shader 批量;shouldRepaint 仅色变,但画布级 setState(拖拽/hover)期间同层伴随重绘 | 图渲染 | open |
| C-033 | `lib/core/ui/an_shimmer_text.dart:86` | low | 每个流光动词一只 repeat 控制器,常驻整个 live 期 | 有 RepaintBoundary 但 N 活卡+thinking=N ticker 持续唤帧+每帧 createShader;工具静默运行期也不停 | 流式 | open |
| C-034 | `lib/core/ui/an_term_viewport.dart:181` | low | termFold+ansiSpans 每 build 重折重染;_showAll 后是 O(全文) | widget 类体只在展开时跑,但 live 回合内每 tick 重建;用户点「显示更早」后 MB 级日志每帧全量折叠 | 流式 | open |
| C-035 | `lib/features/chat/ui/chat_tool_card.dart:122` | low | 每张 live 卡一只 1s Timer.periodic,setState 重建整卡 | 读秒 tick 触发整卡 build(含 :210 的体函数全量构建);并行 N 活卡=N 定时器,与 coalescer 帧叠加 | 流式 | open |
| C-036 | `lib/features/chat/ui/chat_transcript.dart:118` | low | _settledRowCache 无上限、切会话不清(State 无 per-会话 key 被复用) | loadOlder 每页塞新 entry 永不逐出;跨会话残留旧会话行 widget,长会话+多次切换纯增长(内存非 CPU) | 滚动 | open |
| C-037 | `lib/features/chat/ui/chat_transcript.dart:118` | low | _settledRowCache 按 turn.id 缓存 Widget 无上限、不随 resync 失效 | 身份缓存是 settled 行零重建的正确手段,但 map 只增不减且捏着旧 BlockNode 实例;超长会话+深跳窗口反复加载后内存单调增长 | 滚动 | open |
| C-038 | `lib/features/chat/ui/chat_transcript.dart:253` | low | 每 tick settled.take().toList()+head 展开,O(已载回合) 分配 | ValueListenableBuilder 每帧重切两份列表;长对话上翻数百页后每帧数百引用拷贝+GC 压力 | 流式 | open |
| C-039 | `lib/features/chat/ui/stage_panel.dart:224` | low | _rowKeys 每 rowId 一把 GlobalKey 只增不减(会话内) | putIfAbsent 永不清理(仅切会话清),长会话+翻页台账 GlobalKey 注册表持续增长;同文件 :171 注释确认仅切换时 clear | 手风琴 | open |
| C-040 | `lib/features/chat/ui/stage_panel.dart:540` | low | 收起行也执行 argStringPartial(description)+sceneFromSubagentNode 构造 | AnExpandReveal 的 child 构造在 open=false 时照跑;每次手风琴重建×每行 O(args) 提取(ToolCardState.of 有 memo,主要是提取与场景对象分配) | 手风琴 | open |
| C-041 | `lib/features/chat/ui/stage_panel.dart:735` | low | _GenericStage._body 每合并帧遍历全部 session.events | args 流入期间 ValueListenableBuilder 每帧重建,events 随流单调增长 → 每帧 O(n)、整流 O(n²);仅通用舞台路径,args 大的工具明显 | 流式 | open |
| C-042 | `lib/features/chat/ui/stages/workflow_stage.dart:39` | low | graphFromWorkflowOps 每 build 重放全部 ops + 画布 freezed 深比较 | arrayItemsAt O(全部已闭合事件) 每帧重跑(流中 O(n²) 累计);AnGraphCanvas.didUpdateWidget(:196) old.graph!=widget.graph 深比较 O(V+E) 每次父重建都付 | 图渲染 | open |
| C-043 | `lib/features/documents/state/document_state.dart:38` | low | 打字期间每次自动存触发树 refetch+backlinks refetch+rail 重建 | 正文 PATCH 发 document.updated → documentTreeProvider 400ms 防抖 invalidateSelf;backlinksProvider(:176) watch 树跟着重拉——连续打字每 600ms 静默期 = 2 个 GET + rail 重排 | 编辑器打字 | open |

## D demo 可达性矩阵(114 行 = 35 GAP + 79 已可达)

### D-GAP(待补种)

| # | feature × 状态 | 需补什么 | 状态 |
|---|---|---|---|
| D-001 | chat-composer · 附件上传失败 chip | failNextUpload 仅脚本钩(chat_fixtures.dart:616),UI 无触发径;可给展台加一次性失败命令/种子 | open |
| D-002 | chat-gate · ask_user 活问闸(选项+自由文本待答) | 仅 settled ask 卡(cv_show_human human0);需种 kind=ask 未决 interaction + streaming 开卡(GateKind.ask 在 tool_interaction_gate.dart:14) | open |
| D-003 | chat-gate · 决议失败复原(failNextResolve) | 仅脚本钩(chat_fixtures.dart:537),demo UI 无径 | open |
| D-004 | chat-rail · 列表失败重试(M9) | failNextListConversations 仅测试钩(chat_fixtures.dart:84),demo UI 无触发径 | open |
| D-005 | chat-rail · 无限翻(loadMore 分页) | demo 仅 13 会话 < 页大小 30(conversation_list_provider.dart:95);需 30+ 会话种子 | open |
| D-006 | chat-sidestage · agent 渐进开区舞台(R-9) | agents 快照空(chat_fixtures.dart:411)+ 无触点无幕 | open |
| D-007 | chat-sidestage · approval 信笺舞台 | 同上:approvals 快照空(chat_fixtures.dart:409)+ 无触点无幕 | open |
| D-008 | chat-sidestage · control 决策梯舞台(live+settled) | 无 control 触点、controls 快照空(chat_fixtures.dart:408)、脚本无 create_control 幕;需三选一补种 | open |
| D-009 | chat-sidestage · handler 方法架舞台 | handlers 快照空(chat_fixtures.dart:412)+ 无触点无幕 | open |
| D-010 | chat-sidestage · trigger 舞台(R-16 只信 GET) | triggers 快照空(chat_fixtures.dart:410)+ 无触点无幕;R-16 要求 GET 真相,须种 TriggerEntity | open |
| D-011 | chat-sidestage · 台账 loadMore 脚(分页骨架行) | cv_sync 仅 7 行 < 页大小 50;需 50+ 触点种子 | open |
| D-012 | chat-sidestage · 台账首拉失败重试 | fixture listTouchpoints 恒成功(chat_fixtures.dart:487-503),无失败钩;需加 failNext 钩+触发径 | open |
| D-013 | chat-sidestage · 墓碑行(deleted 动词封禁 GET) | 无 verb=deleted 触点种子(墓碑规则 touchpoint_ledger.dart:36);cv_sync 补一条 deleted 行 | open |
| D-014 | chat-stream · edit_workflow 图 morph | 脚本只有 create_workflow;补一幕 edit_workflow(压 wf_night 旧图 morph,B2 旗舰面) | open |
| D-015 | chat-stream · 失败舞台 failedHold(honesty ribbon failed / 失败洗亮) | 脚本全 completed;补一幕 tool close status=failed(或失败 Subagent)演 failedHold + 红丝带 | open |
| D-016 | chat-toolcards · WebSearch/WebFetch soft-fail 结局分类器 | cv_show_mem 的 mw2/mw3 皆成功;补一条 WebFetch 失败句结果(status=completed 渲红,WRK-059 H2 面) | open |
| D-017 | chat-transcript · 410 resync 落盘泡对账(M4) | emitResync 仅脚本钩(chat_fixtures.dart:575);demo 无 410 触发径(M6 人在环重连重拉同理不可达) | open |
| D-018 | chat-transcript · LLM_RESOLVE_ERROR「重选模型」CTA | 需 errorCode=LLM_RESOLVE_ERROR 消息种子(CTA 在 chat_transcript.dart:565-583) | open |
| D-019 | chat-transcript · max_steps / context_budget 琥珀横幅 | 无 stopReason=max_steps/context_budget 种子(分支在 chat_transcript.dart:551-552) | open |
| D-020 | chat-transcript · tool_result 硬失败(status=error 红回执/ownsError) | 全 fixture 无 error:true 结果块(tr() 的 error 参数从未用,chat_showcase_fixture.dart:20-27);展台补一张失败卡 | open |
| D-021 | chat-transcript · 发送失败泡(重试/丢弃) | failNextSend 仅脚本钩(chat_fixtures.dart:310);_PendingRow 失败态(chat_transcript.dart:614-629)demo 不可达 | open |
| D-022 | chat-transcript · 红色 error 横幅(errorCode·errorMessage) | 无通用 error 终态种子(danger 分支 chat_transcript.dart:556 无演示);种一条 stopReason=error+errorCode 消息 | open |
| D-023 | documents · 编辑器表格块 + URL 链接 + h1/h4–h6 标题档 | 种子正文无表格、无 markdown 链接、只有 h2/h3;补一篇全块型样章锁大纲六档下标 | open |
| D-024 | entities · approval 详情页 | 未传 approvalForms→rail approval 段恒空;补 ApprovalForm 种子(表单 schema) | open |
| D-025 | entities · control 详情页 | demoEntityRepository 未传 controlLogics(entity_demo_fixture.dart:169-318)→rail control 段恒空;补 ControlLogic 种子(决策梯/分支) | open |
| D-026 | entities · flowrun parked 停车态(人闸待决 :decide) | 种带 approval 节点的 workflow 图+parked flowrunDetail(fixture 已支持 _walkFlowrun 停车,entity_fixtures.dart:345-352) | open |
| D-027 | entities · handler/agent 版本历史 tab 有内容 | entity_demo_fixture 只种 functionVersions/workflowVersions;补 handlerVersions+agentVersions map | open |
| D-028 | entities · 图编辑器 ref picker 的 mcp/control/approval 候选 | fixture mcpServers/mcpTools/controls/approvals 候选全空;补 RefCandidate 种子 | open |
| D-029 | entities · 详情错误态(error+retry 面) | fixture 永不抛错且桌面无地址栏;需 fixture 加 failNext 脚本钩或种坏 id 展台入口 | open |
| D-030 | notifications · OS 原生通知(失焦路由) | 同上无 signal 可路由;随 toast 展台脚本一并覆盖(失焦时验证) | open |
| D-031 | notifications · 事件→toast(右上重要事件弹窗) | demo 无人调 fixture.emit()(仅测试用);加展台脚本延时 emit danger 行触发 ToastDispatcher | open |
| D-032 | settings · MCP 面板(server 行/registry 安装/调用日志/stderr) | fixture mcpServers/mcpRegistry/calls 全空(settings_repository.dart:717-718);种 ready+failed server+registry 条目 | open |
| D-033 | settings · 沙箱面板(已装运行时/env 行/GC) | bootstrap ok+available 有但 runtimes/envsByOwner 空(settings_repository.dart:851-856);种 SandboxRuntime+SandboxEnv | open |
| D-034 | settings · 记忆面板 | fixture memories 空(settings_repository.dart:685);种 pinned/user/ai 各态记忆行 | open |
| D-035 | shell · 全局快捷键+缩放(⌘B/⌘\/⌘,/⌘±/⌘0) | demo 根未挂 GlobalShortcuts(app.dart:64 只在 AppStartupGate 链;demo_main.dart:78 仅 AnOverlayHost)→demo 挂同件 | open |

### D-已可达(矩阵测试的断言底稿)

| feature × 状态 | 到达路径 |
|---|---|
| chat-composer · @提及 picker(combobox+伪药丸) | composer 输入 @ → entityMentionSource 喂 demo 实体(demo_main.dart:56) |
| chat-composer · send↔stop + 流中取消诚实 cancelled(live) | 任一对话发送 → 播放中点 Stop → FrameClose cancelled + 灰横幅(chat_demo_fixture.dart:97-123) |
| chat-composer · 模型选择器两态(粘性 + 首发盖章) | head 模型菜单;demoModelCapabilities 3 选项(settings_demo_fixture.dart:37;demo_main.dart:55);setModelOverride fixture 实现(chat_fixtures.dart:370) |
| chat-composer · 附件三入口→chip→泡内元数据 | 📎/粘贴/拖放 → fixture uploadAttachment(chat_fixtures.dart:619);已种泡内 chip:cv_sync m_s3 att_demo_shelf(chat_demo_fixture.dart:727-731, 893-900) |
| chat-gate · danger 人闸待决(批/拒,真线缆形) | cv_gate:tool_call 关帧+无 result+message streaming+种 interaction(chat_demo_fixture.dart:663-671, 883-892) |
| chat-gate · 决议章(resolved 冻结)+ decide_approval 判词章 + inbox 薄表 | cv_show_human:ask_user/decide_approval×2/list_approval_inbox settled(chat_showcase_fixture.dart:165-177) |
| chat-landing · 静态问候 + 首发懒建 | 新对话按钮 → landing → 发送即 createConversation(chat_fixtures.dart:156-168) |
| chat-nav · ?around= 深跳 + 回到现场 pill + 洗亮 | cv_scroll 64 turns > 页大小 30 → 场次条点旧锚走 messagesAround(chat_fixtures.dart:182-206) |
| chat-nav · gate 锚骑首页顶 | cv_gate 未决 interaction → listAnchors 首页前插 gate 行(chat_fixtures.dart:294-306) |
| chat-nav · 场次条五 kind 锚(user/工具簇/danger/compaction/abnormal) | cv_scroll 64 回合:簇 i==11 / danger i==23 / compaction i==21 / abnormal i==35(chat_demo_fixture.dart:675-710;锚构造 chat_fixtures.dart:227-307) |
| chat-rail · 归档灰(归档例) | rail 归档范围过滤 → cv_migrate(chat_demo_fixture.dart:652;fixture 归档过滤 chat_fixtures.dart:100-104) |
| chat-rail · 搜索/排序/改名/置顶/归档/删除 | rail 搜索框与行菜单;fixture 全实现(chat_fixtures.dart:87-141) |
| chat-rail · 未读绿点 hasUnread | rail 行 cv_weekly(chat_demo_fixture.dart:650);另:任一对话播完脚本落 hasUnread:true(:546) |
| chat-rail · 琥珀点 awaitingInput | rail 行「展台 · 活人闸」cv_gate(chat_demo_fixture.dart:649 awaiting:true) |
| chat-rail · 生成蓝点 isGenerating | 任一对话发送消息 → sendMessage 即置 generating + turnOpen 脉冲,脚本播 ~30s(chat_demo_fixture.dart:90-91) |
| chat-rail · 空标题回落 + 自动命名打字机(head/rail 双落) | 新建对话 → 发送 → 脚本终帧后 _demoTitle 盖章 + updated 信号(chat_demo_fixture.dart:547-553) |
| chat-rail · 置顶行 | make demo → chat 海洋 rail 顶部「AI 编辑 · sync_inventory 加重试」(chat_demo_fixture.dart:647 pinned:true) |
| chat-sidestage · Cast 台账行(主动词+微徽+动词史摘要) | cv_sync 7 条触点(chat_demo_fixture.dart:867-882;tp_d1 count:2 演 ×N) |
| chat-sidestage · attachment 展品座 | cv_sync 展开 shelf-audit.csv 行(tp_d5 :877 + attachmentMetas :893-900) |
| chat-sidestage · document 真身舞台(prose) | cv_sync 展开 值班手册 行(doc_runbook :831-839) |
| chat-sidestage · function 真身舞台(settled 渲代码) | cv_sync 展开 sync_inventory 行 → functionTruthProvider 吃 fn_sync 快照(chat_demo_fixture.dart:786-801;缝 scene_from_truth.dart:98-102) |
| chat-sidestage · mcp 接线现场(工具架) | cv_sync 展开 github 行(mcpServers 种子 :852-863) |
| chat-sidestage · skill 装订台 | cv_sync 展开 commit-helper 行(skills 种子 :840-851) |
| chat-sidestage · subagent 落定行(嵌套轨迹重水合) | cv_sync m_s5_sub 兄弟子消息折回 tool_call(chat_demo_fixture.dart:749-761;第三源 stage_panel.dart:331-336) |
| chat-sidestage · todo 板置顶行(进度环+分身板) | 发送后 todos 落 fixture map 持久(chat_fixtures.dart:467-478),重开会话仍在;live 演进见幕 2.5 |
| chat-sidestage · workflow 真身舞台(settled 渲图+判别式抽屉) | cv_sync 展开 nightly_rollup 行(wf_night 图快照 chat_demo_fixture.dart:804-830) |
| chat-sidestage · 台账空态 castEmpty | 打开无触点对话(cv_weekly/cv_scroll/展台各会话)→ 右岛空态(stage_panel.dart:375-381) |
| chat-sidestage · 收起态 activityBit(R-15 右钮点) | 发送后播放中收起右岛 → live 频道点亮右钮点(app_shell.dart:106-111) |
| chat-sidestage · 跟随三档菜单 + 展开/收起全部 | 侧幕统一头三动作(stage_panel.dart:71-87, 766-800) |
| chat-stream · Subagent 双活分身群像 + 活 todo 板推进 | 发送幕 2.5:双 Subagent 并行 + emitTodos 三帧推进(chat_demo_fixture.dart:269-330) |
| chat-stream · create_document 前缀快进(prose 流) | 发送幕二(chat_demo_fixture.dart:221-266) |
| chat-stream · create_workflow 图生长(逐 op 上画布) | 发送幕三(chat_demo_fixture.dart:423-478) |
| chat-stream · edit_function 活代码窗(地层→流入→真 diff 落定) | 发送幕一(chat_demo_fixture.dart:167-219;R-5 旧真相 fn_sync :786-801) |
| chat-stream · trigger_workflow 活运行卷(202 驻台+节点 tick+port 徽+durable 终态) | 发送幕 2.9:runTick×4(quality_gate 带 port:pass)+ run_terminal(chat_demo_fixture.dart:368-421;渲染 stage_panel.dart:805-879) |
| chat-stream · write_memory 记忆笺(live) | 发送幕 2.8(chat_demo_fixture.dart:332-364) |
| chat-stream · 文本 token 流 + 用户回声 FIFO | 任一对话发送 → 回声→open→delta→close(chat_demo_fixture.dart:139-147, 480-499) |
| chat-toolcards · B5 执行与档案族(run/call/invoke/flowrun/执行史) | rail「展台 · 执行与档案」cv_show_exec(chat_showcase_fixture.dart:68-88) |
| chat-toolcards · B6 嵌套子代理(NestedRunPane + trace) | 「展台 · 嵌套子代理」cv_show_nested E3 真形(:91-110)+ cv_sync m_s5_sub 委派轨迹(chat_demo_fixture.dart:749-761) |
| chat-toolcards · B7 生态(todo/relations/capability/reconnect_mcp) | 「展台 · 生态工具」cv_show_eco(chat_showcase_fixture.dart:113-130) |
| chat-toolcards · soft-fail 诚实(绿 status 失败句渲红,memory/handler) | cv_show_mem mw5 forget_memory miss(chat_showcase_fixture.dart:161-163);cv_show_census census4 restart_handler crashed(:207-208) |
| chat-toolcards · 建造族(EnvFixTimeline/trigger 四脸/control 决策梯/审批预览) | 「展台 · 建造实体」cv_show_build 六卡(chat_showcase_fixture.dart:178-194,build1 含 envFixAttempts) |
| chat-toolcards · 查阅检索族(EntityGetBody/命中窗/删除依赖审计/needsAttention) | 「展台 · 查阅与检索」cv_show_census(chat_showcase_fixture.dart:195-211) |
| chat-toolcards · 终端与文件手术族(Bash/BashOutput/Write/Edit/Grep/Glob) | 「展台 · 文件与终端」cv_show_shell(chat_showcase_fixture.dart:212-228) |
| chat-toolcards · 记忆与网页族(write/read/forget + WebSearch/WebFetch/search_tools) | 「展台 · 记忆与网页」cv_show_mem(chat_showcase_fixture.dart:131-164) |
| chat-transcript · cancelled 横幅(settled) | cv_sync m_s4 status:cancelled(chat_demo_fixture.dart:732-735) |
| chat-transcript · compaction 压缩标 | cv_scroll i==21 compaction 块(chat_demo_fixture.dart:684-688) |
| chat-transcript · markdown+代码+表格 | cv_weekly m_w2 表格(:767-770);cv_sync b_s2t 代码块(:725) |
| chat-transcript · max_tokens 琥珀横幅 | cv_scroll i==35 status:error+stopReason:max_tokens(chat_demo_fixture.dart:695-699;渲色 chat_transcript.dart:555) |
| chat-transcript · thinking 折叠卡(settled + live 流式) | settled:cv_sync b_s2r(:722);live:发送 → thinking 小簇流(:150-161) |
| chat-transcript · 危险动作卡(dangerous settled) | cv_scroll i==23 delete_function danger:dangerous(chat_demo_fixture.dart:689-693) |
| chat-transcript · 用户泡提及快照 | cv_sync m_s1 attrs.mentions(chat_demo_fixture.dart:714-720) |
| documents · skill 列表+编辑器(fork 带 agent·allowedTools / inline 两态) | documents rail skills 段→commit-helper(fork)/triage(inline)(documents_demo_fixture.dart:129-180) |
| documents · 右岛反链面板 | 选 Getting Started/Deploy——互链 wikilink 种子使反链非空(document_fixtures.dart:201-214 诚实扫正文) |
| documents · 右岛大纲面板 | 选任一页→右岛 inspector 大纲(h2/h3 齐);六档全覆盖依赖上行 GAP |
| documents · 右岛属性面板(描述/标签) | 各页均种 description+tags |
| documents · 树 rail(两级嵌套+CRUD+拖拽重排) | documents 海洋;5 页两级树(documents_demo_fixture.dart:34-127),fixture 写全通(move/duplicate/delete) |
| documents · 空文档/新建流 | rail New 建根页→就地改名→空编辑器(fixture createDocument 全通) |
| documents · 编辑器主块型(h2/h3/无序/有序/任务列/引用/围栏码 bash·sql/分隔线/wikilink 药丸/粗体/行内码) | Getting Started/Concepts/Deploy/Playbooks 正文覆盖(documents_demo_fixture.dart:37-127) |
| entities · agent 详情页(mount health 含不健康挂载) | entities→agent 段→researcher;mountHealth 种 web-search 离线(entity_demo_fixture.dart:266-275) |
| entities · flowrun 运行驾驶舱(running/completed 重试环/failed) | daily-digest→运行 tab;flr_run/flr_done(重试循环 iteration 0/1)/flr_fail 三态全种(entity_demo_fixture.dart:229-265) |
| entities · function 详情页(概览/版本历史/执行日志) | demo→左岛 entities→function 段→normalize-input;版本 v1/v2 + 执行日志 ok/failed 种子齐(entity_demo_fixture.dart:195-213) |
| entities · handler 详情页(运行态四相:running/crashed/stopped+配置缺失) | entities→handler 段→slack/postgres/stripe/twilio;twilio=partially_configured 缺 authToken(entity_demo_fixture.dart:176-181),调用日志种在 hd_slack |
| entities · trigger 详情页(cron/webhook/fsnotify/sensor 四 kind 脸) | entities→trigger 段;四源全种(entity_demo_fixture.dart:277-301);活动/派发 tab 在 trg_3a1f(cron)有数据,Fire CTA 可现催 |
| entities · workflow 触发→活 flowrun(tick 走真图) | daily-digest 头 CTA :trigger→fixture 按真图声明序走+发 signal(entity_fixtures.dart:317-367) |
| entities · workflow 详情页(图概览+版本 v1→v2 diff) | entities→workflow 段→daily-digest;v2 带质检门+回边(entity_demo_fixture.dart:113-116,201-205) |
| entities · 图编辑器(全屏 /entities/workflow/:id/editor) | daily-digest 概览→进入编辑器钮(workflow_overview.dart:70,router.dart:66);editWorkflow 落 v3 真生效 |
| entities · 执行右岛 run 终端(fn/hd 流式、agent ReAct 块树) | 任一 fn/hd/ag 详情头动词 CTA→右岛脚本流(entity_fixtures.dart:413-457,runDelay 10ms 真流式) |
| entities · 空态(未选中)+ rail 搜索空结果 | 切到 entities 不点行=AnState empty(entity_ocean.dart:98);rail 搜索输乱串=过滤空 |
| notifications · 托盘「待你处理」审批段 |  |
| notifications · 托盘「通知」时间流(今天/昨天/更早+已读未读混排) | 左岛铃→下段 feed;12 行横跨事件族(notification_demo_fixture.dart:21-41),点行深链+已读灰 |
| notifications · 未读红点徽标 | 种子 7 行未读→铃格红点(app_shell.dart:198 权威 count) |
| settings · 存储/限额/网络/关于面板 | dataDir=/tmp/anselm-fixture+42MB、limits 2 字段 schema、network 空配置表单、version=0.0.0-fixture(settings_repository.dart:792-846) |
| settings · 工作区面板(行/stats/危险删除) | settings→工作区;Demo ws 一行,建删可操作;注:stats 全零(WorkspaceStats() 默认),可选补真数字 |
| settings · 模型与密钥(受管免费档配额+BYOK+provider 目录) | settings→模型与密钥;2 key+quota 1730/5000(settings_demo_fixture.dart:14-33),providers 5 家内置 |
| settings · 通用/通知/对话/快捷键面板(机器域 prefs) | 齿轮→settings;机器级 SettingsPrefs 在 demo 也真持久(demo_main.dart:41) |
| shell · scheduler「即将推出」占位(rail+海洋双占位) | 海洋切换器点 scheduler(app_shell.dart:145,217) |
| shell · workspace 菜单/齿轮进 settings/浮层头面包屑折叠 | 底栏 workspace 钮等宽菜单;齿轮=settings;entities/documents/settings 滚动出浮层头 |
| shell · 左岛收起/拖宽、右岛拖宽(280–640 持久化) | 顶控收起钮/边缘拖拽;demo 用真 SettingsPrefs 重启存活 |
| shell · 通知托盘接管左岛中段(点海洋即收) | 铃格开/任一海洋收(app_shell.dart:119-122,135) |

## 普查系统性观察(各区 notes 汇)

- **AB**: 本区(工具卡底盘+族体 13 文件)间距 token 纪律总体好,重灾在:①条族四条并存(RunStatBar/ExecResultBar/_InvokeStatBar/_RunFooter),状态词映射也随之四抄;②行族碎裂——台账行/节点行/命中行/kv 逐键/intent 行各自手搓;③ToolWindow 是全区窗心脏(约 20 文件引用),须 P3 窗壳先行、最后一批换;④活尾 v1 只剩 mount 两处、可先杀最便宜;⑤显示封顶/截断常数无档随手定。tool_card_catalog 纯 spec 数据,无视觉违规,仅截断 helper 缺席。
- **AB**: 本区(chat 工具卡族体 14 文件)token 纪律整体较好,违规集中四类:①raw-mono 回落窗 ToolWindow+Text 现场发明 ×10+ 处 cap/色各异,是最大量收敛点;②当家件级视觉件(ToolHitList/GrepContentView/ProseWindow/人闸白岛壳)住 feature 层手搓壳,未进 core/ui+gallery;③活尾三形并存(document·skill mono 尾/NestedRunPane 微光尾/chat_thinking 流窗),窗内机器 payload 双件(ToolWindow vs AnSunkenPanel);④导航 pill 闭包与徽章行 Wrap 间距无文法各自重抄。动效裸值只在 tool_hit_list/chat_thinking 两处,reduced-motion 处理一致良好。
- **AB**: 系统病五条:①stages 目录「Container+Border.all+圆角」带边小卡同型五处(approval×2/skill/memory/subagent),窗族当家件可一网打尽;②手搓状态圆点 Container circle 跨 4 文件约 6 处,AnStatusDot 缺任意色/空心 variant 是根因;③图标/点裸算术(iconSm-4、iconSm-2、dot-2)5 处=私铸 8/10px 档;④伪药丸三处各写各的(document [[id]]/approval 琥珀囊/composer 角✕底);⑤status→色映射两套并行(runStatusColor vs AnStatus.fromRaw)。边界文件 tool_hit_list/tool_interaction_gate/transcript_peek 亦见 BoxDecoration 手搓(tool_hit_list:246,259/tool_interaction_gate:157,324),按分工归 tool-card finder,未入本账。chat_head/user_turn_content/mention_text_controller/scene_from_truth/stage_scene/stage_registry 干净。
- **AB**: entities 区 token 纪律整体优秀:全目录零裸色/零 BoxDecoration/零裸 EdgeInsets 数字,间距全走 AnSpace,state/data 层无 widget 代码。系统性问题集中三处:①右岛 run 终端(run_terminal.dart)先于 AnInspectorHead/活尾族成型,头带·活流·空态全手搓,是本区收敛主战场;②审批决断门三处重复手拼(终端/驾驶舱/收件箱);③block_tree_view 是 chat 工具卡/块行体系外的第二套 transcript 渲染。另有 loadMore/retry 文案 ×4 误用属顺手修。
- **AB**: 本区整体纪律较好(AnMenuSurface/AnCodeSurface/AnRow/AnState/AnKv token 大量正确复用),重灾集中三处:①编辑器浮层三件套(格式条/链接输入/slash·mention 弹层)各自手搓壳+三份翻转落点几何+三套私铸宽档,该收敛成一个 caret 锚定浮层原语;②编辑态与 an_markdown 只读态同视觉规则双实现(引用条/任务勾/提及药丸 vs AnRefPill),违反"同视觉同源";③documents 右岛是 AnGroupLabel/AnKv 的直接欠账客户。数据/状态层零视觉,无 demo 缺口新发现。
- **AB**: settings 区骨架健康:13 面板普遍用 AnSection/AnSettingRow/AnRow/AnState 组装,无大型手搓窗体。两大系统病:①「标签在上」表单字段块 6 文件 ×26 处手搓(_label/_field/内联三种实现),而 AnFormField 已存在且注释明言收口此模式——迁移即清;同理 AnCard/AnCallout 已存在没人用。②控件槽/表单 maxWidth 全是裸数(90–640 共 14 种),无宽度档,面板间互不一致。另:state/mcp_providers.dart:39 裸 Duration(300ms) 去抖(非动效,低危);storage/about/limits/sandbox 用 '…' 哨兵串当 loading 是同一手搓状态模式的变体。
- **AB**: app/ 与 core/shell/ 全清(纯组装,AnState/AnButton/token 到位,零手搓)。系统病三条:①core/ui 同族原语各自铸几何——chip 族 3 圆角 4 内距、framed 容器 3 圆角、标签-值 3 文法,正是 §0「只生不收」实锤;②微尺寸减法私铸(dot-2/iconSm-2/4)横贯 6+ 原语,是最高频 token 违规,补 dotSm/iconXs 两档可批量清;③tone.dart 宣称的单源被 an_toast/notification_row 各自绕开。gallery 自家壳(nav 行/卡/badge)未吃狗粮,讽刺点:法典陈列馆自己手搓。另 AnTermTail 流落 feature 层,活尾二合一前提是先归库。
- **C**: 普查范围=指定 8 类文件全读 + 关联原语(AnExpandReveal/AnShimmerText/AnStatusDot/AnMarkdown/AnCodeEditor/AnTermViewport/PulseClock)。地基本身干净的部分:CoalescingNotifier(≤1 通知/帧,O(1))、BlockTreeReducer(revision 记忆化+delta 缓冲释放)、PartialJsonSession/argsSessionOf(真 O(delta))、ToolCardState.of(revision 记忆化)、settled 行身份缓存(流式中 settled 回合零 build)——这些设计到位。核心机制性发现:①流式期重建粒度=整个「开回合」,回合内全部块(含已落定的 text/tool_call)逐 tick 陪跑;②ChatToolCard 的族体是**函数**(非 widget 类),`spec.body?.call` 在收起态也每 build 全量执行(jsonDecode/正则/argStringPartial 在函数体内立即跑),与 AnExpandReveal「child 只构造不膨胀」的防护错位——widget 类体(RunStatBar/AnTermViewport)收起时 build 不跑,函数体跑;③receipt/target 闭包每 build 重算且无记忆化;④动效三源并存:PulseClock(共享钟,已建)vs AnStatusDot/AnShimmerText 各自 AnimationController.repeat(未迁移)——N 活卡=N ticker,AnStatusDot 无 RepaintBoundary 会脏到整行边界。定罪建议:release + timeline 跑「单开回合含 20+ 工具卡的长对话流式」「右岛展开+流式」「长 reasoning 块流式」三场景,对照 TranscriptProbe 计数即可快速验证 #1/#2/#4/#5。
- **C**: 普查范围:stage_panel.dart+stages/ 全读、stage_director(_provider)/touchpoint_ledger/stage_expansion/rundown/flowrun_progress 全读、an_graph_canvas/an_expand_reveal/coalescing_notifier/partial_json 全读、an_editor+syntax+document_ocean+an_document_editor+document_state 全读、main/window/backend_controller/runtime/workspace_bootstrap 全读、chat_transcript 关键段。已核实的『无罪』项(供对抗审计省力):① AnExpandReveal 全收时子树移出树、child 只构造不 build,收起行不触发 GET(scene_from_truth 注释属实);② transcript settled 行身份缓存+RepaintBoundary,流式期 settled 行零 build——jsonDecode 嫌疑主要落在侧幕行/ticker/live 回合路径;③ ToolCardState.of 按 revision memo 对真 transcript 节点有效(仅被 sceneFromTruth 的 fresh node 绕开);④ CoalescingNotifier/PartialJsonSession O(delta) 契约成立;⑤ termFold 只折 kTermWindow 有界窗口、tailLines O(尾);⑥ shellHead.setCollapsed 有同值 early-return(:115);⑦ 单主角流式(无并行 channel)时 StageState 相等抑制生效——#1 只在并行工具场景发作;⑧ director/ledger/rundown 订阅均在 ref.onDispose 正确取消,SSE 三流 keepAlive 属设计。最重叠加场景:并行工具流式 + 手风琴展开着 workflow/fn 行 = #1(每帧全列表重建)×#2(每帧全量重序列化)×#5(每帧重分词),这是右岛掉帧的首要复合嫌疑。冷启动量化:main 串行 await 链 + spawn 不与窗口重叠 + 健康探测 200ms 步长 + workspace GET 串行,理论可并行压缩数百 ms。
- **D**: demo 装配确认:demo_main.dart 一个 ProviderScope 换缝(chatRepositoryProvider→demoChatRepository、modelCapabilitiesProvider→demoModelCapabilities、mentionSourceProvider→entityMentionSource),与 make app 共壳共路由。demo 会话共 13 个(cv_sync 置顶 + 8 展台 + cv_gate 琥珀 + cv_weekly 未读 + cv_scroll 长卷 + cv_migrate 归档);发送任意消息即播六幕脚本(thinking→edit_function→create_document→双 Subagent+todo→write_memory→trigger_workflow 活运行卷→create_workflow 图生长→text),流式族覆盖极好。GAP 按五主题聚:①右岛 5 个 kind 舞台无入口(control/approval/trigger/agent/handler:触点、快照、流式幕三缺)+ 墓碑行——正是 WRK-066 §4-D 预判的「右岛各 kind 舞台稳定复现入口」缺口;②终态横幅只演 cancelled+max_tokens 两色,红 error/max_steps/context_budget/LLM_RESOLVE_ERROR CTA 全缺;③失败径 fixture 全有一次性脚本钩(failNextSend/Upload/Resolve/ListConversations/emitResync)但 demo UI 无触发径——建议加「展台 · 失败径」会话或调试触发;④两处分页永不触发(rail 13<30、ledger 7<50);⑤流式缺 edit_workflow 图 morph、failedHold 失败舞台、ask_user 活问闸、Web 族 soft-fail。另记:demo 脚本给 write_memory 落 memory 触点(chat_demo_fixture.dart:350-364),但 scene_from_truth.dart:53 注明后端 memory 是 noTouch 永不产 settled 台账行——demo 种子与生产真相在此背离,建对抗审计核一下(fixture 造了真机不可能出现的行)。M6 人在环重连重拉属真连接行为,demo 无 socket 概念,未单列。
- **D**: 普查范围=chat 之外全部(entities/documents/settings/notifications/shell)。证据基面:demo 装配 demo_main.dart:44-57(五 repo override + modelCapabilities + mentionSource);唯一壳 app_shell.dart。  【重要更正】「notifications · 托盘待你处理审批段」一行应为 GAP(schema 需 path 故留空说明于此):FlowrunInbox sectioned 模式 parked 空即整段塌没(flowrun_inbox.dart:44);listFlowrunInbox 只扫 flowrunDetail 里 status=parked 且 kind=approval 的节点(entity_fixtures.dart:198-202),demo 三个 flowrun 无 parked 行,且 wf_digest 图无 approval 节点故连触发运行都停不了车——seed_needed=给某 workflow 图加 approval 节点+种 parked flowrunDetail,一份种子同时解锁「entities·flowrun parked」「托盘待你处理」「run 终端人闸 :decide」三处。  GAP 汇总(9):①control 详情 ②approval 详情 ③flowrun parked/人闸(连带托盘待你处理段)④handler/agent 版本历史 ⑤图编辑器 ref picker mcp/control/approval 候选 ⑥entities 错误态 ⑦documents 表格/URL链接/h1·h4-h6 块型 ⑧settings MCP/记忆/沙箱三面板空 ⑨notifications toast+OS 通知(无 emit 脚本)+shell 全局快捷键缩放(demo 根缺 GlobalShortcuts——这条是装配缺件非 fixture 种子,修一行)。  可达面亮点(fixture 质量好):handler 四运行态相、trigger 四源全脸、flowrun 重试环 iteration 0/1、agent mount 不健康、workflow 触发走真图+approval 停车逻辑已内建(只差图里有 approval 节点)、documents 反链诚实扫正文、settings fixture 有丰富脚本钩(failNext* 系列)可低成本补错误态展台。  关键文件:frontend/lib/dev/demo_main.dart · frontend/lib/app/app_shell.dart · frontend/lib/features/entities/data/entity_demo_fixture.dart · entity_fixtures.dart · frontend/lib/features/documents/data/documents_demo_fixture.dart · frontend/lib/features/settings/data/settings_demo_fixture.dart · settings_repository.dart(FixtureSettingsRepository)· frontend/lib/features/notifications/data/notification_demo_fixture.dart · notification_fixture.dart · frontend/lib/features/notifications/state/toast_dispatcher.dart:35 · frontend/lib/app/app.dart:64。
