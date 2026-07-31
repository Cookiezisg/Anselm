---
id: DOC-045
type: reference
status: active
owner: @weilin
created: 2026-06-25
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 前端设计系统——Token、An* 原语与组合纪律

> 代码事实位于 `frontend/lib/core/design/`、`core/ui/`、`core/editor/`、`core/media/` 与 gallery。完整导出清单以 `core/ui/ui.dart` 为准；本篇维护选择规则和稳定语法，不复制每个构造函数。

## 1. 层级

```text
design tokens
    ↓
An* primitives
    ↓
feature compositions
    ↓
AppShell
```

- `core/design` 是颜色、排版、间距、圆角、尺寸、阴影和动效时长的唯一值源。
- `core/ui` 提供可组合、可测试、可访问的 An* 原语。
- feature 只组合原语并注入业务数据，不私铸同义按钮、卡、行、弹层或状态色。
- app 只装配壳，不发明 feature 视觉语法。

## 2. 核心原则

1. **内容优先**：容器只在表达分组、可操作边界或材质时出现；不为“填满”制造卡片。
2. **一义一件**：同一交互在全 app 使用同一原语和几何，例如行、状态点、确认框、展开、tooltip。
3. **色有语义**：accent 表选中/主动作，tone 表状态；不把蓝色拿来装饰普通信息。
4. **真实空态**：零计数、无 inspector、无历史时允许缺席，不用墓碑文案冒充内容。
5. **布局不跳**：hover/focus/action 揭示预留几何；编辑、loading、selected 切换不得推挤邻项。
6. **动效可停**：循环动效仅用于真实在途；settled 状态零 ticker；reduced motion 双闸覆盖位移和装饰循环。
7. **桌面原生**：键盘、焦点、右键、拖放、窗口缩放与平台控件遵循 Flutter/OS 机制，不用手搓近似物。
8. **诚实性能**：懒构建、定长投影、局部 repaint 与缓存写入规格；不能用“零重建”等不可证说法。

## 3. Token

| 族 | 代码 | 规则 |
|---|---|---|
| 颜色/主题 | `colors.dart`、`theme.dart` | feature 不写 hex；明暗主题都从语义色取值 |
| 排版/字体 | `typography.dart`、`an_fonts.dart` | UI、内容、代码三轴；fallback 保证中英文与 mono |
| 空间/尺寸 | `tokens.dart` 的 `AnSpace`、`AnSize`、`AnInset` | 不散落像素；壳、行、控件使用命名档 |
| 圆角/阴影 | `AnRadius`、`AnShadow` | 岛、窗、卡、chip 分层，禁止嵌套同权重容器 |
| 动效 | `AnMotion` | 使用标准时长/曲线，并检查 reduced motion |

## 4. 选择原语

| 任务 | 使用 |
|---|---|
| 普通/危险/图标动作 | `AnButton`，组合动作使用 `AnActionGroup` |
| 左岛或台账可选行 | `AnRow` / `AnLedgerRow` |
| 设置行与纵向字段 | `AnSettingRow` / `AnFormField` |
| 状态、空、错、加载 | `AnStatusDot`、`AnState`、`AnSkeleton`、`AnSpinner` |
| 内容容器 | `AnWindow`、`AnCard`、`AnInfoCard`；避免窗套窗 |
| 内联元数据 | `AnChip`、`AnRefPill`、`AnPathChip`、`AnKeycap` |
| 编辑 | `AnInput`、`AnInlineEdit`、`AnCodeEditor`、`AnEditor` |
| 展开与过渡 | `AnExpandReveal`、`AnFadeCollapse`、`AnContentIn` |
| 菜单/浮层/确认 | `AnMenu`、`AnPopover`、`AnTooltip`、`AnDialog` / `core/overlay` |
| 页面/壳/岛 | `AnPage`、`AnIsland`、`AnShell`、`AnOceanHeader`、`AnPanelHead` |
| 复杂数据 | `AnProseTable`、`AnThinTable`、`AnJsonTree`、`AnVersionDiff` |
| 图与运行 | `AnGraphCanvas`、`AnRelationGraph`、`AnNodeGantt`、`AnRunBoard`、`AnRunMatrix`、`AnScheduleTrack` |
| 媒体 | `core/media` 的共享媒体卡、查看器与播放控制 |
| 即时消息 | `AnNotice*` 族 + `NoticeCenter`，不用旧 toast |

若 `ui.dart` 已有语义相同的件，先扩展它；新增原语前在 gallery 覆盖静息、hover、focus、disabled、loading、error、长文案和 reduced motion。

## 5. 三岛语法

- 左岛承载海洋切换、当前 rail、workspace/settings/notification 入口；rail 使用固定行语法和虚拟化列表。
- 中心海洋使用 `AnPage` 的单一滚动与阅读列；页面头、tab 与正文不能拆成互相漂移的滚动事实。
- 右岛使用三段式：`AnPanelHead` 身份头、可选速览带、可折叠内容组。无真实选区或证据时整岛可缺席。
- App 顶带只有一个即时消息舞台；确认框是 overlay，durable 通知是左岛账本，三者不可互换。

## 6. 行、焦点与可访问性

- 整行点击与行内按钮必须是不同命中节点；行内点击不得冒泡触发选中。
- hover 揭示不能成为唯一入口：键盘 focus 同样揭示，或提供等价菜单。
- 可编辑件在 pointer 完成后释放焦点，键盘 Enter/Esc 则回到稳定导航点。
- 大型二维控件使用 roving focus：整个控件一个 Tab 停靠，方向键在内部移动，越界交还框架。
- semantics 说完整任务与状态，不逐像素复读装饰；读屏聚合大型矩阵/图的结构摘要。
- reduced motion 时禁位移和无限装饰循环，但不移除状态变化本身。

## 7. 流式、代码与媒体

- 流式文本/工具结果只重建活动叶，settled 叶保持 identity。
- `AnLiveTail` 对输入做有界 tail slicing；终端、mono、prose 使用各自样式，不把 MB 缓冲整段排版。
- `AnCodeEditor` 是代码输入/展示单一表面；语法高亮、行号、copy、软换行策略不由 feature 重做。
- Markdown 的 Chat 只读面与 Library 编辑面共享语义语料和表格/token。
- 图片、音频、视频和生成产物按附件元数据分派；所有产品面复用同一 viewer/player chrome。

## 8. 验证

| 层 | 入口 |
|---|---|
| 原语单测 | `frontend/test/core/ui/` |
| 设计/token 守卫 | `frontend/test/core/design/`、`frontend/test/guards/` |
| 编辑器与 markdown | `frontend/test/core/editor/`、`markdown_parity_test.dart` |
| gallery 人眼矩阵 | `make -C frontend gallery` |
| 真壳组合 | `make -C frontend demo` |
| 完整门禁 | `make -C frontend verify` |

已完成原语的逐轮施工记录只在 `docs/archive/`；current feature reference 只链接本篇的稳定语法，不把历史批次重新带回当前事实面。
