import 'package:anselm/core/design/theme.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:anselm/core/ui/an_path_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// AnPathChip (B4 F01.2, WRK-056 #16) — basename display + full path on hover + tap-to-copy the full
// path, tolerant of a partial path. 路径芯片:显 basename、hover 全路径、点击复制全路径。

// The chip head consumes slang (copy tooltip voice) — host like the app. 当家件消费 slang,宿主如 app。
Widget _host(Widget c) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: c)),
  ),
);

void main() {
  testWidgets('shows the basename, not the full path', (tester) async {
    await tester.pumpWidget(
      _host(const AnPathChip(path: '/Users/x/project/src/parser/lexer.dart')),
    );
    await tester.pumpAndSettle();
    expect(find.text('lexer.dart'), findsOneWidget);
    expect(
      find.text('/Users/x/project/src/parser/lexer.dart'),
      findsNothing,
    ); // full path only on hover
  });

  testWidgets('a trailing slash / no slash / partial path degrade gracefully', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AnPathChip(path: '/a/b/dir/')));
    await tester.pumpAndSettle();
    expect(find.text('dir'), findsOneWidget); // trailing slash trimmed
    await tester.pumpWidget(_host(const AnPathChip(path: 'bare')));
    await tester.pumpAndSettle();
    expect(find.text('bare'), findsOneWidget); // no slash → whole
  });

  testWidgets('tap copies the FULL path (not the basename)', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(_host(const AnPathChip(path: '/a/b/c.dart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AnPathChip));
    await tester.pump();
    expect(copied, ['/a/b/c.dart']); // the FULL path, not 'c.dart'
    await tester.pump(
      const Duration(seconds: 1),
    ); // let the ✓-revert timer fire before teardown
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}
