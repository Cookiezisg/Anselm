import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnMenu = floating menu on AnPopover: section labels + items (icon/check/meta, danger/disabled). Picking
// closes unless keepOpen. AnMenu 契约。
void main() {
  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  Widget menu({required List<AnMenuEntry> entries}) => AnMenu(
        anchorBuilder: (context, toggle, isOpen) =>
            AnButton(label: 'Open', onPressed: toggle),
        entries: entries,
      );

  testWidgets('tapping the anchor opens the menu; items + section label render', (tester) async {
    await tester.pumpWidget(host(menu(entries: [
      const AnMenuSection('Section'),
      AnMenuItem(label: 'Edit', onTap: () {}),
      AnMenuItem(label: 'Delete', danger: true, onTap: () {}),
    ])));
    expect(find.text('Edit'), findsNothing); // closed
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('picking an item fires onTap and closes the menu', (tester) async {
    var picked = 0;
    await tester.pumpWidget(host(menu(entries: [AnMenuItem(label: 'Edit', onTap: () => picked++)])));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.text('Edit'), findsNothing); // closed after pick
  });

  testWidgets('keepOpen item stays open after a tap (multi-check toggle)', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(host(menu(entries: [AnMenuItem(label: 'Show versions', checked: true, keepOpen: true, onTap: () => toggles++)])));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show versions'));
    await tester.pumpAndSettle();
    expect(toggles, 1);
    expect(find.text('Show versions'), findsOneWidget); // still open
  });

  testWidgets('disabled item does not fire / does not close', (tester) async {
    var picked = 0;
    await tester.pumpWidget(host(menu(entries: [AnMenuItem(label: 'Archive', disabled: true, onTap: () => picked++)])));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, 0);
    expect(find.text('Archive'), findsOneWidget); // still open (inert)
  });
}
