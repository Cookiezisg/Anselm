import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_count_up.dart';
import 'package:anselm/core/ui/an_live_code_window.dart';
import 'package:anselm/core/ui/an_minimap_spine.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// W2 primitives (WRK-061 §7-1/§7-8): the live code window releases WHOLE LINES only (the incomplete
// tail is withheld — no jitter), counts lines incrementally, caps to the tail window; the spine paints
// and reports tap fractions. W2 原语电池:整行释放(未完尾行按住)/增量行数/尾窗上限;书脊渲染+点报分数。

Widget _host(Widget c) =>
    TranslationProvider(child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SizedBox(width: 600, child: c))));

void main() {
  testWidgets('whole-line release: the incomplete tail line is withheld until its newline lands',
      (tester) async {
    await tester.pumpWidget(_host(const AnLiveCodeWindow(text: 'alpha()\nbeta()\ngamma(unfinis')));
    await tester.pumpAndSettle();
    expect(find.text('alpha()'), findsOneWidget);
    expect(find.text('beta()'), findsOneWidget);
    expect(find.textContaining('gamma'), findsNothing); // held 按住

    await tester.pumpWidget(_host(const AnLiveCodeWindow(text: 'alpha()\nbeta()\ngamma(unfinished)\n')));
    await tester.pumpAndSettle();
    expect(find.text('gamma(unfinished)'), findsOneWidget); // released 落行
  });

  testWidgets('line counter is incremental and survives a source swap (settle snapshot)', (tester) async {
    await tester.pumpWidget(_host(const AnLiveCodeWindow(text: 'a\nb\n')));
    await tester.pumpAndSettle();
    expect(find.byType(AnCountUp), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(_host(const AnLiveCodeWindow(text: 'a\nb\nc\nd\n')));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);

    // Swap to a SHORTER replacement (settle snapshot differs from deltas) → honest rescan. 换源重扫。
    await tester.pumpWidget(_host(const AnLiveCodeWindow(text: 'x\n')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('the window shows at most tailLines lines (newest kept)', (tester) async {
    final text = '${List.generate(40, (i) => 'row$i').join('\n')}\n';
    await tester.pumpWidget(_host(AnLiveCodeWindow(text: text, tailLines: 10)));
    await tester.pumpAndSettle();
    expect(find.text('row39'), findsOneWidget); // newest 最新在
    expect(find.text('row29'), findsNothing); // beyond the tail 尾窗外
    expect(find.text('40'), findsOneWidget); // count is TOTAL, not the window 计数是全量
  });

  testWidgets('spine renders and reports the tap fraction', (tester) async {
    double? tapped;
    await tester.pumpWidget(_host(SizedBox(
      height: 200,
      child: AnMinimapSpine(
        totalUnits: 1000,
        inkedUnits: 500,
        prefixUnits: 200,
        paragraphOffsets: const [250, 750],
        onTapFraction: (f) => tapped = f,
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(find.byType(AnMinimapSpine)).center);
    expect(tapped, isNotNull);
    expect(tapped!, closeTo(0.5, 0.1));
  });
}
