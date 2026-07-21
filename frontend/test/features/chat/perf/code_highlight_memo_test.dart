import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_code_editor.dart';
import 'package:anselm/core/ui/syntax_highlighter.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// C-012/013/014 — the read-only code faces re-ran the full tokenizer every build (settled cards
// re-render on the 1s ticker / inside live turns), and the edit controller re-highlighted on every caret
// move. Both now cache the token spans on (code/text, colors). This probes highlightCodePasses: a no-op
// rebuild must NOT tokenize again; a code change must. 高亮记忆化:无变化重建/移光标不重分词。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  Widget host(String code) => TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: AnCodeEditor(code: code, lang: 'python'),
      ),
    ),
  );

  testWidgets('C-012/013 a rebuild with UNCHANGED code does not re-tokenize', (
    tester,
  ) async {
    await tester.pumpWidget(host('def a():\n    return 1'));
    final after1 = highlightCodePasses;
    expect(after1, greaterThan(0), reason: '首建分词一次');
    // Force a rebuild with the SAME code (a new widget instance, same props). 同码重建。
    await tester.pumpWidget(host('def a():\n    return 1'));
    expect(highlightCodePasses, after1, reason: '无变化重建→缓存命中,不重分词');
  });

  testWidgets(
    'C-012/013 a code CHANGE re-tokenizes (cache correctly invalidates)',
    (tester) async {
      await tester.pumpWidget(host('x = 1'));
      final before = highlightCodePasses;
      await tester.pumpWidget(host('x = 2'));
      expect(highlightCodePasses, greaterThan(before), reason: '码变→重分词');
      // The new content renders. 新内容渲染。
      expect(find.textContaining('2'), findsWidgets);
    },
  );
}
