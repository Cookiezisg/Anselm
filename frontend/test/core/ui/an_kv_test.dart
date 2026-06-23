import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnKv = compact definition list. Read-only rows = one merged "label: value" node; editable rows edit
// in place via AnEditableValue and emit the WHOLE list on change. AnKv 紧凑定义列表契约。
void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
        ),
      );

  testWidgets('renders rows; read-only value shows; empty → em-dash', (tester) async {
    await tester.pumpWidget(host(const AnKv(rows: [
      AnKvRow('Name', 'normalize'),
      AnKvRow('Owner', null), // empty → —
    ])));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('normalize'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // read-only: no fields
  });

  testWidgets('read-only row is a single merged "label: value" semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const AnKv(rows: [AnKvRow('Type', 'function')])));
    expect(find.bySemanticsLabel('Type: function'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('editable row: pencil → edit → Enter emits the whole list with that row updated', (tester) async {
    List<AnKvRow>? emitted;
    var rows = const [
      AnKvRow('Name', 'old', editable: true),
      AnKvRow('Type', 'function'),
    ];
    await tester.pumpWidget(host(StatefulBuilder(
      builder: (ctx, ss) => AnKv(
        rows: rows,
        onChanged: (r) => ss(() {
          rows = r;
          emitted = r;
        }),
      ),
    )));
    await tester.tap(find.byIcon(AnIcons.edit)); // only the editable row has a pencil
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(emitted, isNotNull);
    expect(emitted!.map((r) => r.value), ['new', 'function']); // row 0 updated, row 1 untouched
    expect(emitted![0].editable, isTrue); // editability preserved
  });

  testWidgets('null onChanged → all rows read-only even if marked editable', (tester) async {
    await tester.pumpWidget(host(const AnKv(rows: [AnKvRow('Name', 'x', editable: true)])));
    expect(find.byIcon(AnIcons.edit), findsNothing); // no pencil without onChanged
  });

  testWidgets('mono value renders (tabular)', (tester) async {
    await tester.pumpWidget(host(const AnKv(mono: true, rows: [AnKvRow('Run', 'run_3a9f0e88')])));
    expect(find.text('run_3a9f0e88'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
