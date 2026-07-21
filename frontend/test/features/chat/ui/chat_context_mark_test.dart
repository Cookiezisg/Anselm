import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/chat/ui/chat_context_mark.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The context-compaction whisper. Pins: the count is parsed off the backend English marker and rendered
// localized; a countless/odd marker degrades to the bare localized label; injection is inert; no overflow.

Widget _host(String marker, {double width = 680}) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: ChatContextMark(marker: marker),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('parses the count off the marker → localized sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        'Context compacted — 42 earlier blocks folded into the running summary.',
      ),
    );
    expect(find.textContaining('42'), findsOneWidget);
    expect(
      find.textContaining('上下文已压缩'),
      findsOneWidget,
    ); // localized, not the English marker
    expect(
      find.textContaining('Context compacted', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('a countless marker → the bare localized label', (tester) async {
    await tester.pumpWidget(_host('Context compacted.'));
    expect(find.text(t.chat.contextCompacted), findsOneWidget);
  });

  testWidgets('empty marker → bare label, no throw', (tester) async {
    await tester.pumpWidget(_host(''));
    expect(tester.takeException(), isNull);
    expect(find.text(t.chat.contextCompacted), findsOneWidget);
  });

  testWidgets('injection + overlong marker: inert, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        'Context compacted — 7 <script>alert(1)</script> ${'x' * 200}',
        width: 300,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('7'), findsOneWidget); // still parses the count
  });
}
