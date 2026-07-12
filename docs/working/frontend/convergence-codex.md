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

**现状**:同角色至少 6 种壳并存——`ToolWindow`(feature 层薄壳包 AnSunkenPanel,A-001)、`ProseWindow`(白底描边+FadeCollapse)、`MemoryNoteCard` 手搓卡壳(A 系)、approval 信笺/subagent 卡手搓 Container、双日志抽屉(`_LogsDrawer` vs `_LogDrawer`,截断策略还不同)。

**当家件**(拍板修订:一脸):
```dart
AnWindow({
  required Widget child,
  Widget? header,            // 左头槽(命令回显/标题行)
  List<Widget> actions,      // 右动作槽(copy 等,chip 族件)
  double? maxHeight,         // 封顶(AnSize 视口档,禁裸数)
  bool collapsible,          // 超高 FadeCollapse(展开/收起文案内建)
})
```
**规则**:①**唯一脸=白底+hairline 边+card 圆角**;灰底容器材质全 App 退役(用户消息泡唯一例外,气泡非窗)。②**窗禁套窗**(叶子容器;窗间距分隔,不嵌套)。③内容不嗅探——窗是纯壳,内容由 AnCodeEditor/AnMarkdown/AnJsonTree/AnLiveTail 等组合进 child;**代码/diff 自带 AnCodeSurface 壳,不再套窗**。④截断注记("已截断,N 字符")作为窗的内建 footer 形态。⑤日志抽屉 = `AnDisclosure + AnWindow` 固定组合,双端截断统一(head 2000 + tail 4000)。

## 族二 · 代码 —— `AnCodeEditor` 长 live 形态(强化地基的原型场景)

**现状**:落定=AnCodeEditor(高亮/自带框/copy);活=ToolWindow 塞裸 mono Text(×3 处)+侧幕另有 `AnLiveCodeWindow`——同一内容两套壳,live→settled 换壳跳变(§0 批评 #4 的原型)。diff 同病:落定 AnVersionDiff,活=手搓 ±色块段(`_editSeg`)。

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

**现状**:AnBadge/AnRefPill/AnCopyChip/AnPathChip/WindowCopyButton 五件 + 手搓 chip 一批(_beltChip 描边、_morphChip 描边+划线、op ticker 色点、skill 琥珀药丸、状态圆点手搓 ×3——AnStatusDot 就在旁边);id 截断三元式手搓 15+ 处,截断档随手定(10/12/24/40/48)。

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

**现状**:四条同角色(RunStatBar/ExecResultBar/_InvokeStatBar/_RunFooter),各自手拼 ' · ' InlineSpan 链(模式散布 4+ 处),状态词↔色映射双系统(runStatusColor vs AnStatus.fromRaw)。

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

**现状**:ToolLiveTail(v1,plain)与 AnTermTail(v2,termFold+ANSI)并存;WebFetch prose 尾另手搓定高视口。

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
