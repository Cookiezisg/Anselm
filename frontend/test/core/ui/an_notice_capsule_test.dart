import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_notice_capsule.dart';
import 'package:anselm/core/ui/an_notice_close_affordance.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The band capsule's self-driven lifecycle: entrance → hold (hover pauses) → exit → onDismissed(once).
// Tap / X reverse the same line; external bulk clear can request the same exit. reduced is instant.
// 点击/X/外部清场均倒放同线;reduced 即时。
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('entrance → hold → exit → onDismissed exactly once', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'workflow failed',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 1),
          onDismissed: () => dismissed++,
        ),
      ),
    );
    await tester.pump(); // post-frame arms
    await tester.pump(
      const Duration(milliseconds: 700),
    ); // entrance done; only now does dwell begin
    expect(find.text('workflow failed'), findsOneWidget);
    expect(dismissed, 0);
    await tester.pump(const Duration(seconds: 1)); // hold elapses → exit starts
    await tester.pump(const Duration(milliseconds: 500)); // exit animation
    await tester.pump();
    expect(dismissed, 1, reason: '退场动画完成后回调恰一次');
  });

  testWidgets('hover pauses the dwell; exit resumes it', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'held',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 1),
          onDismissed: () => dismissed++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('held')));
    await tester.pump();
    // Hover holds it well past the dwell. 悬停远超停留时长仍在。
    await tester.pump(const Duration(seconds: 3));
    expect(dismissed, 0, reason: 'hover 暂停消隐(WCAG)');
    await gesture.moveTo(const Offset(1, 1)); // leave
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(dismissed, 1, reason: '移开后计时恢复并退场');
  });

  testWidgets('view area fires onTap and keeps a separate always-visible X', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'go',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 30),
          onTap: () => tapped++,
          onDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.textContaining('go', findRichText: true));
    expect(tapped, 1);
    expect(
      find.textContaining('· View', findRichText: true),
      findsOneWidget,
      reason: '可导航胶囊带灰「查看」尾',
    );
    expect(find.bySemanticsLabel('Dismiss notice'), findsOneWidget);
  });

  testWidgets('36px crown optically seats the tile-less close affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'aligned',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 30),
          onDismissed: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    final island = tester.getRect(find.byType(DecoratedBox).first);
    final icon = find.byIcon(AnIcons.close);
    final target = find.ancestor(
      of: icon,
      matching: find.byType(AnNoticeCloseAffordance),
    );
    final targetRect = tester.getRect(target);
    final iconRect = tester.getRect(icon);
    expect(island.height, 36);
    expect(targetRect.size, const Size.square(28));
    expect(targetRect.top, moreOrLessEquals(island.top + 4, epsilon: 0.01));
    expect(targetRect.right, moreOrLessEquals(island.right - 2, epsilon: 0.01));
    expect(
      iconRect.center.dx,
      moreOrLessEquals(island.right - 16, epsilon: 0.01),
    );
  });

  testWidgets('pointer hover deepens only the X glyph; no tile appears', (
    tester,
  ) async {
    final previousStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'quiet close',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 30),
          onDismissed: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final affordance = find.byType(AnNoticeCloseAffordance);
    final icon = find.descendant(
      of: affordance,
      matching: find.byIcon(AnIcons.close),
    );
    final face = find.descendant(
      of: affordance,
      matching: find.byType(AnimatedContainer),
    );
    final colors = AnTheme.light().extension<AnColors>()!;
    expect(tester.widget<Icon>(icon).color, colors.inkFaint);
    expect(
      tester.widget<AnimatedContainer>(face).decoration,
      isA<BoxDecoration>().having((d) => d.color, 'fill', isNull),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(affordance));
    addTearDown(gesture.removePointer);
    await tester.pumpAndSettle();

    expect(tester.widget<Icon>(icon).color, colors.ink);
    expect(
      tester.widget<AnimatedContainer>(face).decoration,
      isA<BoxDecoration>()
          .having((d) => d.color, 'fill', isNull)
          .having((d) => d.shape, 'halo shape', BoxShape.circle),
      reason: '鼠标态只加深字形，不在小岛内嵌方形按钮面',
    );
  });

  testWidgets('keyboard focus adds a circular hairline halo', (tester) async {
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'keyboard close',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 30),
          onDismissed: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final face = find.descendant(
      of: find.byType(AnNoticeCloseAffordance),
      matching: find.byType(AnimatedContainer),
    );
    final colors = AnTheme.light().extension<AnColors>()!;
    final decoration =
        tester.widget<AnimatedContainer>(face).decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border!.top.color, colors.inkMuted);
    expect(decoration.border!.top.width, 1);
  });

  testWidgets('reduced motion: instant entrance, instant exit', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'fast',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(milliseconds: 100),
          onDismissed: () => dismissed++,
        ),
        reduced: true,
      ),
    );
    await tester.pump(); // arm (instant entrance)
    expect(find.text('fast'), findsOneWidget);
    await tester.pump(
      const Duration(milliseconds: 150),
    ); // dwell elapses → instant exit
    await tester.pump();
    expect(dismissed, 1, reason: 'reduced 即时进出,无补间帧');
  });

  testWidgets(
    'the four-beat line: newborn circle → mid-stretch → full pill (width tells the story)',
    (tester) async {
      await tester.pumpWidget(
        host(
          AnNoticeCapsule(
            text: 'a reasonably long failure sentence for width',
            viewLabel: 'View',
            closeLabel: 'Dismiss notice',
            hold: const Duration(seconds: 30),
            onDismissed: () {},
          ),
        ),
      );
      await tester.pump();
      double shellW() => tester.getSize(find.byType(DecoratedBox).first).width;
      // Birth beat (~28% of 560ms): the shell is still the circle (width == height). 诞生拍:壳仍是圆。
      await tester.pump(const Duration(milliseconds: 80));
      final birthW = shellW();
      expect(birthW, lessThan(40), reason: '诞生期壳≈圆(宽≈高 36),字一个都还没露');
      // Mid-stretch: strictly between circle and full. 拉开中:严格介于圆与全宽之间。
      await tester.pump(const Duration(milliseconds: 200));
      final midW = shellW();
      expect(midW, greaterThan(birthW));
      // Fully open: wider than mid (easeOut tail may still be settling at 560ms edge). 全开:宽于中段。
      await tester.pump(const Duration(milliseconds: 400));
      expect(shellW(), greaterThan(midW));
    },
  );

  testWidgets('X reverses and dismisses exactly once', (tester) async {
    var closed = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      host(
        AnNoticeCapsule(
          text: 'closable',
          viewLabel: 'View',
          closeLabel: 'Dismiss notice',
          hold: const Duration(seconds: 30),
          onClose: () => closed++,
          onDismissed: () => dismissed++,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.bySemanticsLabel('Dismiss notice'));
    expect(closed, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('external dismiss request plays the same exit', (tester) async {
    var dismiss = false;
    var dismissed = 0;
    Widget capsule() => AnNoticeCapsule(
      text: 'bulk clear',
      viewLabel: 'View',
      closeLabel: 'Dismiss notice',
      dismissRequested: dismiss,
      hold: const Duration(seconds: 30),
      onDismissed: () => dismissed++,
    );
    await tester.pumpWidget(host(capsule()));
    await tester.pump(const Duration(milliseconds: 700));
    dismiss = true;
    await tester.pumpWidget(host(capsule()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(dismissed, 1);
  });
}
