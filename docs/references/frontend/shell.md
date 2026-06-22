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

## 1. 窗体

桌面(`desk` 灰)+ 16px 边距 → **圆角白窗**(`AnRadius.island`=20 + win 阴影)→ 8px 内距 + 8px 岛间距 → 三张白岛卡(`AnRadius.chip`=12 + float 阴影 + 细边)。分隔靠**阴影 + 细线**,非颜色。真 macOS app 接无边框窗(window_manager)后 `AnShell.framed=false`,免与 OS 标题栏重叠。

## 2. 左岛(`AnSidebar`,单张 240 卡,可调宽 240–420)

顶栏:**macOS 红绿灯**(唯一具名色例外,真机即 OS 控件)+ 收起 + 搜索。**横向 Notion 式导航**(未选只图标、选中=图标+标签药丸):Chat / Entities / Scheduler / Documents。中部:feature 列表(`body`)。底部:工作区+齿轮(→设置)/ 铃铛(→通知,带未读点)。左下:`AnPeek` 浮条(瞬态状态:如"流程等待审批")。

## 3. 海洋(`AnPage` 内容 + 浮动头)

`AnShell` 在海洋顶部叠一个**浮动头**(绝对定位 + 白→透明渐隐 scrim;滚动时紧凑标题淡入;含 reopen 钮[左岛收起时]、右岛开合钮)。内容用 `AnPage`(居中 `AnSize.content`=720 列 + overlay 滚轮 + 顶部留白避开浮动头),其首部是大页头 `AnOceanHeader`(面包屑 / 大标题 / meta 徽标 / 右侧动作)。

## 4. 右岛(`AnRightIsland`,360 白卡,可宽至 480)

头(图标 + 标题 + 关闭)+ 可滚正文(`AnInfoCard` 堆叠)。滑入/滑出动画。

## 5. 交互(`AnShell` 持有,bug-free 单测见 `test/core/ui/an_shell_test.dart`)

- 左岛**收起/展开**(动画;收起后 reopen 钮浮现于海洋头)。
- 左岛**拖拽调宽**(240–420,grip 兼作 8px 间距;**shared_preferences 持久**宽度 + 收起态)。
- 右岛**滑入滑出**切换。
- 动画期定宽裁剪(`ClipRect`+`OverflowBox`),内容不挤压不溢出。

## 6. `AnShell` API

`sidebarBuilder(onCollapse) → AnSidebar(…, onCollapse: onCollapse)` · `oceanBuilder(scroll) → AnPage(controller: scroll, …)` · `rightIsland` · `headTitle` · `headActions` · `framed`。装配示例:`app/shell/app_shell.dart`;mock 验收:`cd frontend && make shell`。
