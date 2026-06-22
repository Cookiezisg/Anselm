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
| `typography.dart` | `AnText`——模数字阶(h1/h2/h3/strong/body/bodyProse/label/meta/mono);字族 `Inter` + 系统回退(暂回退 SF,见取舍);刻意无色(主题统一施加) |
| `tokens.dart` | 主题无关常量:`AnSpace`(s2..s64,4 网格)· `AnRadius`(tag/button/chip/card/island/pill)· `AnSize`(row=32 锚 + 2:3:6 布局列 navRail/sidebar/rightIsland/content/islandHead)· `AnMotion`(fast/mid/slow/breath + easeOut/spring) |
| `theme.dart` | `AnTheme.light()/.dark()`——由 token 装配 `ThemeData`:显式 `ColorScheme`+`TextTheme`+滚动条/tooltip/popup;`NoSplash`+紧凑密度(利落原生非 web 感);注册 `AnColors`/`AnSyntax` 扩展 |

字体:声明 `Inter`,未打包 → 回退系统(macOS=SF Pro)。打包 Inter 可获三平台一致(待定)。

## 3. UI 套件(`core/ui/`,features 只许组合这些)

**图标**:全 Lucide(`lucide_icons_flutter`),经 `AnIcons` 语义注册表(`AnIcons.function/agent/...`),**绝不直接 `LucideIcons.*`**。

**原子/分子**:`AnButton`(4 变体×2 尺寸)· `AnIconButton` · `AnBadge`(tone)· `AnChip` · `AnRefPill` · `AnKbd` · `AnKindIcon` · `AnDivider` · `AnSpinner` · `AnSkeleton` · `AnStatusDot`(5 态)。
**表单**:`AnInput` · `AnField` · `AnSearchField` · `AnDropdown` · `AnToggle` · `AnCheckbox` · `AnRadio` · `AnSegmented`。
**容器/反馈**:`AnCard` · `AnSection` · `AnTabs` · `AnCallout` · `AnEmptyState` · `AnProgress` · `AnMenu` · `AnDialog` · `AnToast`。
**数据**:`AnKvRow`+`AnInfoCard` · `AnCodeBlock`(语法高亮)· `AnJsonTree` · `AnThinTable`。
**shell 件**(见 [shell](shell.md)):`AnShell` · `AnSidebar` · `AnOceanHeader` · `AnPage` · `AnRightIsland` · `AnPeek`。

验收:`cd frontend && make gallery`(完整目录,表单可交互)。
