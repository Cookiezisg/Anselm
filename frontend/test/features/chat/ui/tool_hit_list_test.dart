import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_json_tree.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/features/chat/ui/tool_hit_list.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ToolHitList (B3.2, WRK-056 #10) — rows, panel-gated tappability (never a dead link), «当前» marker,
// the two DISTINCT footer states, and instant-when-not-animate. 命中行列:行/可点门控/当前记/双截断态。

ToolHitRow _hit(String kind, String id, String name, {String? snippet}) => ToolHitRow(
      glyph: AnIcons.entityKindGlyph(kind),
      title: name,
      subtitle: snippet,
      kind: kind,
      id: id,
      trailing: Text(id),
    );

final _rows = [
  _hit('function', 'fn_1', 'alpha', snippet: 'first'),
  _hit('function', 'fn_2', 'beta'),
  _hit('agent', 'ag_1', 'gamma'),
];

Widget _host(Widget child) => TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 600, child: child))),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('renders each row: title + subtitle + trailing', (tester) async {
    await tester.pumpWidget(_host(ToolHitList(rows: _rows, cap: 20)));
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('first'), findsOneWidget); // subtitle
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('fn_1'), findsOneWidget); // trailing id
  });

  testWidgets('a row is tappable iff its kind has a panel — fires (kind,id); no-panel kind is inert',
      (tester) async {
    (String, String)? tapped;
    await tester.pumpWidget(_host(ToolHitList(
      rows: [
        _hit('function', 'fn_1', 'alpha'),
        _hit('memory', 'mem_1', 'note'), // no panel → inert, no chevron, no callback
      ],
      cap: 20,
      onRowTap: (k, i) => tapped = (k, i),
    )));
    await tester.pumpAndSettle();
    // function row is tappable → a chevron; memory row is not.
    expect(find.byIcon(AnIcons.chevronRight), findsOneWidget);
    await tester.tap(find.text('alpha'));
    expect(tapped, ('function', 'fn_1'));
    // tapping the inert memory row does nothing (no callback wired to it).
    tapped = null;
    await tester.tap(find.text('note'));
    expect(tapped, isNull);
  });

  testWidgets('«当前» marker only on the currentId row', (tester) async {
    await tester.pumpWidget(_host(ToolHitList(rows: _rows, cap: 20, currentId: 'fn_2', onRowTap: (_, _) {})));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.hitCurrent), findsOneWidget);
  });

  testWidgets('LOCAL over-cap: escape-hatch footer → taps to the full bounded JSON tree', (tester) async {
    await tester.pumpWidget(_host(ToolHitList(
      rows: _rows,
      cap: 2, // 3 rows > cap
      rawJson: '{"count":3,"functions":[{"id":"fn_1"},{"id":"fn_2"},{"id":"ag_1"}]}',
      onRowTap: (_, _) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('gamma'), findsNothing); // capped out (3rd row)
    final footer = t.chat.tool.cappedFooter(n: '2', total: '3');
    expect(find.text(footer), findsOneWidget);
    await tester.tap(find.text(footer));
    await tester.pumpAndSettle();
    expect(find.byType(AnJsonTree), findsOneWidget); // swapped to the full result
  });

  testWidgets('SERVER truncated: a display-only note (no escape hatch, not tappable)', (tester) async {
    await tester.pumpWidget(_host(ToolHitList(
      rows: _rows,
      cap: 20,
      total: 47,
      serverTruncated: true,
      onRowTap: (_, _) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.tool.serverTruncatedNote(n: '3', total: '47')), findsOneWidget);
    // NOT the local escape hatch (they must never be conflated).
    expect(find.text(t.chat.tool.cappedFooter(n: '3', total: '47')), findsNothing);
  });

  testWidgets('animate:false → rows land at full opacity instantly (no cascade)', (tester) async {
    await tester.pumpWidget(_host(ToolHitList(rows: _rows, cap: 20)));
    await tester.pump(); // a single frame, no settle
    final op = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
    expect(op.every((o) => o == 1.0), isTrue, reason: 'no cascade when not animating');
  });
}
