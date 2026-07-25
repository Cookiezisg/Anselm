import 'package:flutter/widgets.dart';

/// A [ScrollBehavior] that SUPPRESSES the scrollbar — wrap a scrollable in
/// `ScrollConfiguration(behavior: const AnScrollBehavior(), child: …)` where the design hides the bar (the
/// right inspector body, the sidebar tree). Apply it LOCALLY only, NEVER at the app root — a global install
/// would strip AnPage's deliberate RawScrollbar and every future feature scrollable. Extends the base
/// [ScrollBehavior] (not Material's) so there is no overscroll glow either.
///
/// 抑制滚动条的 ScrollBehavior:局部包住要隐藏滚动条的可滚区(右岛 body、sidebar 树)。**仅局部、绝不 app-root**
/// (否则碾压 AnPage 故意的 RawScrollbar 与未来 feature 可滚区)。继承基类 ScrollBehavior(非 Material)故无 overscroll 辉光。
class AnScrollBehavior extends ScrollBehavior {
  const AnScrollBehavior();

  // No scrollbar — the design hides it; scroll by wheel / trackpad / scrollbar / touch. 隐滚动条。
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  // dragDevices is DELIBERATELY not overridden. It used to add PointerDeviceKind.mouse, under a comment
  // reading "the base desktop set omits mouse" — as if that omission were an oversight. It is the opposite:
  // Flutter's own breaking-change note says the default set excludes mouse precisely so that text inside
  // scrollable containers stays selectable, and that adding it "will make it difficult or impossible to
  // select text in scrollable containers and is not recommended".
  //
  // So this one line made every SelectionArea in the app inert: a mouse drag went to the scrollable instead
  // of the selection, in all 23 scrollables that use this behavior. It is also why the one SelectionArea we
  // did have (run_terminal) was written correctly and still felt like it did nothing.
  //
  // What is lost is press-and-drag-the-content-with-the-left-button, a PHONE habit. Wheel, trackpad,
  // scrollbar and touch are all unaffected. That is not a trade-off, it is a correction.
  //
  // dragDevices **刻意不覆写**。它原先加了 `PointerDeviceKind.mouse`,注释写着「桌面默认集不含 mouse」,像是在说
  // 那是个疏漏。恰恰相反:Flutter 官方 breaking-change 文档明述默认集**故意**排除 mouse,正是为了让滚动容器里的
  // 文字保持可选,并写明加入它「will make it difficult or impossible to select text in scrollable containers
  // and is not recommended」。
  //
  // 于是这一行让全 app 的 SelectionArea 形同虚设:鼠标拖拽会去滚动而非划选,在用本 behavior 的 23 处可滚区里
  // 处处如此。这也解释了我们唯一那处 SelectionArea(run_terminal)明明写对了、却没人觉得「能用」。
  //
  // 失去的只是「按住左键拖内容」这个**手机习惯**;滚轮、触控板、滚动条、触摸全不受影响。这不是权衡,是纠错。
}
