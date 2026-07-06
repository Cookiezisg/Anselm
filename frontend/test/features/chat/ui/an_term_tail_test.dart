import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/features/chat/ui/tool_card_skins.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnTermTail (B4.3, WRK-056 #46) — the terminal live tail folds cursor rewrites and shows the last N
// lines with a top fade when there's more above. AnTermTail 终端活尾。

const _esc = '\x1B';

Widget _host(Widget c) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: SizedBox(width: 500, child: c))));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('folds a \\r progress bar to its final frame', (tester) async {
    await tester.pumpWidget(_host(const AnTermTail(text: 'Build\n[10%]\r[55%]\r[100%] done')));
    await tester.pumpAndSettle();
    expect(find.textContaining('[100%] done'), findsOneWidget);
    expect(find.textContaining('[10%]'), findsNothing); // overwritten
  });

  testWidgets('shows the last N lines + a top fade when output scrolled off above', (tester) async {
    final many = List.generate(20, (i) => 'line $i').join('\n');
    await tester.pumpWidget(_host(AnTermTail(text: many, tailLines: 6)));
    await tester.pumpAndSettle();
    expect(find.text('line 19'), findsOneWidget); // last line shown
    expect(find.text('line 0'), findsNothing); // scrolled off
    expect(find.byType(AnEdgeFade), findsOneWidget); // top fade (more above)
  });

  testWidgets('no fade when everything fits', (tester) async {
    await tester.pumpWidget(_host(const AnTermTail(text: 'a\nb\nc', tailLines: 6)));
    await tester.pumpAndSettle();
    expect(find.byType(AnEdgeFade), findsNothing);
  });

  testWidgets('renders ANSI colors as themed spans (does not print raw escapes)', (tester) async {
    await tester.pumpWidget(_host(AnTermTail(text: '$_esc[31mERROR$_esc[0m')));
    await tester.pumpAndSettle();
    // The escape codes must NOT appear as literal text. 转义码不得作字面出现。
    expect(find.textContaining(_esc), findsNothing);
    expect(find.textContaining('ERROR'), findsOneWidget);
  });
}
