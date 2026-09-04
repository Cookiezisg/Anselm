import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_large_document_preview.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String repeat(String value, int count) => List.filled(count, value).join();

  Widget host(Widget sliver) => TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: CustomScrollView(
        slivers: [
          SliverPadding(padding: const EdgeInsets.all(24), sliver: sliver),
        ],
      ),
    ),
  );

  test('chunks preserve source and cap every render chunk', () {
    final source = '${repeat('a', 7000)}\nsecond';
    final chunks = AnLargeDocumentPreview.chunksOf(source, maxChars: 1000);

    expect(chunks.join(), source);
    expect(chunks.every((chunk) => chunk.length <= 1000), isTrue);
    expect(chunks, hasLength(8));
  });

  test('the valid API boundary uses the bounded face, including equality', () {
    final under = repeat('a', AnLargeDocumentPreview.maxInlineBytes - 1);
    final exact = repeat('a', AnLargeDocumentPreview.maxInlineBytes);
    final cjk = repeat('中', (AnLargeDocumentPreview.maxInlineBytes ~/ 3) + 1);

    expect(AnLargeDocumentPreview.requiresBoundedPreview(under), isFalse);
    expect(AnLargeDocumentPreview.requiresBoundedPreview(exact), isTrue);
    expect(AnLargeDocumentPreview.requiresBoundedPreview(cjk), isTrue);
  });

  testWidgets('large documents mount the safe face, not the rich editor', (
    tester,
  ) async {
    final source = repeat('a', AnLargeDocumentPreview.maxInlineBytes);
    await tester.pumpWidget(host(AnLargeDocumentPreview(markdown: source)));

    expect(find.byType(AnLargeDocumentPreview), findsOneWidget);
    expect(find.byType(AnEditor), findsNothing);
    expect(find.byType(AnButton), findsOneWidget);
  });
}
