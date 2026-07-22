import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/editor/an_editor.dart';
import 'package:anselm/core/editor/an_editor_markdown.dart';
import 'package:anselm/core/editor/an_editor_table.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_text_layout/super_text_layout.dart' show BlinkController;

// ④ The EDITABLE table (an_editor_table.dart): pure grid ops + the cell-editing seam (SuperTextField per
// cell → whole-node ReplaceNodeRequest) + the right-click structural menu. 可编辑表格测试电池。

TableBlockNode _table3x2() => documentFromMarkdown(
  '| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |',
).toList().whereType<TableBlockNode>().first;

Widget _host(String markdown, {ValueChanged<String>? onChanged}) =>
    TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(
          body: AnEditor(
            initialMarkdown: markdown,
            onChangedMarkdown: onChanged,
          ),
        ),
      ),
    );

void main() {
  TranslationProvider.of;
  LocaleSettings.setLocaleRaw('en');
  setUp(() => BlinkController.indeterminateAnimationsEnabled = false);
  tearDown(() => BlinkController.indeterminateAnimationsEnabled = true);

  group('pure grid ops', () {
    test('cell text swap keeps the node id, cell ids, and cell metadata', () {
      final table = _table3x2();
      final next = tableWithCellText(table, 1, 0, AttributedText('edited'));
      expect(
        next.id,
        table.id,
        reason: 'same node id — the ReplaceNodeRequest seam',
      );
      expect(
        next.getCell(rowIndex: 1, columnIndex: 0).id,
        table.getCell(rowIndex: 1, columnIndex: 0).id,
      );
      expect(
        next.getCell(rowIndex: 1, columnIndex: 0).text.toPlainText(),
        'edited',
      );
      expect(
        next.getCell(rowIndex: 1, columnIndex: 1).text.toPlainText(),
        '2',
        reason: 'others untouched',
      );
    });

    test('row insert/remove reshape the grid and keep every other row', () {
      final table = _table3x2();
      final inserted = tableWithRowInserted(table, 1);
      expect(inserted.rowCount, 4);
      expect(
        inserted.getCell(rowIndex: 1, columnIndex: 0).text.toPlainText(),
        isEmpty,
        reason: 'fresh empty row',
      );
      expect(
        inserted.getCell(rowIndex: 2, columnIndex: 0).text.toPlainText(),
        '1',
        reason: 'old row shifted down',
      );
      final removed = tableWithRowRemoved(inserted, 1);
      expect(removed.rowCount, 3);
      expect(
        removed.getCell(rowIndex: 1, columnIndex: 0).text.toPlainText(),
        '1',
      );
    });

    test('column insert/remove reshape every row', () {
      final table = _table3x2();
      final inserted = tableWithColumnInserted(table, 1);
      expect(inserted.columnCount, 3);
      for (var r = 0; r < inserted.rowCount; r++) {
        expect(
          inserted.getCell(rowIndex: r, columnIndex: 1).text.toPlainText(),
          isEmpty,
        );
      }
      expect(
        inserted.getCell(rowIndex: 0, columnIndex: 2).text.toPlainText(),
        'B',
        reason: 'old column shifted',
      );
      final removed = tableWithColumnRemoved(inserted, 1);
      expect(removed.columnCount, 2);
      expect(
        removed.getCell(rowIndex: 0, columnIndex: 1).text.toPlainText(),
        'B',
      );
    });

    test(
      'a structurally-edited table still serializes as a markdown table',
      () {
        final table = _table3x2();
        final doc = MutableDocument(nodes: [tableWithRowInserted(table, 3)]);
        final md = markdownFromDocument(doc);
        expect(
          md.split('\n').where((l) => l.startsWith('|')).length,
          5,
          reason: 'header + delimiter + 3 data rows',
        );
      },
    );
  });

  group('editable table widget', () {
    testWidgets(
      'typing in a cell lands in the serialized markdown (the ReplaceNode seam)',
      (tester) async {
        String? latest;
        await tester.pumpWidget(
          _host(
            '| A | B |\n| --- | --- |\n| 1 | 2 |',
            onChanged: (md) => latest = md,
          ),
        );
        await tester.pumpAndSettle();

        // Focus the '1' cell's field (cells render as SuperTextFields in row-major order: A,B,1,2). 点进 '1' 格。
        await tester.tap(find.byType(SuperTextField).at(2));
        await tester.pumpAndSettle();
        await tester.ime.typeText(
          'X',
          // Four cells (plus the document editor) own IME clients — pin the '1' cell's inner text field
          // (the desktop shell is a descendant of SuperTextField). 多个 IME 宿主并存,钉住 '1' 格的内芯字段。
          getter: () => imeClientGetter(
            find.descendant(
              of: find.byType(SuperTextField).at(2),
              matching: find.byType(SuperDesktopTextField),
            ),
          ),
        );
        // The cell edit runs a whole-node replace; serialization rides the autosave debounce. 逐键整节点替换;
        // 序列化走 autosave 防抖。
        await tester.pump(AnMotion.autosave);
        await tester.pumpAndSettle();

        expect(latest, isNotNull);
        expect(
          latest!,
          contains('1X'),
          reason: 'the cell edit reached the node and the codec',
        );
        expect(
          latest!,
          contains('| A | B |'),
          reason: 'still a markdown table',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'right-click a cell opens the structural menu; "insert row below" grows the table',
      (tester) async {
        String? latest;
        await tester.pumpWidget(
          _host(
            '| A | B |\n| --- | --- |\n| 1 | 2 |',
            onChanged: (md) => latest = md,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byType(SuperTextField).at(2),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();
        final t = AppLocaleUtils.parse('en').buildSync().library.table;
        expect(
          find.text(t.insertRowBelow),
          findsOneWidget,
          reason: 'the context menu is open',
        );
        expect(find.text(t.deleteTable), findsOneWidget);

        await tester.tap(find.text(t.insertRowBelow));
        await tester.pump(AnMotion.autosave);
        await tester.pumpAndSettle();
        expect(latest, isNotNull);
        expect(
          latest!.split('\n').where((l) => l.trimLeft().startsWith('|')).length,
          4,
          reason: 'header + delimiter + 2 data rows after the insert',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the header row cannot be deleted (GFM needs it) — its delete row item is disabled',
      (tester) async {
        await tester.pumpWidget(_host('| A | B |\n| --- | --- |\n| 1 | 2 |'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byType(SuperTextField).at(0),
          buttons: kSecondaryButton,
        ); // header cell 表头格
        await tester.pumpAndSettle();
        final t = AppLocaleUtils.parse('en').buildSync().library.table;
        // The row exists but is inert (AnMenuRow disabled → dimmed, no onTap). 行在但惰化。
        expect(find.text(t.deleteRow), findsOneWidget);
        await tester.tap(find.text(t.deleteRow));
        await tester.pumpAndSettle();
        expect(
          find.text(t.deleteRow),
          findsOneWidget,
          reason: 'disabled row does not act (menu still open)',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
