import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 B6 — flipping light↔dark must not rebuild the whole tree once per frame for 200ms.
//
// User report: «明暗切换卡卡的». The cause is not our code being slow, it is what MaterialApp does by
// default: [AnimatedTheme] LERPS the entire ThemeData over `kThemeAnimationDuration`, and our ThemeData
// carries three ThemeExtensions — [AnColors] alone interpolates 46 colours plus shadow lists, and
// SyntaxColors / graph colours follow. Every frame of that animation hands out a NEW extension
// instance, so every widget that reads `context.colors` rebuilds once per FRAME, not once. (This test
// counts 3 with the default duration, because `pumpAndSettle` steps 100ms at a time; on a 60Hz display
// the same 200ms window is ~12 frames. The number is not the point — «more than once» is.)
//
// This app makes that worse by design: the ocean / rail / inspector stacks KEEP EVERY VISITED SCREEN
// MOUNTED (S3, deliberate — zero rebuild on ocean switch). So a theme flip does not repaint one screen,
// it repaints all five, once per frame.
//
// The rule this pins is the one the codebase already states for data updates: 「已挂载内容的数据更新
// 原地换、零动画(快就是丝滑)」. A theme flip is that same shape — a whole-surface swap, where the fastest
// honest thing is to swap.
//
// WRK-083 B6——明↔暗切换不得让整棵树在 200ms 内每帧重建一次。
//
// 用户报告:「明暗切换卡卡的」。病因不是我们的代码慢,而是 MaterialApp 的**默认行为**:[AnimatedTheme] 在
// `kThemeAnimationDuration` 内**逐帧 lerp 整个 ThemeData**,而我们的 ThemeData 挂了三个 ThemeExtension——光
// [AnColors] 就要插值 46 个颜色外加阴影列表,SyntaxColors / 图色板还在后面。那个动画的**每一帧**都发一个**新的**
// extension 实例,于是每个读 `context.colors` 的 widget **每帧**都重建,而不是一次。(本测试在默认时长下数到 3,
// 因为 `pumpAndSettle` 按 100ms 步进;真机 60Hz 下同一个 200ms 窗口是 ~12 帧。数字不是重点,「不止一次」才是。)
//
// 本 app 的设计让它更糟:海洋 / rail / 右岛三个栈**把访问过的每一屏都保活挂着**(S3,刻意为之——切海洋零重建)。
// 于是一次主题切换重绘的不是一屏,是五屏、各每帧一次。
//
// 本条钉住的规矩,正是代码库对数据更新已经写下的那条:「已挂载内容的数据更新原地换、零动画(快就是丝滑)」。
// 主题切换是同一种形状——整面替换,而最快的诚实做法就是**换**。

/// Counts its own builds; reads `context.colors` so it depends on the AnColors extension.
/// 自数 build 次数;读 `context.colors`,故依赖 AnColors extension。
class _ColorConsumer extends StatelessWidget {
  const _ColorConsumer(this.builds);

  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(1);
    return ColoredBox(color: context.colors.canvas, child: const SizedBox());
  }
}

class _Host extends StatefulWidget {
  const _Host(this.builds);
  final List<int> builds;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  ThemeMode mode = ThemeMode.light;

  /// Flip from the test — `setState` itself is protected to the State subclass.
  /// 供测试翻转;`setState` 只属 State 子类自己。
  void flipToDark() => setState(() => mode = ThemeMode.dark);

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    darkTheme: AnTheme.dark(),
    themeMode: mode,
    // The knob under test — see AnApp. 被测的那颗旋钮,见 AnApp。
    themeAnimationDuration: AnTheme.switchDuration,
    home: Scaffold(body: _ColorConsumer(widget.builds)),
  );
}

void main() {
  testWidgets('a light↔dark flip repaints ONCE, not once per frame (B6)', (
    tester,
  ) async {
    final builds = <int>[];
    await tester.pumpWidget(_Host(builds));
    await tester.pumpAndSettle();

    builds.clear();
    final host = tester.state<_HostState>(find.byType(_Host));
    host.flipToDark();
    await tester.pumpAndSettle();

    expect(
      builds.length,
      lessThanOrEqualTo(2),
      reason:
          'the theme flip rebuilt every `context.colors` consumer ${builds.length} times — that is '
          'AnimatedTheme lerping the whole ThemeData frame by frame, across every kept-alive screen '
          '(WRK-083 B6)',
    );
  });

  test('the two ThemeData objects are built once, not per AnApp build (B6)', () {
    expect(
      identical(AnTheme.light(), AnTheme.light()),
      isTrue,
      reason:
          'AnApp rebuilds on router / locale / theme-mode changes and constructs both themes each '
          'time; ThemeData with three extensions is not free to build (WRK-083 B6)',
    );
    expect(identical(AnTheme.dark(), AnTheme.dark()), isTrue);
  });
}
