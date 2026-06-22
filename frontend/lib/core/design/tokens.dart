import 'package:flutter/widgets.dart';

/// Theme-INVARIANT design tokens: the values that do not change between light and dark.
/// Colors live in [AnColors] (a ThemeExtension) instead, so they can adapt and lerp; these
/// const scales are pure geometry/time and are read directly. Three self-consistent maths
/// (density = 4-grid powers, layout = 2:3:6 harmonic at u=120, type metrics = modular)
/// keep every surface dimensionally coherent — never inline a raw px.
///
/// 主题无关 token:明暗不变的值(几何/时间)。会变的色在 [AnColors](ThemeExtension)里,
/// 可自适应可 lerp;这些常量直接读。三套自洽数学(密度=4 网格幂 · 布局=谐波 2:3:6,u=120 ·
/// 字阶=模数)保证全局尺寸一致——绝不内联裸 px。

/// Spacing scale (4-grid harmonic). Value-named to stay unambiguous at call sites.
/// 间距阶梯(4 网格谐音)。值命名,调用处零歧义。
abstract final class AnSpace {
  static const double s2 = 2; // hairline gap (dense segmented seams) 密集段缝
  static const double s4 = 4; // base grid 基础网格
  static const double s8 = 8; // inline gap (icon↔text) 行内间距
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

/// Corner radii (4-grid). Each tier maps to a surface class: tag→card→island.
/// 圆角(4 网格)。每级对应一类表面:tag→card→island。
abstract final class AnRadius {
  static const double tag = 4;
  static const double button = 8;
  static const double chip = 12;
  static const double card = 16;
  static const double island = 20;
  static const double pill = 999;
}

/// Sizes: control heights, icon slots, and the 2:3:6 layout widths. The 32px row is the
/// single density anchor (CLAUDE.md 前端守则); sidebar/right-island/content widths are the
/// harmonic columns the three-island shell is laid out on.
///
/// 尺寸:控件高、图标槽、2:3:6 布局宽。32px 行是唯一密度锚;侧栏/右岛/内容宽是三岛 shell 的谐波列。
abstract final class AnSize {
  // Density anchors. 密度锚。
  static const double row = 32; // standard row height (the one) 标准行高(唯一)
  static const double control = 28; // control height = row − grid 控件高
  static const double controlSm = 24; // compact control 小控件
  static const double icon = 16; // standard icon = row lead slot 标准图标=行首槽
  static const double iconSm = 12; // inline dense icon 密集内联图标
  static const double iconLg = 20; // nav / heading icon 导航/标题图标
  static const double dot = 7; // status dot optical size 状态点光学尺寸
  static const double hairline = 1; // one physical line 一物理线
  static const double focusRing = 2; // focus outline weight 焦点环

  // Three-island layout columns (2:3:6 at u=120). 三岛布局列。
  static const double navRail = 64; // left-island icon rail 左岛图标轨
  static const double sidebar = 240; // 2u · left-island list 左岛列表
  static const double sidebarMin = 240;
  static const double sidebarMax = 420;
  static const double rightIsland = 360; // 3u · context inspector 右岛
  static const double rightIslandWide = 480; // 4u · deep-read 右岛深读
  static const double content = 720; // 6u · ocean content column 海洋内容列
  static const double islandHead = 44; // 11u · floating header height 浮动头高
  static const double fieldRow = 48; // 12u · minimum readable field row 字段阅读行
  static const double tab = 34;

  // Window-controls zone. `windowControlsInset` is the width reserved at the chrome bar's
  // leading edge so app content never sits under the macOS traffic lights. `trafficLight*` are
  // the lights' target geometry, DERIVED so they land exactly on the chrome bar's content line
  // — pushed to the native side by WindowChrome (single source of truth, no magic number in
  // Swift). The island's hairline border folds into its padding (Container adds the border to
  // the content inset), so the content line = window pad + border + island pad (+ half a row for
  // the center). `oceanHeaderTopInset` makes the borderless floating ocean header replicate that
  // same offset so its chrome bar lands on the identical line.
  //   left    = window pad + border + island pad → same gap from the island/ocean edge as content
  //   centerY = window pad + border + island pad + half a row → the chrome bar's vertical center
  // 窗控区:inset 给真红绿灯留位;trafficLight* 是灯的目标几何(由 token 派生,精确落在顶栏条内容线),
  // 经 WindowChrome 下发原生——事实源在 Dart,Swift 不写死。岛的发丝边框会并入内距(Container 把
  // 边框算进内容缩进),故内容线 = 窗内距+边框+岛内距(+半行=中心)。oceanHeaderInset 让无边框的
  // 海洋浮动头在两轴复刻同一偏移,使其顶栏条落在同一条线、前导边对齐红绿灯左缘。
  static const double windowControlsInset = 72; // reserve for the real macOS traffic lights 给真红绿灯留位
  static const double trafficLightLeft = AnSpace.s8 + hairline + AnSpace.s12; // 21
  static const double trafficLightCenterY = AnSpace.s8 + hairline + AnSpace.s12 + row / 2; // 37
  static const double oceanHeaderInset = hairline + AnSpace.s12; // 13 — floating header's island-content inset (both axes)

  // Responsive breakpoints: below these the shell auto-collapses islands so the ocean always
  // has room (never overflows). 响应式断点:低于此 shell 自动收岛,海洋永有空间(不溢出)。
  static const double rightIslandBreakpoint = 1080;
  static const double sidebarBreakpoint = 760;
}

/// Motion: durations + easing. Fast for hover, mid for reveals, slow for island slides;
/// breath is the run-status pulse. Curves match the demo's spring feel.
///
/// 动效:时长 + 缓动。fast 悬停 / mid 揭示 / slow 岛屿滑入;breath 是运行状态呼吸。曲线沿用 demo 的弹感。
abstract final class AnMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration mid = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 340);
  static const Duration breath = Duration(milliseconds: 1800);

  static const Cubic easeOut = Cubic(0.16, 1, 0.3, 1);
  static const Cubic spring = Cubic(0.2, 0.9, 0.25, 1);
}
