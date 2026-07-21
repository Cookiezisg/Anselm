import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnThinTable = aligned multi-column display (built on Table). Header is header-semantics; a selectable
// row taps to onRowTap and carries a per-row button summary. AnThinTable 对齐多列契约。
void main() {
  Widget host(Widget child, {double width = 360}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  const cols = [
    AnTableColumn('name', label: 'Name'),
    AnTableColumn('status', label: 'Status', align: AnTableAlign.right),
  ];
  const rows = [
    {'name': 'deploy', 'status': 'running'},
    {'name': 'build', 'status': 'passed'},
  ];

  testWidgets('renders header labels + data cells', (tester) async {
    await tester.pumpWidget(host(const AnThinTable(columns: cols, rows: rows)));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('deploy'), findsOneWidget);
    expect(find.text('passed'), findsOneWidget);
  });

  testWidgets('header cells are header semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnThinTable(columns: cols, rows: rows)));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Name'))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('selectable: tapping a row → onRowTap with that row map', (
    tester,
  ) async {
    Map<String, String>? tapped;
    await tester.pumpWidget(
      host(
        AnThinTable(
          columns: cols,
          rows: rows,
          selectable: true,
          onRowTap: (r) => tapped = r,
        ),
      ),
    );
    await tester.tap(find.text('deploy'));
    expect(tapped, isNotNull);
    expect(tapped!['name'], 'deploy');
    expect(tapped!['status'], 'running');
  });

  testWidgets('selectable row first cell carries a button + row summary', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AnThinTable(
          columns: cols,
          rows: rows,
          selectable: true,
          onRowTap: (_) {},
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Name: deploy, Status: running'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('empty columns → renders nothing, no exception', (tester) async {
    await tester.pumpWidget(host(const AnThinTable(columns: [], rows: [])));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long value in a NON-first column shrinks within the table (no overflow)',
    (tester) async {
      // RenderTable never throws on overflow, so no-exception proves nothing — assert real geometry:
      // the (non-first) cell's text must not extend past the table's right edge. RenderTable 不报溢出,验真几何。
      const longStatus =
          'an-extremely-long-status-value-that-must-not-overflow-the-table-right-edge';
      await tester.pumpWidget(
        host(
          const AnThinTable(
            columns: cols,
            rows: [
              {'name': 'short', 'status': longStatus},
            ],
          ),
          width: 220,
        ),
      );
      final tableRight = tester.getBottomRight(find.byType(Table)).dx;
      final cellRight = tester.getBottomRight(find.text(longStatus)).dx;
      expect(
        cellRight,
        lessThanOrEqualTo(tableRight + 0.5),
        reason:
            'a long non-first value must ellipsis within the table, not paint past its right edge',
      );
    },
  );
}
