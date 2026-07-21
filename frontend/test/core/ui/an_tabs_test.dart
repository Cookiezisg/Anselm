import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnTabs = text-underline switcher over an IndexedStack of keep-alive panes; controlled (value + onSelect).
// AnTabs 契约:下划线切换 + IndexedStack 隐藏不销毁 + 受控。
void main() {
  Widget host(Widget child, {double w = 400, double h = 300}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: w, height: h, child: child),
      ),
    ),
  );

  testWidgets('renders tab labels; tapping a tab picks it', (tester) async {
    var value = 'a';
    String? picked;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (ctx, ss) => AnTabs(
            items: const [
              AnTabsItem(key: 'a', label: 'Alpha', pane: Text('PANE A')),
              AnTabsItem(key: 'b', label: 'Beta', pane: Text('PANE B')),
            ],
            value: value,
            onSelect: (k) => ss(() {
              value = k;
              picked = k;
            }),
          ),
        ),
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      0,
    ); // A selected
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      1,
    ); // B selected
  });

  testWidgets('panes keep state across switches (IndexedStack keep-alive)', (
    tester,
  ) async {
    var value = 'a';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (ctx, ss) => AnTabs(
            items: const [
              AnTabsItem(key: 'a', label: 'A', pane: TextField()),
              AnTabsItem(key: 'b', label: 'B', pane: Text('B pane')),
            ],
            value: value,
            onSelect: (k) => ss(() => value = k),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'typed');
    await tester.pump();
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(
      find.text('typed'),
      findsOneWidget,
    ); // pane A's TextField state survived 状态保留
  });

  testWidgets('unknown value falls back to tab 0 consistently (highlight + pane agree)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        AnTabs(
          items: const [
            AnTabsItem(key: 'a', label: 'Alpha', pane: Text('A')),
            AnTabsItem(key: 'b', label: 'Beta', pane: Text('B')),
          ],
          value:
              'zzz', // not present in items — must clamp to tab 0 for ALL of pane/underline/highlight
          onSelect: (_) {},
        ),
      ),
    );
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    expect(
      tester
          .getSemantics(find.text('Alpha'))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isTrue,
      reason:
          'fallback tab 0 must read as selected (highlight + a11y agree with the shown pane)',
    );
    // The UNSELECTED tab says NOTHING about selection — not «false». `selected: false` is a lie on the
    // pinned engine (kFlutterTristateFalse == 2 is truthy in the bridge's bool param, so it announces as
    // SELECTED); absence is the only safe «no». See [AnA11y.selected] — this flips back to isFalse when
    // Flutter moves off 3.41.x. 未选中的 tab 对「选中」**什么都不说**、而非说 false:在钉住的引擎上 false 会被念成
    // 「已选中」,不说是唯一安全的「否」。升离 3.41.x 后这条改回 isFalse。
    expect(
      tester
          .getSemantics(find.text('Beta'))
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      isNull,
    );
    handle.dispose();
  });

  testWidgets('many tabs scroll horizontally without overflow', (tester) async {
    await tester.pumpWidget(
      host(
        AnTabs(
          items: [
            for (var i = 0; i < 12; i++)
              AnTabsItem(key: 't$i', label: 'Tab number $i', pane: Text('p$i')),
          ],
          value: 't0',
          onSelect: (_) {},
        ),
        w: 280,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
