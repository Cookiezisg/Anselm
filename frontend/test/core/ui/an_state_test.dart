import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('empty renders title + hint + action; not a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(AnState(
      kind: AnStateKind.empty,
      title: 'No functions yet',
      hint: 'Create one to start.',
      action: AnButton(label: 'New', onPressed: () {}),
    )));
    expect(find.text('No functions yet'), findsOneWidget);
    expect(find.text('Create one to start.'), findsOneWidget);
    expect(find.text('New'), findsOneWidget); // action present + focusable
    expect(tester.getSemantics(find.byType(AnState)).flagsCollection.isLiveRegion, isFalse,
        reason: 'empty is initial content, not a change');
    handle.dispose();
  });

  testWidgets('error is MONOCHROME (glyph = inkFaint, never danger) and is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnState(kind: AnStateKind.error, title: 'Failed', hint: 'Retry.')));
    final glyph = tester.widget<Icon>(find.byIcon(AnIcons.error));
    expect(glyph.color, AnColors.light.inkFaint);
    expect(glyph.color, isNot(AnColors.light.danger)); // decision ①: red is reserved for AnCallout
    final s = tester.getSemantics(find.byType(AnState));
    expect(s.flagsCollection.isLiveRegion, isTrue);
    expect(s.label, 'Failed. Retry.');
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
