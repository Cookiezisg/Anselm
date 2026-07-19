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

# 右岛三段式文法 —— 全右岛收敛战役（台账 · 在建）

> 用户 0719 裁决：全 App 右岛「小灰标题 + 平坦大块」寡淡（Activity 头无 icon、右侧四钮杂）。经调研（**Linear 删标题派** / **Figma·GitHub 信息组头派**）拍板 **三段式文法**，分四批全右岛铺开。**批 0+1 已落**；批 2/3 open。落地形态陈述见 [`design-system.md`](../../references/frontend/design-system.md)（AnPanelHead + 三段式立法）与 [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md)（chat 范例田）。

## 总纲：三段式文法

1. **§1 身份头**：`icon + 标题 + ⋯ + ✕` 一行，全右岛统一，**面板级动作全收 ⋯**（右侧永远至多两钮）。原语 = `AnPanelHead`（core/ui）。
2. **§2 速览带**：头下一行安静数字速览（如「12 触点 · 3 执行 · 1 待你处理」）——**零人话律 = 有真信号才在**（无信号不渲、绝不硬凑）。不造新原语，一行 `AnText.meta` + `·` 分隔文法，传 `AnPanelHead.sub`（`null` = 无带）。
3. **§3 分组内容**：平坦长列表 → 可折叠组，组头 = **AnRow 组头文法**（常驻箭头 lead + 计数 meta、无 ⋯，今日托盘/左岛 Pinned·Recents 同款）——**左岛 / 托盘 / 右岛三处一种语言**。

## 四批建造顺序

| 批 | 范围 | 状态 |
|---|---|---|
| **批 0** | 地基：`AnPanelHead` 原语（core/ui + gallery 样章）+ 速览带文法判断 + design-system.md 三段式立法 | ✅ 已落 |
| **批 1** | chat「活动」侧幕范例田：头换 `AnPanelHead`、⋯ 收编（跟随三档·全展开·全收起）、速览带、顶层分组 | ✅ 已落 |
| **批 2** | documents 右岛：三孤儿标题并一头三组 | ⏳ open |
| **批 3** | entities 调试台 + scheduler 右岛迁移 | ⏳ open |

## 批 0+1 落账（本单，0719）

### 地基（批 0）
- **`AnPanelHead`**（`lib/core/ui/an_panel_head.dart`，导出于 `ui.dart`）：`icon`（必填身份字形）+ `title` + `menuEntries: List<AnMenuEntry>`（空→无 ⋯，退役「四钮杂」）+ `menuSemanticLabel` + `sub`（速览带槽，`null`=无带）+ `onClose`/`closeSemantics`。**几何守右岛内距单源律**（同 `AnInspectorHead`：岛壳 12 唯一、头前导 0，icon/标题落岛 pad 缘 = 岛 +12；下方行族各缩 s8 → 头以一档超顶列表）。gallery 样章三态（⋯+速览带 / 无 ⋯ 无带 / 超长标题省略）。测锁 `test/core/ui/an_panel_head_test.dart`。
- **速览带**：**不造新原语**（判断结论）——就是 `_glance(context, ref, cid)`（`stage_panel.dart`）产出的一行 `AnText.meta` `·` 分隔文法，传 `AnPanelHead.sub`。
- **design-system.md**：§5 加 `AnPanelHead` 原语条 + **★ 三段式文法** 立法（三段各自律 + 零人话律 + 组头复用 AnRow）。

### chat 范例田（批 1）
- **头**（`StagePanel`）：`AnInspectorHead` → `AnPanelHead`（icon `AnIcons.activity` + 标题 `chat.stage.island`）；旧四小钮（`_FollowMenu`/`_ExpandAllButton`/`_CollapseAllButton`）**物理删除** → `_panelMenuEntries`（跟随三档单选勾 + 展开全部[顺手 `openAll` 掀组] + 收起全部）收进 ⋯。
- **速览带**（`_glance`）：N=触点台账实体数、M=执行过实体数（`byVerb` 含 `executed`）、K=`pendingInteractionsProvider` 待决数；每段 `>0` 才现、全零 `null`。i18n 新键 `chat.stage.{glanceTouched,glanceExecuted,glanceNeedsYou}`。
- **顶层分组**（`_computeItems` + `_GroupHead` + `stageGroupCollapseProvider` + 纯分类器 `sidestageTierKey`）：落定 Cast 按**时间三档**折叠（刚刚/早些时候/更早，键 = `lastAt`）；组头 = icon-free collapsible `AnRow`（常驻箭头 + 计数、无 ⋯）；档序刚刚→早些时候→更早、档内最新先；**两条防碎律**（①空档免头 ②单档全裸行）；**todo + 活/委派层（合成 live·落定 subagent）恒不分组置顶**；档折叠态与行级 `stageExpansionProvider` **正交**；**含 live/自动展开行的档强制展开**（深跳/auto-expand 绝不藏活）。i18n 新键 `chat.stage.{groupJustNow,groupEarlierToday,groupEarlier}`。测 `stage_grouping_test.dart`（纯分类器三档分界 + 空档免头 + 单档裸行 + 折叠 + 深跳强制展开 + 跨天）+ `stage_panel_test.dart` 适配。

### 分组轴取舍（两轮）
**第一轮 = kind（已否决）**：授权「读现状选最自然的轴」下我选了 kind（robust + 语义上一实体只属一 kind + 合「信息组头派」）。**用户 0719 看中间态当面否决**——「12 条内容 10 个组头，组头比内容多」的**目录病**（demo/短对话每 kind 常 1 个，kind 轴碎成一堆单行组，比平坦列表更糟）。
**第二轮 = 时间三档（定案）**：照**通知托盘的精神**、**用对话的刻度**——**刚刚**（本回合，最近一次用户发言以来）/ **早些时候**（今天更早）/ **更早**（跨天）；键 = 行的最后触碰时间。**两条防碎律**根治目录病：短对话（全「刚刚」）回落干净一列（单档裸行），长对话自动分层。
**「刚刚」取径**：R-14 回合锚**首选但取不到**——`hydrateTurn` 丢 `createdAt`、`BlockNode` 无时间戳，回合边界在 ledger/transcript 节点数据上无法取；按用户授权的退化取径用**固定 10-min 窗**代「本回合」（`stageJustNowWindow`）。日界（早些时候 vs 更早）= 本地日历天。分类器 `sidestageTierKey` 纯函数、注入 `now` 可定测（三档分界 + 10-min 边界 + 跨midnight 归「刚刚」全锁）。

## landed-into

- 原语 + 三段式立法 → [`design-system.md`](../../references/frontend/design-system.md)（§5 AnPanelHead + ★ 三段式文法）。
- chat 范例田当前形态 → [`features/chat-sidestage.md`](../../references/frontend/features/chat-sidestage.md)（头带 §1+§2 行 + §3 分组注）。

## open（批 2/3，本单不做）

- **批 2 documents**：三孤儿标题（大纲/属性/backlinks）并一 `AnPanelHead` 头 + 三组。
- **批 3 entities 调试台 + scheduler**：右岛迁 `AnPanelHead`（注意与 relation-graph 单 / 调试台 v3 单的冲突纪律）。
- 其余右岛（`AnInspectorHead` 消费方：documents/scheduler/entities/run 终端）择机迁 `AnPanelHead`——**本单不动**（AnInspectorHead 留用至迁移批）。
