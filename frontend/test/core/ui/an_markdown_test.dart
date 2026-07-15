import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnMarkdown — the pins the gallery matrix can't assert: the link-scheme gate (javascript:/data: inert,
// http fires the callback, NOTHING ever launches — structurally: this facade has no url_launcher import),
// bold really lands w400 + wght axis (the whole point of _AnBoldMd — the package default renders w300 on
// our pinned VF), heading downshift, inline-code chip anatomy, fenced code → AnCodeEditor (incl. the
// unclosed-fence streaming mid-state), table → AnProseTable bordered grid with per-column align + rich cells, image → inert chip with
// zero Image widgets (flutter test would crash on a real network fetch anyway — double insurance), raw
// HTML literal, and the theme-flip span-regeneration (isSame/style mechanics — the easiest silent break).
//
// AnMarkdown 专项钉子:链接 scheme 闸/加粗真 w400+wght 轴/标题降档/内联 chip/围栏→AnCodeEditor(含未闭合流式
// 中间态)/表→AnProseTable 有框网格·逐列对齐·富单元格/图片零 Image/HTML 字面/主题翻转 span 再生成(最易悄悄退化)。

void main() {
  Widget host(Widget child, {ThemeData? theme}) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme ?? AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 620, child: child))),
        ),
      );

  // Walk every RichText span; collect (text, style, recognizer) triples. 遍历 span 树收集三元组。
  List<(String, TextStyle?, GestureRecognizer?)> spans(WidgetTester tester) {
    final out = <(String, TextStyle?, GestureRecognizer?)>[];
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          out.add((span.text!, span.style, span.recognizer));
        }
        return true;
      });
    }
    return out;
  }

  (String, TextStyle?, GestureRecognizer?) spanWhere(WidgetTester tester, String needle) =>
      spans(tester).firstWhere((s) => s.$1.contains(needle));

  group('links', () {
    // Links render as a LinkButton (WidgetSpan + GestureDetector), not a span recognizer — assert by
    // REAL tap. 链接渲成 LinkButton(WidgetSpan+GestureDetector)、非 span recognizer——真点击断言。
    testWidgets('allowed scheme fires the callback exactly once; style is accent', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(host(AnMarkdown('see [docs](https://x.dev/a)', onLinkTap: (u, t) => taps.add(u))));
      final (_, style, _) = spanWhere(tester, 'docs');
      expect(style?.color, AnColors.light.accent);
      await tester.tap(find.textContaining('docs'));
      expect(taps, ['https://x.dev/a']);
    });

    testWidgets('javascript:/data:/file:/weird/relative are inert (callback never fires)', (tester) async {
      final taps = <String>[];
      const md = '[jsA](javascript:alert(1))\n\n[jsB](JAVASCRIPT:x)\n\n[dataC](data:text/html,x)\n\n'
          '[fileD](file:///etc/passwd)\n\n[weirdE](weird://x)\n\n[relF](/relative)';
      await tester.pumpWidget(host(AnMarkdown(md, onLinkTap: (u, t) => taps.add(u))));
      for (final label in ['jsA', 'jsB', 'dataC', 'fileD', 'weirdE', 'relF']) {
        await tester.tap(find.textContaining(label));
      }
      expect(taps, isEmpty);
    });

    testWidgets('null onLinkTap: tapping an allowed link is a safe no-op', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('[docs](https://x.dev)')));
      await tester.tap(find.textContaining('docs')); // must not throw 不抛
    });
  });

  group('two-weight rule', () {
    testWidgets('**bold** lands w400 AND the wght axis (the axis is what actually renders)', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('normal **bold** tail')));
      final (_, bold, _) = spanWhere(tester, 'bold');
      expect(bold?.fontWeight, FontWeight.w400);
      expect(bold?.fontVariations, contains(const FontVariation('wght', 400)),
          reason: 'without the axis the pinned wght(300) wins and bold renders as w300');
      final (_, body, _) = spanWhere(tester, 'normal');
      expect(body?.fontWeight, FontWeight.w300);
    });

    testWidgets('# heading downshifts to readingH1 22/w400 (never 32, never >w400)', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('# Title')));
      final (_, style, _) = spanWhere(tester, 'Title');
      expect(style?.fontSize, 22);
      expect(style?.fontWeight, FontWeight.w400);
    });
  });

  group('code', () {
    testWidgets('inline `code` renders mono on a surfaceSunken chip', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('use `retries` here')));
      final text = tester.widget<Text>(find.text('retries'));
      expect(text.style?.fontFamily, 'JetBrains Mono');
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('retries'), matching: find.byType(Container)).first,
      );
      expect((box.decoration as BoxDecoration?)?.color, AnColors.light.surfaceSunken);
    });

    testWidgets('fenced code renders AnCodeEditor; unclosed fence (streaming) survives + closes cleanly',
        (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('```py\nprint(')));
      expect(find.byType(AnCodeEditor), findsOneWidget); // optimistic open-render 乐观渲染
      await tester.pumpWidget(host(const AnMarkdown('```py\nprint(1)\n```\ndone')));
      expect(find.byType(AnCodeEditor), findsOneWidget);
      expect(find.textContaining('done'), findsOneWidget);
    });
  });

  group('tables', () {
    // Chat tables are the bordered [AnProseTable] (1:1 with the document editor), NOT the borderless
    // AnThinTable; cells parse rich; the :--:/--: separators drive per-column TextAlign. 有框表 1:1、富单元格。
    testWidgets('md table → AnProseTable hairline grid; :-:/--: drive per-column align; cells parse rich',
        (tester) async {
      const md = '| a | b | c |\n|:--|:-:|--:|\n| **x** | 2 | 3 |\n| 4 | 5 | 6 |';
      await tester.pumpWidget(host(const AnMarkdown(md)));
      expect(find.byType(AnProseTable), findsOneWidget);
      expect(find.byType(AnThinTable), findsNothing); // AnThinTable retired from the markdown path
      final table = tester.widget<Table>(
          find.descendant(of: find.byType(AnProseTable), matching: find.byType(Table)));
      // hairline grid border in the line token
      expect(table.border?.top.width, AnSize.hairline);
      // 1 header + 2 data rows, exactly 3 cells each (header defines the column count)
      expect(table.children, hasLength(3));
      expect(table.children.every((r) => r.children.length == 3), isTrue);
      // per-column alignment reaches the cell text — the header row's cells, in tree order, are
      // left / center / right. (left may surface as start; center + right are the unambiguous pins.)
      final aligns = tester
          .widgetList<RichText>(find.descendant(of: find.byType(AnProseTable), matching: find.byType(RichText)))
          .map((r) => r.textAlign)
          .toList();
      expect(aligns[1], TextAlign.center);
      expect(aligns[2], TextAlign.right);
      // rich cell: **x** lands the emphasis weight (w400) — cells are parsed, not flattened.
      expect(spanWhere(tester, 'x').$2?.fontWeight, AnText.emphasisWeight);
    });

    testWidgets('cells with inline-code / link WidgetSpans render without throwing (intrinsic-width guard)',
        (tester) async {
      // A cell rendered via MdWidget can contain WidgetSpans (inline-code chip, link). Inside a Flutter
      // Table these get measured for intrinsic width — historically that THREW ("Intrinsics not available
      // for PlaceholderSpans"); the current pinned SDK measures them. This locks that: a code+link table
      // builds cleanly. 富单元格(码 chip/链接=WidgetSpan)在 Table 里要测 intrinsic;旧 SDK 会炸,此测钉住不炸。
      const md = '| a | b |\n|---|---|\n| `code` | [site](https://e.com) |';
      await tester.pumpWidget(host(const AnMarkdown(md)));
      expect(tester.takeException(), isNull);
      expect(find.byType(AnProseTable), findsOneWidget);
    });

    testWidgets('ragged rows normalize to the header column count (no crash, uniform Table rows)',
        (tester) async {
      const md = '| a | b |\n|---|---|\n| 1 | 2 | extra |\n| x |';
      await tester.pumpWidget(host(const AnMarkdown(md)));
      final table = tester.widget<Table>(
          find.descendant(of: find.byType(AnProseTable), matching: find.byType(Table)));
      // A Flutter Table THROWS on ragged rows, so every row (header + the over-wide + under-wide data rows)
      // MUST have the SAME cell count — our builder pads/clips each row to the header width. 参差归一、无参差即不炸。
      final widths = table.children.map((r) => r.children.length).toSet();
      expect(widths, hasLength(1)); // uniform → no crash
      expect(table.children, hasLength(3)); // header + 2 data rows
    });
  });

  group('injection / safety', () {
    testWidgets('raw HTML renders literally (<script>, <u> — UnderLineMd stripped)', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('<script>alert(1)</script> and <u>plain</u>')));
      expect(find.textContaining('<script>alert(1)</script>'), findsOneWidget);
      expect(find.textContaining('<u>plain</u>'), findsOneWidget);
    });

    testWidgets('images never fetch: zero Image widgets, inert placeholder chip instead', (tester) async {
      await tester.pumpWidget(host(const AnMarkdown('![alt](https://evil.example/x.png)')));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(AnIcons.image), findsOneWidget);
      expect(find.textContaining('evil.example'), findsOneWidget); // the URL is visible, not fetched
    });
  });

  testWidgets('theme flip regenerates spans (link color follows dark accent)', (tester) async {
    await tester.pumpWidget(host(const AnMarkdown('[x](https://x.dev)')));
    expect(spanWhere(tester, 'x').$2?.color, AnColors.light.accent);
    await tester.pumpWidget(host(const AnMarkdown('[x](https://x.dev)'), theme: AnTheme.dark()));
    await tester.pumpAndSettle();
    expect(spanWhere(tester, 'x').$2?.color, AnColors.dark.accent,
        reason: 'isSame() compares style — a colourless style would leave stale light-theme spans');
  });
}
