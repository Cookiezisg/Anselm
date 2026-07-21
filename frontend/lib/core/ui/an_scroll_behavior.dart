import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A [ScrollBehavior] that SUPPRESSES the scrollbar — wrap a scrollable in
/// `ScrollConfiguration(behavior: const AnScrollBehavior(), child: …)` where the design hides the bar (the
/// right inspector body, the sidebar tree). Apply it LOCALLY only, NEVER at the app root — a global install
/// would strip AnPage's deliberate RawScrollbar and every future feature scrollable. Extends the base
/// [ScrollBehavior] (not Material's) so there is no overscroll glow either; it also enables mouse / trackpad
/// drag-to-scroll (the desktop default set omits them).
///
/// 抑制滚动条的 ScrollBehavior:局部包住要隐藏滚动条的可滚区(右岛 body、sidebar 树)。**仅局部、绝不 app-root**
/// (否则碾压 AnPage 故意的 RawScrollbar 与未来 feature 可滚区)。继承基类 ScrollBehavior(非 Material)故无 overscroll
/// 辉光;并开鼠标/触控板拖拽滚动(桌面默认集不含)。
class AnScrollBehavior extends ScrollBehavior {
  const AnScrollBehavior();

  // No scrollbar — the design hides it; scroll by wheel / trackpad / drag. 隐滚动条。
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  // Allow drag-to-scroll from mouse + trackpad (the base desktop set omits mouse). 开鼠标/触控板拖滚。
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
