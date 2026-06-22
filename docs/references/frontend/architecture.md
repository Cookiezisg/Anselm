---
id: DOC-044
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端架构 —— Flutter 桌面端的物理结构（重建中）

> 前端已从 0 重建（见 git：`frontend-rebuild` 分支）。本篇是重建的**第 0 篇**:分层、文件住哪、纪律。
> 决策依据 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md)；工程规范见 [`CLAUDE.md`](../../../CLAUDE.md) 前端守则 + 设计原则。设计系统 / 契约 / SSE / shell 各篇随对应代码落地后填充。

## 1. 一句话

Go 后端作 **sidecar**,Flutter 桌面端是其纯客户端。**3-tier feature-first**:`core`(跨切共享)→ `features`(各域)→ `app`(装配根 + shell)。**无 use-case/domain 层**——Go 二进制即用例,DTO 都是后端投影。

## 2. 物理结构（`frontend/lib/`，当前已落地 = 骨架）

```
main.dart                  # 入口:scaled binding(应内缩放)→ initWindow → 恢复缩放档 → runApp(ProviderScope(AnApp))
app/                       # 装配根
  app.dart                 # 根 widget(MaterialApp + 主题 + home=AnShell;绑 Cmd +/-/0 缩放)
  window_setup.dart        # 桌面窗口:window_manager(尺寸/最小/居中)+ macos_window_utils(无边框 + 加高标题栏红绿灯)
core/                      # 跨切共享层(不依赖上层)
  design/                  # tokens · colors · typography · theme —— 唯一值源,禁内联 px/hex/ms
  platform/                # OS 缝:host_platform(dart:io 收口)· window_zoom(应内 Cmd +/- 缩放)
  ui/                      # An* 原语:an_island · an_window_controls · an_shell（套件随 gallery 扩充）
features/                  # ★中间层:每域 data+state+ui+model（随 feature 落地）
```
**dev 工具**:截图夹具 `test/dev/capture_shell.dart`(无头渲染 PNG 看效果);产物 `test/dev/out/` **gitignore**。

## 3. 依赖规则（三层，单向）

`app → features → core`。**features 互不依赖**(跨片走 core provider / 导航 intent);`core` 不依赖上层。UI 只用 `core/ui` + `core/design` 组合,**禁内联配色/度量**。

## 4. 设计系统（`core/design`，单一值源）

- `tokens.dart`(主题无关:`AnSpace`/`AnRadius`/`AnSize`/`AnMotion`)· `colors.dart`(`AnColors` ThemeExtension,明暗双值 + lerp,值镜像 demo `tokens.css`)· `typography.dart`(`AnText`,**打包 MiSans 变量字体**)· `theme.dart`(装配 `ThemeData`)。
- **单色 chrome + 功能色**:无装饰强调色(`accent`=墨);保留状态语义(ok/warn/danger)。
- **字体**:`MiSans`(Latin + 简体中文一套变量字体)**随 app 打包**(`assets/fonts/MiSansVF.ttf`)→ 全平台确定渲染。

## 5. 三岛 shell 骨架（`core/ui/an_shell.dart`）

无边框**不透明白窗**:左岛(`AnIsland` 卡,**弹性 240–400 默认 320、可拖**)· 敞开海洋(窗体白面、无卡,内容列**弹性 480–720**)· 右岛(`AnIsland` 卡,**固定 320**);四周 8px + 岛间 8px(左岛 grip 兼间距、右岛纯间距)。**两岛恒在,不收起。**
- **尺寸(逻辑点,`window_manager` 管 → scale 正确、resize 不炸)**:**最小** = 保证即便左岛拖到 max、海洋仍有最小内容列 `内距 + 左岛max(400) + 间距 + 海洋min(480) + 间距 + 右岛(320) + 内距` = **1232×761**(黄金比例高)。**默认** ≈ 1280×791(居中、1512 屏上留余量)。海洋是弹性区,内容列在 480–720 间随窗伸缩(更宽则 720 居中)。
- **红绿灯**:macOS 由 `macos_window_utils`(成熟包)**加高标题栏**(`addToolbar` + unified 风格)→ OS 把灯纵向居中到更低位、**仍在可点击的标题栏层**(Apple 旗舰做法)。**绝不**把原生按钮挪进内容区(会被全尺寸内容视图吃掉点击)、**绝不手搓**(见设计原则 #8)。Windows/Linux 此位放产品标 + 名(`AnWindowControls`)。
- **缩放(两种,别混)**:① **系统显示档**(设置→显示器)——全用**逻辑点**即自动适配,无需特殊处理;② **应内 Cmd +/-/0**(`core/platform/window_zoom.dart`)——用 `scaled_app`(`ScaledWidgetsFlutterBinding` 重写视图配置)**整体重排式**缩放(非 Transform/textScaler),默认 100%、离散档持久化,变更时窗口最小值同步 ×zoom。**zoom-in 受屏幕容量管控**(`maxFactor` = 屏可容 / 设计min,逐轴取小):到顶即停、**绝不撑破布局**;持久化档恢复时也按当前屏可容上限收敛。**不手搓**(原则 #8)。

## 6. 工具链与门禁

- 工具链 = **mise**(go + flutter,仓库根 `mise.toml`)。
- **三种启动**:`make demo`(真形态 + fixture、零后端)· `make gallery`(组件画廊,UI 套件落地后)· `make app`(后端 sidecar)。
- 门禁 `make verify` = `flutter analyze` 净 + `flutter test` 绿(`make fe-verify` 含 codegen,待 freezed/slang 接入)。

## 7. 文档纪律

`references/frontend/` 随骨架 / feature **同提交**重写填充,与代码逐字同步(CLAUDE.md #9)。
