import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnToolbar = three-region bar: leading | main(title+meta or center) | trailing. NOT a card unless
// [bordered]. The title left-packs + ellipsizes; trailing actions stay on the right. AnToolbar 契约。
void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
      );

  testWidgets('renders title + meta + trailing action', (tester) async {
    await tester.pumpWidget(host(AnToolbar(
      title: 'Source',
      meta: 'fn',
      trailing: [AnButton.iconOnly(AnIcons.more, semanticLabel: 'More', onPressed: () {})],
    )));
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('fn'), findsOneWidget);
    expect(find.byIcon(AnIcons.more), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('center slot renders when title/meta are null', (tester) async {
    await tester.pumpWidget(host(AnToolbar(center: AnButton(label: 'custom', size: AnButtonSize.sm, onPressed: () {}))));
    expect(find.text('custom'), findsOneWidget);
  });

  testWidgets('bordered adds top-bar chrome (taller via padding)', (tester) async {
    await tester.pumpWidget(host(const AnToolbar(title: 'Bar')));
    final plain = tester.getSize(find.byType(AnToolbar)).height;
    await tester.pumpWidget(host(const AnToolbar(bordered: true, title: 'Bar')));
    final bordered = tester.getSize(find.byType(AnToolbar)).height;
    expect(bordered, greaterThan(plain), reason: 'bordered adds vertical padding (top-bar chrome)');
    expect(find.text('Bar'), findsOneWidget);
  });

  testWidgets('compact is shorter than the standard row', (tester) async {
    await tester.pumpWidget(host(const AnToolbar(title: 'Std')));
    final std = tester.getSize(find.byType(AnToolbar)).height;
    await tester.pumpWidget(host(const AnToolbar(compact: true, title: 'Cmp')));
    final cmp = tester.getSize(find.byType(AnToolbar)).height;
    expect(cmp, lessThan(std), reason: 'compact (control) < standard (row)');
  });

  testWidgets('long title ellipsizes — trailing action stays on-panel', (tester) async {
    await tester.pumpWidget(host(AnToolbar(
      title: 'an-extremely-long-toolbar-title-that-must-ellipsis-and-not-push-the-actions-off-the-edge',
      trailing: [AnButton.iconOnly(AnIcons.more, semanticLabel: 'More', onPressed: () {})],
    ), width: 300));
    expect(tester.takeException(), isNull);
    final barRight = tester.getRect(find.byType(AnToolbar)).right;
    final actionRight = tester.getRect(find.byIcon(AnIcons.more)).right;
    expect(actionRight, lessThanOrEqualTo(barRight + 0.5), reason: 'trailing action must stay within the toolbar');
  });
}
