import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/announce_probe.dart';

void main() {
  Widget host(Widget child, {double width = 320}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      );

  testWidgets('numbered: done shows a check, current/upcoming show numbers', (tester) async {
    await tester.pumpWidget(host(const AnStepper(count: 4, current: 2, variant: AnStepperVariant.numbered)));
    expect(find.byIcon(AnIcons.check), findsOneWidget); // step 1 = done
    expect(find.text('1'), findsNothing); // done shows a check, not its number
    expect(find.text('2'), findsOneWidget); // current
    expect(find.text('3'), findsOneWidget); // upcoming
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a11y value is "Step N of M" (clamped) and is FINDABLE', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnStepper(count: 4, current: 3, semanticLabel: 'Setup')));
    final s = tester.getSemantics(find.byType(AnStepper));
    expect(s.value, 'Step 3 of 4');
    handle.dispose();
  });

  testWidgets('arriving says NOTHING; ADVANCING announces — the furniture/news asymmetry', (tester) async {
    final handle = tester.ensureSemantics();
    final said = probeAnnouncements(tester);
    await tester.pumpWidget(host(const AnStepper(count: 4, current: 1, semanticLabel: 'Setup')));
    await tester.pumpAndSettle();
    // A stepper is page FURNITURE that was already here — shouting on mount talks over the page the
    // reader just navigated to, and they will read it when they get there.
    // stepper 是**本来就在**的页面家具——挂载即喊会盖过读屏刚导航到的这一页,而他们走到时自会读到。
    expect(said, isEmpty, reason: '到场不播报——它不是新闻');

    await tester.pumpWidget(host(const AnStepper(count: 4, current: 2, semanticLabel: 'Setup')));
    await tester.pumpAndSettle();
    // The flow moving underneath them is the one thing they CANNOT discover on their own. 脚下流程在动
    // 是他们自己发现不了的唯一一件事。
    expect(said.map((a) => a.toString()), ['polite: Setup. Step 2 of 4']);
    handle.dispose();
  });

  testWidgets('a rebuild that does not advance stays silent (no announce storm on repaint)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnStepper(count: 4, current: 2, semanticLabel: 'Setup')));
    await tester.pumpAndSettle();
    final said = probeAnnouncements(tester);
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(host(const AnStepper(count: 4, current: 2, semanticLabel: 'Setup')));
      await tester.pumpAndSettle();
    }
    expect(said, isEmpty, reason: '重建不是推进;每帧喊一遍=滥播报');
    handle.dispose();
  });

  testWidgets('onStepTap: only COMPLETED steps are tappable and report the right 1-based index', (tester) async {
    int? tapped;
    await tester.pumpWidget(host(AnStepper(
      count: 4,
      current: 3,
      variant: AnStepperVariant.numbered,
      onStepTap: (s) => tapped = s,
    )));
    // steps 1,2 are done → tappable; 3 (current) and 4 (upcoming) are not.
    expect(find.bySemanticsLabel('Go to step 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Go to step 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Go to step 3'), findsNothing);
    expect(find.bySemanticsLabel('Go to step 4'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Go to step 2'));
    expect(tapped, 2);
  });

  testWidgets('count <= 0 renders nothing (no overflow)', (tester) async {
    await tester.pumpWidget(host(const AnStepper(count: 0, current: 1)));
    expect(tester.takeException(), isNull);
    expect(find.byType(Row), findsNothing); // shrunk to SizedBox.shrink
  });

  testWidgets('many steps in a narrow row do not overflow', (tester) async {
    await tester.pumpWidget(host(const AnStepper(count: 10, current: 4), width: 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
