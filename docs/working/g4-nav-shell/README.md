---
id: WRK-039
type: working
status: active
owner: @weilin
created: 2026-06-24
reviewed: 2026-06-24
review-due: 2026-09-22
audience: [human, ai]
landed-into:
---

# WRK-039 — G4 导航与壳 建造规范

> G4 开工前调研产物(11-agent 扇出:逐件 demo 盘点 + kit 复用 + 联网 best-practice → 架构综合 → 2 镜对抗复审)。
> 用户 2026-06-24 拍板 4 决策。建造规范、单一作者、gallery-first、逐组提交。结论随件 landed 进
> `references/frontend/design-system.md` 后归档(同 WRK-037/038 先例)。

## §0 一句话

把已落的三岛骨架(`AnShell`/`AnIsland`/`AnWindowControls`,G0)从占位升级为可运营的壳,并补齐 **7 个命名原语**。
**复用优先**是本组主轴:`AnSidebarList` 骑在 `AnRow` 上、`AnToolbar` 骑在 `AnActionGroup` 上、`AnOceanHeader`
骑在 `AnInlineEdit`+plain Row 上、`AnTabs` 骑在 `AnInteractive`+`IndexedStack` 上。仅 **2 个新共享原语**。

**已核对的 AnShell 现状**:`Material(surface) → Padding(8) → Row[ SizedBox(_leftW)+AnIsland(sidebar 含 _ChromeBar) | _Grip(拖 240–400) | Expanded(ocean=Placeholder) | gap | SizedBox(320)+AnIsland(inspector=Placeholder) ]`。已有左岛拖拽;缺:左岛 collapse+持久化、浮动海洋头、右岛 reveal。tokens 齐(content=720 / islandHead=44 / controlSm=24 / oceanMin=480 / rightIsland=320 / windowMin=1232),仅缺 `AnSize.tab`。

## §1 锁定决策(用户 2026-06-24 拍板)

1. **右岛内容壳命名 = `AnInspector`**。它只渲 head+body,**不画岛皮、不管宽**(皮和宽由 `AnShell`/`AnIsland` 负责)。叫 `AnRightIsland` 会误导后人以为它画岛 → 双画皮/双管宽。
2. **AnRow 键盘展开提升 = 是(窄版)**。仅让 `AnRow` 在 `collapsible` 时把 `expanded` 透给已接好的 `AnInteractive.expanded`(屏读播报「已展开/已折叠」)。**方向键树导航留在 `AnSidebarList` 的 roving-focus 控制器,不塞进 `AnRow`**(避免双键盘属主)。改动须重跑 AnRow 全测 + 每个 AnRow 消费 specimen,门控在既有 `collapsible` 旗下(非 collapsible 行方向键照样冒泡)。
3. **OceanHeader 大标题就地改名 = 是 → 参数化 `AnInlineEdit`**。给 `AnInlineEdit` + `AnSeamlessField` 加 `style`(TextStyle)+ `minHeight` 旋钮(默认值保持现有 body/control 行为不变),让 H2(24px / islandHead 高)标题能就地改名而字号不跳。这是对**已发布原语的跨切改动**,须 WRK 明列、重跑其测试,非静默 bolt-on。
4. **AnWireList = 推迟到 graph-editor 批**。它实为 key→CEL form-array、**零壳依赖**、误归 nav/shell;唯一消费者是后期 graph-editor 节点 inspector + branch editor。和真实消费者一起建(否则现在凭空敲定 onChanged payload 形状)。

