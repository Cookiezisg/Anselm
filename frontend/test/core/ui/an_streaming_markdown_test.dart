import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/an_markdown.dart';
import 'package:anselm/core/ui/an_streaming_markdown.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnStreamingMarkdown (S9) — the open-block markdown that commits prose past safe paragraph
// boundaries into identity-cached segments, so a streaming frame re-parses only the active tail.

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets(
    'a paragraph that streamed past a blank line becomes an identity-cached segment '
    '(identical widget across frames); the tail stays live',
    (tester) async {
      const p1 = 'First paragraph, fully streamed.';
      await tester.pumpWidget(
        _host(const AnStreamingMarkdown('$p1\n\nSecond para')),
      );
      // One settled segment (p1) + the live tail. 一段落定 + 活尾。
      final settledBefore = tester
          .widgetList<AnMarkdown>(find.byType(AnMarkdown))
          .first;
      expect(settledBefore.text, p1);

      // The tail grows — the settled segment must be the IDENTICAL instance (no re-parse).
      await tester.pumpWidget(
        _host(const AnStreamingMarkdown('$p1\n\nSecond paragraph grows…')),
      );
      final settledAfter = tester
          .widgetList<AnMarkdown>(find.byType(AnMarkdown))
          .first;
      expect(
        identical(settledAfter, settledBefore),
        isTrue,
        reason: 'settled segment: identical widget → element never rebuilds',
      );
      expect(find.textContaining('Second paragraph grows…'), findsOneWidget);
    },
  );

  testWidgets(
    'a blank line INSIDE an open fence is not a boundary — code stays whole',
    (tester) async {
      const md = '```py\na = 1\n\nb = 2\n\nStill code, not prose';
      await tester.pumpWidget(_host(const AnStreamingMarkdown(md)));
      // The whole thing is ONE live tail: a single code editor carrying both halves. 整体一个活尾。
      expect(find.byType(AnCodeEditor), findsOneWidget);
      final editor = tester.widget<AnCodeEditor>(find.byType(AnCodeEditor));
      expect(editor.code, contains('a = 1'));
      expect(editor.code, contains('b = 2'));

      // Once the fence CLOSES and a paragraph boundary follows, the code block settles as a segment.
      await tester.pumpWidget(
        _host(
          const AnStreamingMarkdown(
            '```py\na = 1\n\nb = 2\n```\n\nprose after the fence',
          ),
        ),
      );
      expect(find.byType(AnCodeEditor), findsOneWidget);
      expect(find.textContaining('prose after the fence'), findsOneWidget);
    },
  );

  testWidgets('indented code spanning blank lines is never split', (
    tester,
  ) async {
    const md = 'intro\n\n    code line 1\n\n    code line 2\n\ntail prose';
    await tester.pumpWidget(_host(const AnStreamingMarkdown(md)));
    // The guard refuses boundaries whose next content line is indented code — both code lines stay
    // in one region (rendered by one AnMarkdown, whatever its internal shape). 守卫拒切缩进码。
    final segments = tester
        .widgetList<AnMarkdown>(find.byType(AnMarkdown))
        .toList();
    final codeCarrier = segments.where(
      (s) => s.text.contains('code line 1') && s.text.contains('code line 2'),
    );
    expect(
      codeCarrier,
      isNotEmpty,
      reason: 'the indented block must live inside ONE segment',
    );
  });

  testWidgets('a REPLACED text (reconnect snapshot) resets honestly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const AnStreamingMarkdown('old alpha\n\nold beta tail')),
    );
    expect(find.textContaining('old alpha'), findsOneWidget);

    // Not an append — completely different content. 非追加,整替。
    await tester.pumpWidget(
      _host(const AnStreamingMarkdown('brand new content\n\nnew tail')),
    );
    expect(find.textContaining('brand new content'), findsOneWidget);
    expect(find.textContaining('old alpha'), findsNothing);
  });

  testWidgets('full-text content parity with a plain AnMarkdown render', (
    tester,
  ) async {
    const md =
        '# Title\n\npara one **bold**\n\n- item a\n- item b\n\n'
        '```dart\nfinal x = 1;\n```\n\nclosing para';
    await tester.pumpWidget(_host(const AnStreamingMarkdown(md)));
    // Every piece of content the plain renderer would show is present. 内容齐全。
    expect(find.textContaining('Title'), findsOneWidget);
    expect(find.textContaining('para one'), findsOneWidget);
    expect(find.textContaining('item a'), findsOneWidget);
    expect(find.textContaining('item b'), findsOneWidget);
    expect(find.byType(AnCodeEditor), findsOneWidget);
    expect(find.textContaining('closing para'), findsOneWidget);
  });
}
