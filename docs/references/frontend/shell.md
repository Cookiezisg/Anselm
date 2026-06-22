---
id: DOC-048
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 三岛 shell —— 左岛 / 海洋 / 右岛

> 整体空间布局**完整复刻** `demo/`(`demo/core/{shell,sidebar}.js` + `primitives/{right-island,page,ocean-header}.js`)的设计——这是认真定过的产品形态,实现忠实于 demo 结构;视觉细节走 [design-system](design-system.md)。组件在 `core/ui/`。

## 1. 窗体(原生窗口,非 mockup 盒子)

真 app = **不透明白色无边框窗**(`window_manager`:隐藏标题栏但 `windowButtonVisibility:true` 保留 macOS **真红绿灯**;圆角由 OS 给;`setMinimumSize` 900×600)。统一设置在 `app/window_setup.dart`,真 app 与 dev 入口(`make demo` / `make gallery`)共用。`AnShell` 根是 `Material(color: surface)` 填满窗体——**不画假桌面/假圆角窗**(那是 demo 作为网页 mockup 的妥协)。窗内:8px 内距 + 8px 岛间距 → 三张白岛卡(`AnRadius.chip`=12 + float 阴影 + 细边),分隔靠**阴影 + 细线**非颜色。

**红绿灯对齐(代码控制,非魔法数)**:macOS 红绿灯由 OS 画、Flutter 排不动 → `core/platform/window_chrome.dart` 的 `WindowChrome` 经平台通道 `anselm/window_chrome` 把目标几何**下发原生**(`macos/Runner/MainFlutterWindow.swift` 存值 + 每次 resize 重应用)。位置事实源在 Dart 的 **design token**:`AnSize.trafficLightLeft`(=窗内距+边框+岛内距)/ `trafficLightCenterY`(+半行=顶栏条中心线)。灯位**恒定**(不随开合跳动),启动 `initWindow` 时下发一次。非 macOS / 无头测试 = noop。

> `Material` 包裹同时根治"缺 Material 祖先"的**黄色调试下划线**。

## 2. 左岛(`AnSidebar`,单张 240 卡,可调宽 240–420)

顶栏 = 共用 **`AnChromeBar`**(定高一行,中心线刻意对齐红绿灯):行首 **`AnWindowControls`** 前导区(macOS 留 `windowControlsInset` 给真红绿灯、**绝不画假点**;Win/Linux 无左侧 OS 控件 → 放产品标+名)+ `Spacer` + 收起 + 搜索。**横向 Notion 式导航**(未选只图标、选中=图标+标签药丸,标签溢出截断):Chat / Entities / Scheduler / Documents。中部:feature 列表(`body`)。底部:工作区+齿轮(→设置)/ 铃铛(→通知,带未读点)。左下:`AnPeek` 浮条(瞬态状态:如"流程等待审批")。

## 3. 海洋(`AnPage` 内容 + 浮动头)

`AnShell` 在海洋顶部叠一个**浮动头**(`_OceanHeader`:绝对定位 + 白→透明渐隐 scrim;滚动时紧凑标题淡入)。它复用**同一个 `AnChromeBar`**:左岛**收起**时长出前导窗控区 + reopen 钮(海洋左上既避开又**对齐**红绿灯,与侧栏顶栏同一几何);未收起时无前导,只标题 + 右岛开合钮。两态顶栏条共享一条中心线 = 红绿灯永远对齐(单测 `every chrome bar shares the traffic-light vertical center` 守)。内容用 `AnPage`(居中 `AnSize.content`=720 列 + overlay 滚轮 + 顶部留白避开浮动头),其首部是大页头 `AnOceanHeader`(面包屑 / 大标题 / meta 徽标 / 右侧动作)。

## 4. 右岛(`AnRightIsland`,360 白卡,可宽至 480)

头(图标 + 标题 + 关闭)+ 可滚正文(`AnInfoCard` 堆叠)。滑入/滑出动画。

## 5. 交互(`AnShell` 持有,bug-free 单测见 `test/core/ui/an_shell_test.dart`)

- 左岛**收起/展开**(spring 动画;收起后 reopen 钮浮现于海洋头)。
- 左岛**拖拽调宽**(240–420,grip 兼作 8px 间距;**shared_preferences 持久**宽度 + 收起态)。
- 右岛**滑入滑出**切换。
- **响应式自动收岛**:窗宽 < `rightIslandBreakpoint`(1080)强制收右岛;< `sidebarBreakpoint`(760)强制收左岛——海洋永有空间、**不溢出**;宽于断点时尊重手动开合。
- 动画期定宽裁剪(`ClipRect`+`OverflowBox`),内容不挤压不溢出。

## 6. `AnShell` API

`sidebarBuilder(onCollapse) → AnSidebar(…, onCollapse: onCollapse)` · `oceanBuilder(scroll) → AnPage(controller: scroll, …)` · `rightIsland` · `headTitle` · `headActions`。装配示例:`app/shell/app_shell.dart`(demo 与 app 共用);验收:`cd frontend && make demo`。
