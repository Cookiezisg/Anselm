import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_edge_fade.dart';
import 'package:anselm/core/ui/an_term_viewport.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnStickViewport + AnTermViewport (B4.4, WRK-056 #6) — bounded, stick-to-bottom terminal scrollback +
// lazy «show earlier». 有界钉底终端窗 + 懒加载更早。

Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 500, child: c)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets(
    'short output shows in full — no fade, no back-to-latest floater',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AnStickViewport(
            maxHeight: 320,
            child: Column(children: const [Text('a'), Text('b')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AnEdgeFade), findsNothing);
      expect(find.text(t.chat.tool.backToLatest), findsNothing);
    },
  );

  testWidgets(
    'a long log is bounded to maxHeight and pinned to the BOTTOM (terminal semantics)',
    (tester) async {
      final many = List.generate(60, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _host(AnTermViewport(text: many, maxHeight: 200)),
      );
      await tester.pumpAndSettle();
      // The viewport is bounded (< the natural height of 60 lines). 有界。
      final size = tester.getSize(find.byType(AnTermViewport));
      expect(size.height, lessThan(400));
      // Pinned to the bottom → the LAST line is visible, the first scrolled off. 钉底:末行可见、首行滚走。
      expect(find.text('line 59'), findsOneWidget);
      // A TOP fade exists (content scrolled off above); the «back to latest» floater does NOT (already at
      // the latest — it only appears after scrolling UP). 顶缘渐隐现;回到最新不现(已在最新)。
      expect(find.byType(AnEdgeFade), findsWidgets);
      expect(find.text(t.chat.tool.backToLatest), findsNothing);
    },
  );

  testWidgets('a huge log materializes only the tail + a «show earlier» button', (
    tester,
  ) async {
    final huge = 'x' * 8000; // one giant line > initialCharCap 6000
    await tester.pumpWidget(
      _host(AnTermViewport(text: huge, initialCharCap: 6000, maxHeight: 200)),
    );
    await tester.pumpAndSettle();
    // The «show earlier» affordance appears (tail-only materialization). 显示更早出现。
    expect(find.textContaining('显示更早'), findsOneWidget);
  });

  testWidgets('tapping «back to latest» is a no-op error-free interaction', (
    tester,
  ) async {
    final many = List.generate(60, (i) => 'line $i').join('\n');
    await tester.pumpWidget(_host(AnTermViewport(text: many, maxHeight: 200)));
    await tester.pumpAndSettle();
    // Scroll up to reveal the floater, then tap it. 上滚露浮标再点。
    await tester.drag(find.byType(AnTermViewport), const Offset(0, 300));
    await tester.pumpAndSettle();
    final floater = find.text(t.chat.tool.backToLatest);
    if (floater.evaluate().isNotEmpty) {
      await tester.tap(floater);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  // ── WRK-061 W0: fill-parent mode (the right island's full-page terminal) ────────────────────────

  testWidgets(
    'fill mode: a SHORT log still owns the whole parent height (maxHeight ignored)',
    (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 500,
                  height: 480,
                  child: AnTermViewport(
                    text: 'one\ntwo',
                    maxHeight: 200,
                    fill: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnTermViewport)).height, 480);
      expect(find.text('one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fill mode: a long log stays pinned to the bottom inside the filled page',
    (tester) async {
      final many = List.generate(200, (i) => 'row $i').join('\n');
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: AnTermViewport(text: many, fill: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('row 199'), findsOneWidget); // pinned to bottom 钉底:末行可见
      expect(tester.takeException(), isNull);
    },
  );
}
