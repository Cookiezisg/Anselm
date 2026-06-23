import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnAutoGrid = CSS repeat(auto-fit, minmax(W,1fr)): N equal columns (each ≥ minColWidth) filling the
// row, collapsing to one column when narrow, each row sized to its content. AnAutoGrid 响应式块网格契约。
void main() {
  List<Widget> cells(int n) => [for (var i = 0; i < n; i++) Container(key: ValueKey('c$i'), height: 20)];
  double cellW(WidgetTester tester, int i) => tester.getSize(find.byKey(ValueKey('c$i'))).width;

  // Pump AnAutoGrid filling a surface of the given width (default test surface is only 800px, which
  // would clamp wider layouts). 把测试画布设成指定宽,AnAutoGrid 直接铺满(默认 800 会夹窄)。
  Future<void> pumpAt(WidgetTester tester, double width, List<Widget> children) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnAutoGrid(children: children))));
  }

  testWidgets('fits N equal columns by width (gap-compensated, columns fill the row)', (tester) async {
    await pumpAt(tester, 900, cells(6));
    // n = floor((900+16)/(280+16)) = 3; colW = floor((900 - 2*16)/3) = 289
    for (var i = 0; i < 6; i++) {
      expect(cellW(tester, i), 289.0, reason: 'all columns equal width, filling the row');
    }
  });

  testWidgets('collapses to ONE column when narrower than minColWidth', (tester) async {
    await pumpAt(tester, 200, cells(3));
    for (var i = 0; i < 3; i++) {
      expect(cellW(tester, i), 200.0); // single full-width column
    }
  });

  testWidgets('few children in a wide container stretch to fill (auto-fit, not auto-fill)', (tester) async {
    await pumpAt(tester, 1200, cells(2));
    // n = min(floor((1200+16)/296)=4, 2) = 2; colW = floor((1200-16)/2) = 592
    expect(cellW(tester, 0), 592.0);
    expect(cellW(tester, 1), 592.0);
  });

  testWidgets('empty children → renders nothing, no exception', (tester) async {
    await pumpAt(tester, 400, const []);
    expect(tester.takeException(), isNull);
    expect(find.byType(AnAutoGrid), findsOneWidget);
  });

  testWidgets('unbounded width → single-column fallback, no crash', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Row(children: [AnAutoGrid(children: cells(3))])), // Row → unbounded maxWidth
    ));
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('c$i')), findsOneWidget);
    }
  });
}
