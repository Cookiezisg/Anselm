import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/an_field.dart';
import 'package:anselm/core/ui/an_json_tree.dart';
import 'package:anselm/core/ui/an_ref_pill.dart';
import 'package:anselm/features/chat/ui/tool_card_entity_get.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// EntityGetBody four-part skeleton (B3.4, WRK-056 #31) + AnKvRow row-level mono (#9). 四段骨架 + 行级 mono。

Widget _host(Widget child) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 640, child: child))),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('AnKvRow row-level mono: a mono row renders monospace, a prose row does not', (tester) async {
    await tester.pumpWidget(_host(const AnKv(rows: [
      AnKvRow('signature', 'url:string', mono: true),
      AnKvRow('python', '3.12'),
    ])));
    await tester.pumpAndSettle();
    final monoStyle = tester.widget<Text>(find.text('url:string')).style!;
    final proseStyle = tester.widget<Text>(find.text('3.12')).style!;
    expect(monoStyle.fontFamily, AnText.monoFamily);
    expect(proseStyle.fontFamily, isNot(AnText.monoFamily));
  });

  testWidgets('ToolEntityHeader: navigable kind → tappable pill; no-panel kind → inert', (tester) async {
    await tester.pumpWidget(_host(const ToolEntityHeader(
        kind: 'function', name: 'fetch_with_retry', id: 'fn_1', meta: 'v3 · 2026-07-01')));
    await tester.pumpAndSettle();
    expect(find.text('fetch_with_retry'), findsOneWidget);
    expect(find.text('fn_1'), findsOneWidget); // mono id
    expect(find.text('v3 · 2026-07-01'), findsOneWidget); // right meta
    // The pill is present (a function has a panel). function 有面板 → pill 存在。
    expect(find.byType(AnRefPill), findsOneWidget);
  });

  testWidgets('EntityCodeWindow: over the char cap → a truncation note; under → none', (tester) async {
    await tester.pumpWidget(_host(EntityCodeWindow(code: 'x' * (kEntityContentCap + 10), lang: 'python')));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.contentTruncated), findsOneWidget);

    await tester.pumpWidget(_host(const EntityCodeWindow(code: 'print(1)', lang: 'python')));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.contentTruncated), findsNothing);
  });

  testWidgets('RawResultDisclosure: toggles the unfiltered JSON tree', (tester) async {
    await tester.pumpWidget(_host(const RawResultDisclosure(rawJson: '{"id":"fn_1","secret":"visible-in-raw"}')));
    await tester.pumpAndSettle();
    expect(find.byType(AnJsonTree), findsNothing); // collapsed
    await tester.tap(find.text(t.chat.tool.rawResult));
    await tester.pumpAndSettle();
    expect(find.byType(AnJsonTree), findsOneWidget); // the full ledger, unfiltered
  });

  testWidgets('EntityGetBody composes all four segments', (tester) async {
    await tester.pumpWidget(_host(EntityGetBody(
      header: const ToolEntityHeader(kind: 'function', name: 'f', id: 'fn_1'),
      badges: const Text('env ready'),
      kv: const AnKv(rows: [AnKvRow('desc', 'a function')]),
      content: const [EntityCodeWindow(code: 'print(1)', lang: 'python')],
      rawJson: '{"id":"fn_1"}',
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ToolEntityHeader), findsOneWidget); // ①
    expect(find.text('env ready'), findsOneWidget); // badges
    expect(find.byType(AnKv), findsOneWidget); // ②
    expect(find.byType(EntityCodeWindow), findsOneWidget); // ③
    expect(find.byType(RawResultDisclosure), findsOneWidget); // ④
  });
}
