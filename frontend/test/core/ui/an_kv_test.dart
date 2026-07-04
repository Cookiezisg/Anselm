import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/typography.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
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

  // The edit pencil is hover-gated (idle 0-width so the value rests flush-right); hover the editable
  // row to reveal + enable it (as on desktop). 铅笔悬停门控(静态 0 宽让值贴右);悬停编辑行揭示可点。
  Future<void> revealPencil(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(AnEditableValue).first));
    addTearDown(g.removePointer);
    await tester.pumpAndSettle();
  }

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
    await revealPencil(tester);
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

  testWidgets('mono value uses mono+tabular style; a NON-mono value is still tabular (值列 tabular 铁律)', (tester) async {
    await tester.pumpWidget(host(const AnKv(mono: true, rows: [AnKvRow('Run', 'run_3a9f0e88')])));
    final mono = tester.widget<Text>(find.text('run_3a9f0e88'));
    expect(mono.style?.fontFamily, AnText.mono.fontFamily, reason: 'mono value uses the monospace family');
    expect(mono.style?.fontFeatures, contains(const FontFeature.tabularFigures()), reason: 'mono value is tabular');
    // The value column is tabular UNCONDITIONALLY — even without mono (the documented 铁律). 非 mono 也 tabular。
    await tester.pumpWidget(host(const AnKv(rows: [AnKvRow('Name', 'normalize')])));
    final plain = tester.widget<Text>(find.text('normalize'));
    expect(plain.style?.fontFeatures, contains(const FontFeature.tabularFigures()),
        reason: 'value column is tabular even without mono');
  });

  testWidgets('values of editable + read-only rows share one flush-right column', (tester) async {
    // The reported bug: values parked mid-row at inconsistent x. Now every value (editable display value
    // and read-only value alike) right-aligns to the same column. 报告的 bug:值停在行中、起点不一;现共一贴右列。
    await tester.pumpWidget(host(AnKv(
      onChanged: (_) {},
      rows: const [
        AnKvRow('Name', 'normalize-input', editable: true), // editable (pencil) display value
        AnKvRow('Created', '2026-06-24'), // read-only value
      ],
    )));
    final editableValueRight = tester.getRect(find.text('normalize-input')).right;
    final readonlyValueRight = tester.getRect(find.text('2026-06-24')).right;
    expect((editableValueRight - readonlyValueRight).abs(), lessThan(1.0),
        reason: 'editable and read-only values must share the same right edge');
  });
}
