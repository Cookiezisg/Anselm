import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/core/ui/an_live_tail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnLiveTail term face (WRK-066 族六, absorbed AnTermTail) — folds cursor rewrites and shows the last N
// lines with a top fade when there's more above. 活尾族 term 脸(吸收旧 AnTermTail)。

const _esc = '\x1B';

Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: SizedBox(width: 500, child: c)),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('folds a \\r progress bar to its final frame', (tester) async {
    await tester.pumpWidget(
      _host(const AnLiveTail('Build\n[10%]\r[55%]\r[100%] done')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('[100%] done'), findsOneWidget);
    expect(find.textContaining('[10%]'), findsNothing); // overwritten
  });

  testWidgets(
    'shows the last N lines + a top fade when output scrolled off above',
    (tester) async {
      final many = List.generate(20, (i) => 'line $i').join('\n');
      await tester.pumpWidget(_host(AnLiveTail(many, tailLines: 6)));
      await tester.pumpAndSettle();
      expect(find.text('line 19'), findsOneWidget); // last line shown
      expect(find.text('line 0'), findsNothing); // scrolled off
      expect(find.byType(AnEdgeFade), findsOneWidget); // top fade (more above)
    },
  );

  testWidgets('no fade when everything fits', (tester) async {
    await tester.pumpWidget(_host(const AnLiveTail('a\nb\nc', tailLines: 6)));
    await tester.pumpAndSettle();
    expect(find.byType(AnEdgeFade), findsNothing);
  });

  testWidgets(
    'renders ANSI colors as themed spans (does not print raw escapes)',
    (tester) async {
      await tester.pumpWidget(_host(AnLiveTail('$_esc[31mERROR$_esc[0m')));
      await tester.pumpAndSettle();
      // The escape codes must NOT appear as literal text. 转义码不得作字面出现。
      expect(find.textContaining(_esc), findsNothing);
      expect(find.textContaining('ERROR'), findsOneWidget);
    },
  );
}
