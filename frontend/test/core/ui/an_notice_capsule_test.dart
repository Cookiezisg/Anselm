import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_notice_capsule.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The band capsule's self-driven lifecycle: entrance → hold (hover pauses) → exit → onDismissed(once).
// Tap fires onTap; reduced motion is instant in/out. 胶囊自驱生命周期+hover 暂停+点击+reduced。
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('entrance → hold → exit → onDismissed exactly once', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(AnNoticeCapsule(
      text: 'workflow failed',
      viewLabel: 'View',
      hold: const Duration(seconds: 1),
      onDismissed: () => dismissed++,
    )));
    await tester.pump(); // post-frame arms
    await tester.pump(const Duration(milliseconds: 300)); // entrance done
    expect(find.text('workflow failed'), findsOneWidget);
    expect(dismissed, 0);
    await tester.pump(const Duration(seconds: 1)); // hold elapses → exit starts
    await tester.pump(const Duration(milliseconds: 500)); // exit animation
    await tester.pump();
    expect(dismissed, 1, reason: '退场动画完成后回调恰一次');
  });

  testWidgets('hover pauses the dwell; exit resumes it', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(AnNoticeCapsule(
      text: 'held',
      viewLabel: 'View',
      hold: const Duration(seconds: 1),
      onDismissed: () => dismissed++,
    )));
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

  testWidgets('tap fires onTap (host owns teardown — no auto-dismiss on tap)', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(AnNoticeCapsule(
      text: 'go',
      viewLabel: 'View',
      hold: const Duration(seconds: 30),
      onTap: () => tapped++,
      onDismissed: () {},
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('go'));
    expect(tapped, 1);
    expect(find.text('· View'), findsOneWidget, reason: '可导航胶囊带灰「查看」尾');
  });

  testWidgets('reduced motion: instant entrance, instant exit', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(
      AnNoticeCapsule(
        text: 'fast',
        viewLabel: 'View',
        hold: const Duration(milliseconds: 100),
        onDismissed: () => dismissed++,
      ),
      reduced: true,
    ));
    await tester.pump(); // arm (instant entrance)
    expect(find.text('fast'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150)); // dwell elapses → instant exit
    await tester.pump();
    expect(dismissed, 1, reason: 'reduced 即时进出,无补间帧');
  });

  testWidgets('the four-beat line: newborn circle → mid-stretch → full pill (width tells the story)',
      (tester) async {
    await tester.pumpWidget(host(AnNoticeCapsule(
      text: 'a reasonably long failure sentence for width',
      viewLabel: 'View',
      hold: const Duration(seconds: 30),
      onDismissed: () {},
    )));
    await tester.pump();
    double shellW() => tester.getSize(find.byType(DecoratedBox).first).width;
    // Birth beat (~28% of 560ms): the shell is still the circle (width == height). 诞生拍:壳仍是圆。
    await tester.pump(const Duration(milliseconds: 80));
    final birthW = shellW();
    expect(birthW, lessThan(40), reason: '诞生期壳≈圆(宽≈高 28),字一个都还没露');
    // Mid-stretch: strictly between circle and full. 拉开中:严格介于圆与全宽之间。
    await tester.pump(const Duration(milliseconds: 200));
    final midW = shellW();
    expect(midW, greaterThan(birthW));
    // Fully open: wider than mid (easeOut tail may still be settling at 560ms edge). 全开:宽于中段。
    await tester.pump(const Duration(milliseconds: 400));
    expect(shellW(), greaterThan(midW));
  });
}
