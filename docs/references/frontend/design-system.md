---
id: DOC-045
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端设计系统 —— token 体系 + UI 套件

> 视觉语言的单一事实源。所有颜色/度量/组件由此出,**禁内联硬编码**(CLAUDE.md 前端节)。空间布局规范见 [shell](shell.md)。

## 1. 原则:单色 chrome、彩色语义

**无装饰强调色**——强调(主操作/选中/焦点)是**墨色**(近黑)压亮面;层级靠表面深度阶梯 + 墨色阶梯。**功能色才有彩**:5 态状态(ok 绿 / warn 橙 / danger 红;run·idle 无彩)+ 代码高亮。图表黑白(节点种类靠图标 + 灰阶)。明亮通透轻盈、紧凑(行高 32)。

## 2. Token(`core/design/`)

| 文件 | 内容 |
|---|---|
| `colors.dart` | `AnColors extends ThemeExtension`——语义角色色(表面阶梯 desk/canvas/surface/subtle/hover/active · 墨 ink/inkMuted/inkFaint/onAccent · line/lineStrong/scrim · accent=墨 · ok/warn/danger + soft · 阴影)。**light + dark 双值 + lerp**。糖:`context.colors` |
| `syntax.dart` | `AnSyntax extends ThemeExtension`——代码高亮 5 色(comment/keyword/string/number/function),One Light/Dark。糖:`context.syntax` |
| `typography.dart` | `AnText`——模数字阶(h1/h2/h3/strong/body/bodyProse/label/meta/mono);字族 `MiSans`(**随 app 打包**)+ 系统回退;刻意无色(主题统一施加) |
| `tokens.dart` | 主题无关常量:`AnSpace`(s2..s64,4 网格)· `AnRadius`(tag/button/chip/card/island/pill)· `AnSize`(row=32 锚 + 2:3:6 布局列 navRail/sidebar/rightIsland/content/islandHead)· `AnMotion`(fast/mid/slow/breath + easeOut/spring) |
| `theme.dart` | `AnTheme.light()/.dark()`——由 token 装配 `ThemeData`:显式 `ColorScheme`+`TextTheme`+滚动条/tooltip/popup;`NoSplash`+紧凑密度(利落原生非 web 感);注册 `AnColors`/`AnSyntax` 扩展 |

字体:`MiSans`(demo 首选字族)**作为变量字体随 app 打包**(`frontend/assets/fonts/MiSansVF.ttf`,经 `pubspec.yaml` 声明 `family: MiSans`;一套覆盖 Latin + 简体中文,引擎按 `TextStyle.fontWeight` 取其 `wght` 轴)。打包=双语 UI 全平台**确定渲染**,不随机器装了什么漂移(免对齐之苦)。回退链仅兜 MiSans 缺的字形。

## 3. UI 套件(`core/ui/`,features 只许组合这些)

**图标**:全 Lucide(`lucide_icons_flutter`),经 `AnIcons` 语义注册表(`AnIcons.function/agent/...`),**绝不直接 `LucideIcons.*`**。

**原子/分子**:`AnButton`(4 变体×2 尺寸)· `AnIconButton` · `AnBadge`(tone)· `AnChip` · `AnRefPill` · `AnKbd` · `AnKindIcon` · `AnDivider` · `AnSpinner` · `AnSkeleton` · `AnStatusDot`(5 态)。
**表单**:`AnInput` · `AnField` · `AnSearchField` · `AnDropdown` · `AnToggle` · `AnCheckbox` · `AnRadio` · `AnSegmented`。
**容器/反馈**:`AnCard` · `AnSection` · `AnTabs` · `AnCallout` · `AnEmptyState` · `AnProgress` · `AnMenu` · `AnDialog` · `AnToast`。
**数据**:`AnKvRow`+`AnInfoCard` · `AnCodeBlock`(语法高亮)· `AnJsonTree` · `AnThinTable`。
**shell 件**(见 [shell](shell.md)):`AnShell` · `AnSidebar` · `AnChromeBar`(顶栏条,中心对齐红绿灯)· `AnWindowControls`(窗控前导:macOS 留位 / Win·Linux 产品标)· `AnOceanHeader` · `AnPage` · `AnRightIsland` · `AnPeek`。

验收:`cd frontend && make gallery`(完整目录,表单可交互)。

## 4. Motion 标准(动效铁律)

动效**唯一时长/曲线来源 = `AnMotion`**(`core/design/tokens.dart`),分级用途固定,**禁内联 Duration/Curve**。基调:轻盈、利落、有节制——服务清晰,不炫技。

| 用途 | token | 说明 |
|---|---|---|
| 微交互(hover / press / focus) | `AnMotion.fast`(120ms) | 行/按钮/控件的状态过渡。**off 态用同色相 0-alpha**(如 `surfaceHover.withValues(alpha:0)`)补间,**绝不从 `Colors.transparent`(透明黑)补**——会中途闪暗(已踩坑) |
| 内容转场(切实体/切视图) | `AnMotion.mid`(240ms)+ `easeOut` | `AnimatedSwitcher` 交叉淡入,按内容 id `key` 触发(见 `entities_page.dart`) |
| 结构转场(岛收合/滑入) | `AnMotion.slow`(340ms)+ `spring` | 左岛收合、右岛滑入、宽度动画;拖拽中 `duration: Duration.zero`(不补间、跟手) |
| 持续脉动(运行状态) | `AnMotion.breath`(1.8s) | `AnStatusDot` run 态呼吸(仅 run 态建/跑控制器,见其 initState——非 run 态不建,避免 dispose 期建 Ticker 崩) |

原则:① 动效靠 token、不内联;② hover off 态用 0-alpha 同色;③ 无限动画用固定 pump(测试)/`TickerMode` 谨慎(截图);④ 尊重系统"减少动效"(`MediaQuery.disableAnimations`,后续接入)。

**覆盖(动效审计)**:hover/press —— `AnButton`/`AnIconButton`(animationDuration)·`AnRow`/`AnChip`/`AnRefPill`(AnimatedContainer)。选择/切换 —— 左岛 nav pill(`AnimatedSize` spring 展开标签)·`AnTabs`(下划线+字色淡变)·`AnSegmented`/`AnToggle`/`AnCheckbox`/`AnRadio`(AnimatedContainer)。内容 —— entities 详情交叉淡入(`AnimatedSwitcher`)。结构 —— 岛收合/右岛滑入(spring)、紧凑标题淡入。持续 —— `AnStatusDot` run 呼吸 / `AnSkeleton` 微脉。**新交互组件须按本表挂上对应级动效,不留瞬时跳变。**
