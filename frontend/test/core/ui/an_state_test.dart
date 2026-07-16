import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/announce_probe.dart';

void main() {
  // No fixed height — AnState centers within its bounds and shrink-wraps when height is unbounded (its
  // real usage is inside a scrollable/flex parent). 不固定高:AnState 在界内居中、无界时收缩包裹。
  Widget host(Widget child, {double width = 360, bool reduced = false}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Builder(builder: (ctx) {
                  return reduced ? MediaQuery(data: MediaQuery.of(ctx).copyWith(disableAnimations: true), child: child) : child;
                }),
              ),
            ),
          ),
        ),
      );

  testWidgets('empty renders title + hint + action; and stays SILENT', (tester) async {
    final handle = tester.ensureSemantics();
    final said = probeAnnouncements(tester);
    await tester.pumpWidget(host(AnState(
      kind: AnStateKind.empty,
      title: 'No functions yet',
      hint: 'Create one to start.',
      action: AnButton(label: 'New', onPressed: () {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('No functions yet'), findsOneWidget);
    expect(find.text('Create one to start.'), findsOneWidget);
    expect(find.text('New'), findsOneWidget); // action present + focusable
    expect(said, isEmpty, reason: 'empty 是你导航过去那地方的初始内容、不是新闻');
    handle.dispose();
  });

  testWidgets('error is MONOCHROME (glyph = inkFaint, never danger) and ANNOUNCES itself', (tester) async {
    final handle = tester.ensureSemantics();
    final said = probeAnnouncements(tester);
    await tester.pumpWidget(host(const AnState(kind: AnStateKind.error, title: 'Failed', hint: 'Retry.')));
    await tester.pumpAndSettle();
    final glyph = tester.widget<Icon>(find.byIcon(AnIcons.error));
    expect(glyph.color, AnColors.light.inkFaint);
    expect(glyph.color, isNot(AnColors.light.danger)); // decision ①: red is reserved for AnCallout
    expect(tester.getSemantics(find.byType(AnState)).label, 'Failed. Retry.'); // findable 可被找到
    // Asserted on the CHANNEL, not on `liveRegion`: this used to assert the flag, which is a desktop
    // no-op — so the old test was green while the block was mute. Polite, because the loud tier is
    // AnCallout's. 断言打在**通道**上而非 liveRegion:那面旗标是桌面 no-op,旧测试在**块是哑的**时候照样绿。
    expect(said.map((a) => a.toString()), ['polite: Failed. Retry.']);
    handle.dispose();
  });

  testWidgets('an in-place loading→error flip announces the NEW sentence (the reader is sitting on it)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final said = probeAnnouncements(tester);
    await tester.pumpWidget(host(const AnState(kind: AnStateKind.loading, title: 'Loading…')));
    // NOT pumpAndSettle — `loading` runs AnSpinner, an infinite loop that never settles (the existing
    // reduced-motion test single-steps for the same reason). Two pumps = mount + the post-frame callback
    // the announcement rides. 不用 pumpAndSettle:loading 挂着 AnSpinner 无限循环、永不收敛(同文件的 reduced
    // 测试也是单步推进);两 pump = 挂载 + 播报所在的 post-frame。
    await tester.pump();
    await tester.pump();
    expect(said.map((a) => a.toString()), ['polite: Loading…']);
    said.clear();
    await tester.pumpWidget(host(const AnState(kind: AnStateKind.error, title: 'Failed', hint: 'Retry.')));
    await tester.pump();
    await tester.pump();
    expect(said.map((a) => a.toString()), ['polite: Failed. Retry.'],
        reason: '原地翻成错误:除了我们没人会告诉读屏');
    handle.dispose();
  });

  testWidgets('loading spins normally, freezes to a static glyph under reduced-motion', (tester) async {
    await tester.pumpWidget(host(const AnState(kind: AnStateKind.loading, title: 'Loading…')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // animated spinner

    await tester.pumpWidget(host(const AnState(kind: AnStateKind.loading, title: 'Loading…'), reduced: true));
    await tester.pumpAndSettle(const Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(tester.takeException(), isNull); // no ticker left running
    expect(find.byType(CircularProgressIndicator), findsNothing); // froze to a static glyph
    expect(find.byIcon(AnIcons.spin), findsOneWidget);
  });

  testWidgets('long title + hint wrap and stay centered, no overflow', (tester) async {
    await tester.pumpWidget(host(
      const AnState(
        kind: AnStateKind.error,
        title: 'A long error title that must wrap and stay centered without overflowing the column',
        hint: 'An equally long explanatory hint that wraps onto several centered lines and never overflows.',
      ),
      width: 240,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
