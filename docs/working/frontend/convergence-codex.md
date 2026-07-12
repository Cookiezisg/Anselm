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

## 批5a 落地(2026-07-12,芯片族·五件收编+点族)

A-032/A-033/A-034/A-036/A-038/A-046/A-048 关账(A-031 剩 AnAttachmentChip、A-039 剩 function_stage opTicker 内点随 A-043、A-045 缓议——窗头裸字形 vs 芯片壳待帧裁,均留 open 注记)。**AnBadge/AnCopyChip 物理删除**(131+8 用点机械并入 AnChip;copyDone 死键退役),AnRefPill/AnPathChip/AnScopeBadge 降**薄预设**(名字保留,壳全走 AnChip;RefPill 自有知识=kind 字形单源+a11y 类型词+交互闸,PathChip=basename 切法,ScopeBadge=枚举 slang 表)。法典族三增量(签名外小参数,随批签字):
- **AnChip +5**:`tooltip`(静息覆盖——path/value hover 全文)/`semanticLabel`(a11y 覆盖,**静态芯片也承载**[Semantics+ExcludeSemantics 单节点])/**空标签守卫**(icon-only 示能形不留孤儿间隙)/**outlined 形不透明白岛底**(hover 提亮;灰泡上透明芯片读作破洞,承 AnRefPill 岛面)/`dot: AnStatusDot?` **强类型点槽**(拒任意子树;吸收 AnBadge.dot 与 op ticker 双脸)。**i18n 惰性化**:slang 仅交互径消费,静态芯片不问宿主要 TranslationProvider。
- **AnStatusDot.raw**:直喂色+`hollow` 空心环+`size` 档(dot 7/dotSm 5/swatch 10 新铸)——珠串/色点/fire 记号唯一实现;raw 形纯静态零帧。六处手搓圆点清剿(run_ledger×3/handler·trigger_stage/notification _Dot[6→7px 归档]/workflow kind 方块→族圆点 swatch 档,刻意裁决)。
- **AnFollowPill.jump**:静态回场脸(label 站点自定+`elevated` 浮影[AnOpacity.shadow=0.12 新档])——绝不呼吸不挂钟;吃 an_term_viewport._backToLatest 与 chat_transcript._BackToLivePill 两处手搓;_PillShell 内两处 token 算术(dot-2/iconSm-2)清为 dotSm/iconXs。
- **拍板点记档(建造者裁决,帧供否决)**:①RefPill 字面 body13 w400→族 meta12 w300(全族一字面;帧核可读性,否决则退半降级);②copy 芯片族声=outlined(与 path chip 一致);③AnSize.capsulePadY=1 新档(行内药囊竖距,inline 脸用)。
- 新 variant 全部 gallery-first(raw 点四形/outlined·copy·icon-only·strikethrough·tooltip 五 specimen/inline 嵌文本/jump 双态)+ tonggui 电池 7 测(dot 槽/空标签/host-agnostic/a11y/raw 尺寸/空心零帧/jump 静态)。

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

**现状**:AnKv 在,但逐键排布另有 ToolIOSection 私排、_metaRow、各 stage 手搓 label-value;台账/命中行四套(_RunRow/_nodeRow/_WebHits/_ToolHitCard),状态点一左一右;「展开全部 N」escape 手搓 ×2;intent 行三套。

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
