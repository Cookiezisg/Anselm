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

# WRK-068 「同轨」法典草案 —— 六族当家件 API + 版式文法(待拍板)

> [`convergence.md`](convergence.md)(WRK-066)P2 产物。**用户逐族拍板后冻结**,之后一切视觉争议回本档查表。
> 每族给:现状(吃谁,引 [台账](convergence-ledgers.md) 条号)→ 当家件 API → 规则 → **⚖ 拍板点**。
> 拍板后:法典正文提取进 `references/frontend/design-system.md`(reference 级,逐字同步代码);
> **视觉细节保险**:P3 每族首件先出 gallery 真帧交抽查——不满意改壳不改 API(概念先冻结,壳可调)。

---

## 族一 · 窗(机器产物容器)—— `AnWindow`

**现状**:同角色至少 6 种壳并存——`ToolWindow`(feature 层薄壳包 AnSunkenPanel,A-001)、`ProseWindow`(白底描边+FadeCollapse)、`MemoryNoteCard` 手搓卡壳(A 系)、approval 信笺/subagent 卡手搓 Container、双日志抽屉(`_LogsDrawer` vs `_LogDrawer`,截断策略还不同)。

**当家件**:
```dart
AnWindow({
  required Widget child,
  AnWindowLook look = AnWindowLook.sunken,  // sunken(凹面灰,机器原料) | card(白底描边,成品排版)
  Widget? header,            // 左头槽(命令回显/标题行)
  List<Widget> actions,      // 右动作槽(copy 等,chip 族件)
  double? maxHeight,         // 封顶(AnSize 视口档,禁裸数)
  bool collapsible,          // 超高 FadeCollapse(展开/收起文案内建)
})
```
**规则**:①机器原料(终端/代码/JSON/原始文本/日志)= `sunken`;成品排版(prose/信笺/便笺/表单预览)= `card`。全 App 只有这两种容器脸。②内容不嗅探——窗是纯壳,内容由 AnCodeEditor/AnMarkdown/AnJsonTree/AnLiveTail 等组合进 child。③截断注记("已截断,N 字符")作为窗的内建 footer 形态,不再各处手拼。④日志抽屉 = `AnDisclosure + AnWindow(sunken)` 固定组合,双端截断策略统一(head 2000 + tail 4000)。

**⚖ 拍板点**:两种脸(sunken/card)够不够?(台账证据说够——没有第三种正当形;若你想要第三种此刻说)

## 族二 · 代码 —— `AnCodeEditor` 长 live 形态(强化地基的原型场景)

**现状**:落定=AnCodeEditor(高亮/自带框/copy);活=ToolWindow 塞裸 mono Text(×3 处)+侧幕另有 `AnLiveCodeWindow`——同一内容两套壳,live→settled 换壳跳变(§0 批评 #4 的原型)。diff 同病:落定 AnVersionDiff,活=手搓 ±色块段(`_editSeg`)。

**当家件**:
```dart
AnCodeEditor(code, lang, reading: true,
  live: false,        // NEW:live=流式脸——同壳同框同 copy 位,内容渲纯 mono 尾(逐 delta 重高亮烧帧)
  tailLines: 8,       // live 期尾行数
)
AnVersionDiff(before, after,
  live: false,        // NEW:两幕手术脸——−old 段/+new 段随流生长(吃掉 _editSeg)
)
```
**规则**:①代码内容(含流式期)永远住编辑器壳,**换脸不换壳**——live→settled 只是内容渲染方式切换,边框/copy 位/圆角零跳变。②`AnLiveCodeWindow`(侧幕)并入 live 形态后删除。③扩展名→语言映射归 core(删 feature 层两张私表 `_langOf`/`_buildLang`)。

**⚖ 拍板点**:live 期保持「纯 mono 不高亮」(帧预算理由)你认不认?

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

**⚖ 拍板点**:filled 与 outlined 两形都留吗?(证据:描边形今用于「预授权/变更花名册」这类轻列表,填充形用于状态徽——语义有别,建议都留)

## 族四 · 行(键值/标签-值/台账行)—— 台账最大族(34 条)

**现状**:AnKv 在,但逐键排布另有 ToolIOSection 私排、_metaRow、各 stage 手搓 label-value;台账/命中行四套(_RunRow/_nodeRow/_WebHits/_ToolHitCard),状态点一左一右;「展开全部 N」escape 手搓 ×2;intent 行三套。

**当家件**(行族三件 + 既有 AnDisclosure):
```dart
AnKv(rows)                    // 唯一键值对排布(已有,吃掉一切逐键私排)
AnFieldSection(label, child)  // 「13 灰标签在上 + 内容在下」的唯一实现(吃 ToolIOSection 骨架/intent 行/_section)
AnLedgerRow({lead, primary, chips, meta, onTap, expandChild})  // 唯一台账/命中行(吃四套;状态点一律居左)
```
**规则**:①键值=AnKv,标签-值=AnFieldSection,**禁第三种排布**。②台账行 lead(状态点/glyph)一律左侧。③「展开全部 N」escape 并入 AnLedgerRow 列表壳。④' · ' 元数据链禁手拼(归条族)。

**⚖ 拍板点**:工具卡主行(动词行)v1 是否入族?(建议:本战役**不动**主行——它是打磨过的核心交互,收敛它风险>收益,记 §7 豁免候选)

## 族五 · 条(结果/状态条)—— `AnStatBar`

**现状**:四条同角色(RunStatBar/ExecResultBar/_InvokeStatBar/_RunFooter),各自手拼 ' · ' InlineSpan 链(模式散布 4+ 处),状态词↔色映射双系统(runStatusColor vs AnStatus.fromRaw)。

**当家件**:
```dart
AnStatBar({
  AnStatus? status,          // 状态词徽(色随 AnStatus,删平行映射)
  List<AnStat> stats,        // ' · ' 链(text|tabular 数字),内建分隔
  List<Widget> chips,        // 尾随凭据(AnChip 预设:ref pill/copy)
  Widget? note,              // 下挂注记行(envError 红/restartNote 琥珀)
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
**规则**:活尾只此一件;v1 删除;prose clamp 高度进 AnSize 档。(代码流式尾**不在此族**——归代码族 live 形态,壳必须是编辑器壳。)

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

**⚖ 拍板点(文法)**:第 1 条对齐规则与第 6 条色调语义是口味核心——照此冻结吗?

---

## 拍板清单(逐族 ✓/✗/改)

| # | 项 | 建议 |
|---|---|---|
| 1 | 窗族两脸(sunken/card) | ✓ |
| 2 | 代码 live 纯 mono 不高亮 | ✓(帧预算) |
| 3 | 芯片 filled+outlined 双形 | ✓(语义有别) |
| 4 | 工具卡主行本战役不动 | ✓(记豁免) |
| 5 | 条族四并一 | ✓ |
| 6 | 活尾三形态一件 | ✓ |
| 7 | 文法十条 | ✓ |
