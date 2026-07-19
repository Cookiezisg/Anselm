---
id: WRK-073
type: working
status: active
owner: @weilin
created: 2026-07-19
reviewed: 2026-07-19
review-due: 2026-10-17
audience: [human, ai]
---

# 右岛三段式文法 —— 全右岛收敛战役（台账 · 收官）

> 用户 0719 裁决：全 App 右岛「小灰标题 + 平坦大块」寡淡（Activity 头无 icon、右侧四钮杂）。经调研（**Linear 删标题派** / **Figma·GitHub 信息组头派**）拍板 **三段式文法**，分四批全右岛铺开。**批 0–3 全落（0719 收官）**——chat 侧幕 / documents 检查器 / entities 调试台 / scheduler run 检查器四处右岛皆迁 `AnPanelHead`。落地形态陈述见 [`design-system.md`](../../references/frontend/design-system.md)（AnPanelHead + 三段式立法）、[`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md)（chat 范例田）、[`features/documents.md`](../../references/frontend/features/documents.md)（documents 检查器）、[`features/entities.md`](../../references/frontend/features/entities.md)（调试台头）。

## 总纲：三段式文法

1. **§1 身份头**：`icon + 标题 + ⋯ + ✕` 一行，全右岛统一，**面板级动作全收 ⋯**（右侧永远至多两钮）。原语 = `AnPanelHead`（core/ui）。
2. **§2 速览带**：头下一行安静数字速览（如「12 触点 · 3 执行 · 1 待你处理」）——**零人话律 = 有真信号才在**（无信号不渲、绝不硬凑）。不造新原语，一行 `AnText.meta` + `·` 分隔文法，传 `AnPanelHead.sub`（`null` = 无带）。
3. **§3 分组内容**：平坦长列表 → 可折叠组，组头 = **AnRow 组头文法**（常驻箭头 lead + 计数 meta、无 ⋯，今日托盘/左岛 Pinned·Recents 同款）——**左岛 / 托盘 / 右岛三处一种语言**。

## 四批建造顺序

| 批 | 范围 | 状态 |
|---|---|---|
| **批 0** | 地基：`AnPanelHead` 原语（core/ui + gallery 样章）+ 速览带文法判断 + design-system.md 三段式立法 | ✅ 已落 |
| **批 1** | chat「活动」侧幕范例田：头换 `AnPanelHead`、⋯ 收编（跟随三档·全展开·全收起）、速览带、顶层分组 | ✅ 已落 |
| **批 2** | documents 右岛：三孤儿标题并一头三组 | ✅ 已落（`documents_inspector.dart` 头 §1 + 速览带 §2 + 三组 §3；详见 documents 单落账） |
| **批 3** | entities 调试台 + scheduler 右岛迁移 | ✅ 已落（本单，见「批 3 落账」） |

## 批 0+1 落账（本单，0719）

### 地基（批 0）
- **`AnPanelHead`**（`lib/core/ui/an_panel_head.dart`，导出于 `ui.dart`）：`icon`（必填身份字形）+ `title` + `menuEntries: List<AnMenuEntry>`（空→无 ⋯，退役「四钮杂」）+ `menuSemanticLabel` + `sub`（速览带槽，`null`=无带）+ `onClose`/`closeSemantics`。**几何守右岛内距单源律**（同 `AnInspectorHead`：岛壳 12 唯一、头前导 0，icon/标题落岛 pad 缘 = 岛 +12；下方行族各缩 s8 → 头以一档超顶列表）。gallery 样章三态（⋯+速览带 / 无 ⋯ 无带 / 超长标题省略）。测锁 `test/core/ui/an_panel_head_test.dart`。
- **速览带**：**不造新原语**（判断结论）——就是 `_glance(context, ref, cid)`（`stage_panel.dart`）产出的一行 `AnText.meta` `·` 分隔文法，传 `AnPanelHead.sub`。
- **design-system.md**：§5 加 `AnPanelHead` 原语条 + **★ 三段式文法** 立法（三段各自律 + 零人话律 + 组头复用 AnRow）。

### chat 范例田（批 1）
- **头**（`StagePanel`）：`AnInspectorHead` → `AnPanelHead`（icon `AnIcons.activity` + 标题 `chat.stage.island`）；旧四小钮（`_FollowMenu`/`_ExpandAllButton`/`_CollapseAllButton`）**物理删除** → `_panelMenuEntries`（跟随三档单选勾 + 展开全部[顺手 `openAll` 掀组] + 收起全部）收进 ⋯。
- **速览带**（`_glance`）：N=触点台账实体数、M=执行过实体数（`byVerb` 含 `executed`）、K=`pendingInteractionsProvider` 待决数；每段 `>0` 才现、全零 `null`。i18n 新键 `chat.stage.{glanceTouched,glanceExecuted,glanceNeedsYou}`。
- **顶层分组**（`_computeItems` + `_buildTier` + `_GroupHead` + `stageGroupCollapseProvider` + 纯分类器 `sidestageTierKey`）：落定 Cast 按**时间三档**折叠（刚刚/早些时候/更早，键 = `lastAt`）；组头 = icon-free collapsible `AnRow`（常驻箭头 + 计数、无 ⋯）；档序刚刚→早些时候→更早、档内最新先；**两条防碎律**（①空档免头 ②单档全裸行）；**todo + 活/委派层（合成 live·落定 subagent）恒不分组置顶**；档折叠态与行级 `stageExpansionProvider` **正交**；**含 live/自动展开行的档强制展开**（深跳/auto-expand 绝不藏活）。i18n 新键 `chat.stage.{groupJustNow,groupEarlierToday,groupEarlier}`。测 `stage_grouping_test.dart`（纯分类器三档分界 + 空档免头 + 单档裸行 + 折叠 + 深跳强制展开 + 跨天 + **折叠动效中间帧 + reduced 即时**）+ `stage_panel_test.dart` 适配。
- **折叠动效**（用户 0719 追加，瞬跳→标准滑动）：**Option A（非虚拟化配方，最小手术）**——每档整合成单 list item（`_buildTier`：组头 + `AnExpandReveal.builder` 裹档内行），折叠走 **kit 标准 `AnExpandReveal` 收合滑动**（chevron 旋转[AnRow]+高度滑动[reveal]同播、reduced 双闸即时、`AnMotion.mid`）。**选它而非通知托盘 `SliverAnimatedList` 配方的理由**：①`AnExpandReveal` 声明式 `open` → **强制展开（深跳/导演器）自动播同一滑动**，命令式 removeItem/insertItem 做不到；②列表虽 `ListView.builder`，但档整合成单 item 后即「一组一 reveal」的非虚拟化形，与 flowrun_inbox「待你处理」band 同款；③避开托盘配方与导演器 auto-expand/scroll-to-row/transcript 重建/force-open 的交织雷区。惰性（收起档不建行）、`AnExpandReveal` 可安全嵌套（ClipRect+Align，非 AnimatedSize）故档 reveal 裹行体 reveal 无碍。

### 分组轴取舍（两轮）
**第一轮 = kind（已否决）**：授权「读现状选最自然的轴」下我选了 kind（robust + 语义上一实体只属一 kind + 合「信息组头派」）。**用户 0719 看中间态当面否决**——「12 条内容 10 个组头，组头比内容多」的**目录病**（demo/短对话每 kind 常 1 个，kind 轴碎成一堆单行组，比平坦列表更糟）。
**第二轮 = 时间三档（定案）**：照**通知托盘的精神**、**用对话的刻度**——**刚刚**（本回合，最近一次用户发言以来）/ **早些时候**（今天更早）/ **更早**（跨天）；键 = 行的最后触碰时间。**两条防碎律**根治目录病：短对话（全「刚刚」）回落干净一列（单档裸行），长对话自动分层。
**「刚刚」取径**：R-14 回合锚**首选但取不到**——`hydrateTurn` 丢 `createdAt`、`BlockNode` 无时间戳，回合边界在 ledger/transcript 节点数据上无法取；按用户授权的退化取径用**固定 10-min 窗**代「本回合」（`stageJustNowWindow`）。日界（早些时候 vs 更早）= 本地日历天。分类器 `sidestageTierKey` 纯函数、注入 `now` 可定测（三档分界 + 10-min 边界 + 跨midnight 归「刚刚」全锁）。

## 批 2 落账（documents，本单 0719）

三孤儿小标题（大纲/属性/backlinks 各一 `AnGroupLabel` + 平坦块）→ **一头三组**；组内实现**原样保留**（大纲树/KV/反链列表/skill 表单——动骨不动髓），只重组外壳。`documents_inspector.dart` 全重写。

### 头（§1）+ 速览带（§2）
- **头**：`_InspectorShell` `AnInspectorHead` → `AnPanelHead`（doc/skill 字形 + 页名/slug + ⋯ + ✕）。**⋯ 菜单** = `_menuEntries`（`展开全部`/`收起全部`——可折叠三组结构引入的**唯一**面板级动作；空状态[无选]传空 `menuEntries` → 无 ⋯，「无则暂缺」诚实）。i18n 新键 `documents.props.{expandAll,collapseAll}`。
- **速览带 `_glance`**：`N 字 · M 反链 · <rel>编辑`——**字数**=`content`/`body` 去空白后码点数（`_charCount`，粗粒度、含 markdown 语法字符，`_compactCount` 压成 `2.4k`；是 size proxy 非语言学 word count）· **反链数**=`backlinksProvider` 长度 · **`<rel>`**=新增 core `fmtRelativeDay`（`time_format.dart`：今天/昨天/N 天前/>7 天数字 `y/m/d`，注入串保纯可测——与 chat rail 的 `conversationTimeLabel` 语义近，后者在 chat 文件、本批不动，未来可合流 core）。**零人话律**：chars/backlinks 为 0 省段、`编辑`恒在（updatedAt 恒有）；全空→`null`→无带（仅无选/加载时）。skill 无反链（后端只在 documents 解析 `[[id]]`）→ 反链段被 0 律省。i18n 新键 `documents.props.{glanceChars,glanceBacklinks,glanceEdited,time.{today,yesterday,daysAgo}}`。

### 三组（§3）
- **`_GroupSection`**：组头 = collapsible `AnRow`（常驻箭头 lead + 计数 meta、无图标无 ⋯，与左岛 Pinned·Recents/托盘时段头同一 AnRow 文法）；体 = `AnExpandReveal`（只读体，动画+树移除 a11y 干净）**或** `Offstage`（`keepMounted`，见下）。
- **doc 三组**：**大纲**（`docOutlineProvider`+`docOutlineActiveProvider`，点行→`outlineJumpProvider`；无标题→整组静默缺席，计数=标题数）/ **属性**（path/size/modified 族 KV，计数=字段数=3）/ **反链**（入向 `link` 边，文档行点击导航；空态陈述「无页面链接」，计数=条数）。**skill 二组**：大纲 + **属性**（`_SkillForm` frontmatter，计数=可见字段数，`keepMounted`；无反链组）。默认全展开。
- **折叠持久化**：`docGroupCollapseProvider`（`state/doc_group_collapse.dart`）——**复用已声明前缀族** `an.right.collapsed.`（`SettingsPrefs.getFamilyBool`/`setFamilyBool`，此前声明但无消费者，语义正为「per-ocean 右岛折叠」）。**取舍**：选**磁盘持久化**（跟随三档先例的轻量版）而非 chat 侧幕的 session 级——折叠意图是稳定的机器级面板偏好、应跨重启，且前缀族恰为此预留、外于设置三相等门禁（`SettingsKeys.all`）。
- **skill 属性组 `keepMounted` 特例**（Offstage 不卸载 vs `AnExpandReveal` 树移除）：表单持防抖 autosave + 编辑缓冲，`openSkillProvider` 刻意不中途 refetch（保光标）→ 收起若卸载会丢在途保存并从陈旧 provider 重挂错值。故此一组保态收起（换掉滑动动画换正确性，注释在案）；其余组均 `AnExpandReveal`。

### 测
`documents_test.dart` 加「三段式文法」组（一头三组 + 孤儿大写标题 findsNothing / 速览三段·缺段·全空不渲 / 组折叠+re-tap / skill 二组无反链段 / 大纲点击 jump 联动）+ `docGroupCollapseProvider`（默认全展/toggle 持久化跨控制器/全展全收遍历）；`time_format_test.dart` 加 `fmtRelativeDay`（今天/昨天/N 天前/数字/时钟偏移）；既有 inspector 测适配（`BACKLINKS` 大写 → `Backlinks` 组头行）。帧 `demo_documents_doc{,_fold}.png`（DOC 深链 + `DOCFOLD=<组头>` flag）。

## 批 3 落账（本单，0719）

调试台 v3 与 scheduler run 检查器刚各自重建/成型，**主体一律不碰**——只套 §1 头 + §2 速览带（两处**面板级动作皆无** → 空 `menuEntries` → 无 ⋯，「无则暂缺」诚实兑现）。

### entities 调试台（`run_terminal.dart`）
- **头**：`AnInspectorHead` → `AnPanelHead`（kind 图标 + 实体名 + ✕）；**活/失败状态徽退役**（旧 `subTrailingWidget` 徽 + `_phaseBadge` 物理删除——运行由流式体+停止钮陈述、失败由 `AnCallout`+落定条陈述、上次结果由速览带，头纯身份，chat 侧幕同律）。
- **速览带 `_glance`**：`v{N} · 今天 {n} 次执行 · 上次{结果} {耗时}`——版本号取新增的 `EntityDetailX.activeVersionNumber`（内嵌 `activeVersion.version`，无版本 kind[trigger]/未解出→null），今日执行数与上次结果从 `recentRunsProvider`（≤5 条工作台账）聚合：今日=起始落在本地当天的行计数（≤5 有界，很忙的一天会少报——工作台是速览、全史在 Logs）；上次=最新一行的落定结局（ok/completed→成功、failed→失败、cancelled→取消，running 仍在跑不算「上次」）+ `fmtDuration` 耗时。每段真数据才在（缺段不渲），全空→`null`→无带。
- 主体（`RunEditorCard` JSON 编辑器卡 / `run_example` 生成器 / `_RecentStrip` 工作台账）**零改**。
- i18n 新键 `entities.run.{glanceToday,glanceLastOk,glanceLastFailed,glanceLastCancelled}`。测 `run_debugger_test.dart` 加「head 三段式文法」组（头=AnPanelHead·无 ⋯、三段速览全渲、缺段只剩 v{N}）+ 既有 47 项零改语义。

### scheduler run 检查器（`scheduler_run_inspector.dart`）
- **现状**：右岛=`SchedulerRunInspector`（run 旗舰唯一右岛，overview/主页不揭示），已成结构——**双脸**（无节点=运行卷宗、选中节点=节点检查器）各 `AnStatBar`/`AnSection`/`AnKv` 清爽陈列，故**只套头+速览带、内容零重排**。
- **头**（共享壳 `_Face`）：`AnInspectorHead` → `AnPanelHead`（scheduler 图标 + 脸标题[卷宗/检查器] + ✕）；**⋯ 空**（replay/triage 是就地正文动作、非面板 chrome，「无则暂缺」）。
- **速览带 `_glance`**：`下次点火 {d} 后 · 近 7 天 {r}% 成功 · 连败 {n}`——run 的**父 workflow 运营上下文**，全读已挂 `schedulerRailProvider`（scheduler 海洋常驻，**零新取**=最小手术）：下次点火=rail 的 trigger-schedule 连接 `nextFireByWorkflow`（有未来 fire 才现）、成功率=`stats.successRate` 7d 窗**真实信号**（**取径取舍**：flowrun-stats **无 run 计数字段**、`recent` 珠封顶 10，故任务书「N 跑」不可诚实得——用 7d 成功率替，正是主页健康头本身之选）、连败=`stats.consecutiveFailures`（>0 才现）。每段真数据才在、全空→无带。
- i18n 新键 `scheduler.run.{glanceNextFire,glanceSuccess,glanceStreak}`。测 `scheduler_run_test.dart` 加「head 三段式文法」组（头=AnPanelHead·无 ⋯、三段速览全渲[连败 4/20% 成功/下次点火]、无 rail 数据→无带）+ 既有全绿。

## landed-into

- 原语 + 三段式立法 → [`design-system.md`](../../references/frontend/design-system.md)（§5 AnPanelHead + ★ 三段式文法）。
- chat 范例田当前形态 → [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md)（头带 §1+§2 行 + §3 分组注）。
- documents 检查器当前形态 → [`features/documents.md`](../../references/frontend/features/documents.md)（documents 单落账）。
- entities 调试台头当前形态 → [`features/entities.md`](../../references/frontend/features/entities.md)（调试台头=三段式文法 + 速览带取径）。
- scheduler run 检查器头 → 工作形态见 [`scheduler.md`](scheduler.md) §6（壳头三段式文法 + 速览带取径；scheduler 无 features/ reference 文档，随 WRK-069/070 归档时并入）。

## 收官（0719）

四批全落（chat / documents / entities 调试台 / scheduler run 检查器）——三段式文法铺满**三岛壳的四处右岛**。**唯一剩余 `AnInspectorHead` 消费方 = `workflow_editor_inspector.dart`**（全屏图编辑器的节点检查器），它是**编辑器语境**、非三岛壳右岛，**不在本战役范围**，`AnInspectorHead` 作为编辑器/画廊原语留用。`make fe-verify` + `make docs` 双绿。台账随三段式立法已全落 design-system.md，可按归档流程并入 archive。