**清晰推荐-即锁定**(技术上无争议,反对再议):
- **一律手搓、拒 Material**:`AnTabs`(TabBar 的 ink 波纹 / M3 indicator / 46–72px 高 / 3.32「children must have tab role」异常 / 桌面屏读遍历自动切 tab 的 bug,与本 kit 明亮单色 2px ink slider 根本冲突);`AnToolbar`(非 AppBar/kToolbarHeight=56);`AnOceanHeader`(非 SliverAppBar,它是内容流首块非壳级浮动头)。
- **`AnPage` 滚动条 = `RawScrollbar`**(框架官方 overlay,**勿照搬 demo 的 rAF thumb 数学 + 700ms idle-hide**——原则 #8、本项目手搓窗口 chrome 反复跌跟头)。
- **导航状态 = 本批不引 `go_router`**(已核 pubspec 无此依赖)。7 组件是 ZERO-router 纯 callback/prop widget(gallery-first 单作者)。app 装配阶段再定:Riverpod 持导航 INTENT + selected-ocean STATE,`go_router StatefulShellRoute.indexedStack` 持路由树/URL/back-stack(scroll/selection 恢复须 keepAlive provider 或 PageStorage 主动持,**非** indexedStack 自带)。
- **多 pane 布局 = 保留 `AnShell._Grip`**(单拖柄已正确;拒 `panes`/`resizable_columns` IDE 级 N-pane overkill)。

## §2 新共享原语(仅 2 个)

- **`AnMenu`**(`core/ui`,on `AnPopover`):命令/浮层菜单 = section label 行 + per-item 勾选(多选 toggle)+ danger/disabled 风味。消费者:sidebar sliders(Sort / Display)、row-more 动作、壳 head ⋯ 菜单。demo 有专门 `menu.js`。
- **`AnScrollBehavior`**(`core/design` 或 `core/ui`):`ScrollBehavior` 子类 override `buildScrollbar` 抑制桌面自动 Scrollbar。**仅局部应用**(`ScrollConfiguration` 包住 AnInspector body、sidebar 树等需隐藏滚动条的可滚区),**绝不 app-root 全局**——否则碾压 `AnPage` 的 RawScrollbar 故意 overlay + 未来 feature 可滚区(复审 footgun)。

## §3 跨切依赖(改已发布原语,须重跑其测试)

- **AnRow 窄提升**(决策 #2):`collapsible ? expanded: open : null` → `AnInteractive.expanded`。删 `an_row.dart` 的 false-promise 注释。重跑 `an_row_test` + `an_row_detail_test` + 每个 AnRow specimen。
- **AnInlineEdit 参数化**(决策 #3):`AnInlineEdit` + `AnSeamlessField` 加 `style` + `minHeight`(默认不变)。重跑 `an_inline_edit_test` + `an_seamless_field`/`an_editable_value` 相关测试(确认默认行为零回归)。

## §4 HIGH 正确性铁律(复审拦下,build 时必守)

- **AnTabs `SemanticsRole.tabBar` 只挂 tab-strip Row**,其子**恰为** tab 按钮(下划线 slider `ExcludeSemantics`、滚动 viewport、IndexedStack body 都不在该节点子集内)——否则 3.41.9 的 `_semanticsTabBar` debug 断言「Children of TabBar must have the tab role」**崩**,gallery_matrix 的 `takeException` 必抓。每 tab 的 `AnInteractive` 带 `selected:true`+onTap 过 `_semanticsTab`。隔离不干净就**降级为 button+selected+「N of M」label,不半挂**。
- **`GallerySpecimen` 加 `height` 字段**(地基增强,#8):matrix host 给**无界高**,凡根部高贪婪的件(AnPage / AnTabs(Expanded IndexedStack)/ AnInspector(Expanded scroll body)/ AnSidebarList(Expanded ListView))一 pump 即「Vertical viewport unbounded height」/ RenderFlex 溢出。给这些 specimen 有界高(如 360)+ 一条大高度无溢出断言验滚动路径。
- **AnToolbar 中区贴内容、非贪婪 `Expanded`**:demo `grid-template-columns: auto 1fr auto`,中区 `.main` 是 `inline-flex` content-hug + `overflow:hidden`,**不是** greedy Expanded(`Row[w, Expanded, w]` 不等价、左右不对称会移位)。按 demo:`Row[leading, gap, title(Flexible ellipsis)+meta, Spacer, trailing]`。
- **`AnTwoZone(meta:null)` 不是真 no-op**:meta 分支虽跳过(cap 无害),但 trailing 前**恒插 8px SizedBox**。故 **AnInspector head 与 OceanHeader crumb 行不走 AnTwoZone**,用 plain `Row[icon?, Expanded(label ellipsis), trailing]`(无 meta 区可 cap、无第二消费者要共享骨架,复用-为-复用反拖入多余 gap)。
- **AnInspector landmark role**:`SemanticsRole.complementary` 在 3.41.9 存在,但有「须唯一非空 label + 不得嵌另一 landmark」断言;headless 变体无 head=空 label → 第二个 complementary 共存即崩。**kit v1 不挂 landmark role**(尚无第二消费者,entity-workspace 已推迟),app 装配阶段连同 main/nav/complementary 全景一起设。仍带 `AnInteractive` 已给的 button+selected+localized label 兜底。

## §5 逐件建造计划 + 复用图

| 件 | 复用骑乘 | 要点 |
|---|---|---|
| **AnToolbar** | `AnActionGroup`(左 start / 右 end,逐项 Wrap)· `AnText.strong/body`(title w600)+`meta` | 三区 Row(中区贴内容非贪婪,见 §4);`bordered` 时底 hairline + island bg + pad;`compact` 高 control(28)否则 row(32)。 |
| **AnInspector** | `AnIsland` 皮由 AnShell 供(勿加第二套皮)· plain Row head(§4)· `AnScrollBehavior` body | head(islandHead 44)+ 滚动块流 body + headless 变体(无 head);headless 用 stub specimen 测。v1 无 landmark role。 |
| **AnPage** | `RawScrollbar`(thumb=lineStrong / radius pill / thickness s4)· `Center`+`ConstrainedBox(content 720)` | 单滚动区 + 居中内容列 + 头净空 pad(top s12 / LR s24 / bottom s48);为后续滚动宿主。 |
| **AnMenu** | `AnPopover`(OverlayPortal,点外/Esc 关) | section label + 多勾 toggle + danger/disabled。 |
| **AnTabs** | `AnInteractive`(每 tab,hover/focus/激活/disabled+focus ring)· `IndexedStack`(panes keep-alive,等价 demo「hide 不销毁」)· `AnMotion.spring`+`AnMotionPref.reduced`(下划线)· `AnSize.tab=34`/`gripLine=2`(slider) | 受控件(value+onPick);水平滚动 strip(hidden scrollbar)+ `AnimatedPositioned` 下划线**在滚动内容坐标系**(随 tab 滚)+ roving-focus(方向键 Left/Right/Home/End wrap,手动激活避自动切-on-traverse bug)。count 徽标留槽推迟。 |
| **AnSidebarList** | `AnRow`(entity 行 / type head passive collapsible / 递归 branch,depth/collapsible/open/selected/dot/icon/meta/hint/actions 全已支持——**最大复用**)· `ListView` · `AnMenu`(sliders)· `AnInput` seamless(filter) | 先 `SidebarModel` 纯模型 + 单测(5-battery 含 injection/CJK/ancestor-reveal),再 widget。filter Escape 清 query、不 auto-scroll(匹配 demo)。常见 entities 2 级、仅 documents 真深递归。 |
| **AnOceanHeader** | 参数化 `AnInlineEdit`(标题就地改名,决策 #3)· plain Row crumb(§4)· `AnActionGroup(end)` · `AnBadge`+`AnStatusDot`+`AnTone`(meta) | Column[crumb 行 + H2 标题行(可改名)+ meta Wrap];静态版(滚动折叠联动留缝,§6)。 |
| **AnShell 扩展** | `AnShell`/`AnIsland`/`AnWindowControls`(扩展非替换)· `AnButton`/`AnActionGroup` · `AnMenu`(⋯)· `AnState`(海洋占位)· `shared_preferences` | (a)左岛 collapse+持久化 leftW/collapsed;(b)浮动海洋头 = ocean 上 Stack overlay(scrim 渐变 + compact title + model 槽 + ⋯ 菜单 + panel-right);(c)右岛 open/closed reveal(AnimatedContainer 0↔320 + 阴影)。 |

## §6 建造顺序(单作者、gallery-first、依赖序)

0. **地基**:`AnScrollBehavior` + `AnSize.tab=34`(已核 demo tokens.css)+ 新 i18n keys + **`GallerySpecimen.height` 字段**(§4)。
1. **AnToolbar** — 最薄,先落建 gallery+matrix 节奏。
2. **AnInspector** — on AnIsland 皮 + AnScrollBehavior + plain Row head;headless stub 测。
3. **AnPage** — on RawScrollbar;为后续滚动宿主。
4. **AnMenu** — on AnPopover;sidebar sliders + 壳 ⋯ 依赖它,先于 sidebar。
5. **AnTabs** — on AnInteractive+IndexedStack+下划线+roving focus(§4 铁律)。
6. **AnRow 窄提升**(决策 #2)— 改 AnRow + 重跑全测 + 每个消费 specimen。
7. **AnInlineEdit 参数化**(决策 #3)— style+minHeight,改 AnInlineEdit+AnSeamlessField+测试。
8. **AnSidebarList** — 最重:SidebarModel 纯模型+单测,再 widget on AnRow+ListView+AnMenu+AnInput。
9. **AnOceanHeader** — on 参数化 AnInlineEdit + plain Row crumb;静态(联动留缝)。
10. **AnShell 扩展** — 左岛 collapse+持久化、浮动海洋头 overlay、右岛 reveal;依赖 AnMenu/AnPage/AnInspector 全落。
- (推迟)**AnWireList** → graph-editor 批。

## §7 推迟(kit ≠ feature)

- **AnWireList** → graph-editor 批(决策 #4)。
- **AnEntityWorkspace / AnModelPicker** → chat feature(G4 出 AnInspector 壳 + headless 变体,feature 在其内建)。
- **AnBlockTree / AnComposer / AnGraphCanvas / AnRunBoard 等 11 真复合件** → 各自 feature(step3 既定)。
- **OceanHeader↔shell 滚动折叠联动** → 壳/AnPage 接线阶段(本批仅留 Riverpod/ScrollController offset hook 缝;OceanHeader 只出 resolved-title,offset 阈值 collapse 决策归 AnPage 滚动宿主下游,OceanHeader 无 scrollable)。
- **AnInlineEdit wrap 模式 / AnTabs count 徽标 / AnTabs 垂直 / AnSidebarList TreeSliver 虚拟化深树 / 480 宽 deep-read inspector** → 超 demo floor 或非 G4 scope。

## §8 已解(复审核实,免 build 时再查)

- `AnSize.tab = 34`(demo `--tab-h:34px`,**有意比 row(32)高 1u**,非派生)。
- `SemanticsRole.tab/tabBar/complementary` 在 3.41.9 **存在**(sky_engine semantics.dart),无须降级——但带结构断言(§4)。
- `AnTwoZone(meta:null)`:cap 真 no-op(guard),但恒插 8px trailing gap → meta-less head 用 plain Row(§4)。
- 右岛宽 = **320**(非 demo 360)、拖范围 **240–400**(非 demo 420)——G0 既定决策,勿「改回 demo」。

## §9 build 时真机/核值(verify-by-real-run)

- `RawScrollbar` 显隐策略(默认 scroll 显隐 vs demo hover 全页显)— 真机 macOS/Impeller 截图验,不够才 MouseRegion→thumbVisibility。
- 浮动海洋头 scrim 渐变(IgnorePointer 渐变 + 角控件 pointer-events)在 Impeller 的 hit-test 路由 — 壳扩展时真机验。
- 所有 a11y(tab/complementary/header role + VoiceOver 播报)— **真机 VoiceOver 验**,勿仅 headless 测就声称完成。

## 附:导航/焦点/键盘/动画 跨切约定

- **焦点分层**:每 pane 包 `FocusTraversalGroup`(Tab 留 pane 内);整壳 `FocusScope`(无 trap);跨 pane 跳(Cmd/Ctrl+1/2/3)经 `Shortcuts`→`focusInDirection`,落壳/app 层(随路由推迟),**不 bake 进** AnTabs/AnSidebarList。
- **键盘激活**:`AnInteractive` 已统一 Enter/Space 激活 + 仅键盘 focus ring;tab 按钮 / New / group head / rows / toolbar 动作全经它。AnTabs/AnSidebarList 的 inter-child 方向键用 `DirectionalFocusIntent`/`Shortcuts`+roving focusNode(WAI-ARIA tabs/tree,手动激活 = arrow 移焦 / Enter 激活,避 Flutter 自动切-on-traverse bug)。
- **动画**:全经 `AnMotionPref.reduced` 闸(下划线 / thumb 淡入 / chevron 旋转+hover tint / 岛滑动);reduced→`Duration.zero`;gallery_matrix reduced 轴断言无动画(否则 pumpAndSettle 超时)。
- **滚动条两诉求拆清**:AnPage 要 overlay thumb(RawScrollbar);AnInspector/sidebar 要彻底隐藏(AnScrollBehavior 局部)——非同件勿混;`primary:false` 让 inspector/sidebar 不抢海洋方向键滚动。
- **i18n**:所有发布字符串(New/filter placeholder/crumb/Sort/Display/aria label)经 slang `context.t`;gallery specimen dev-only 豁免。
- **测试矩阵**:每件 gallery specimen + matrix(build / no-overflow / escape-safe / renders / disabled-keyboard-passthrough)+ 5-battery(empty/long/many/extreme/injection);有状态件用 `_XxxDemo` StatefulWidget 持态。
