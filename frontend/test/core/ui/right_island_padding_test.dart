import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_inspector.dart';
import 'package:anselm/core/ui/an_inspector_head.dart';
import 'package:anselm/core/ui/an_island.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// RIGHT-ISLAND INNER-PADDING SINGLE SOURCE (用户 0719): the wrapping [AnIsland]'s 12px is the ONE island
// inset; right-island consumer bodies add NO horizontal pad. So content lands its left edge at island + 12
// (row-family content then indents its own s8 → text at +20),逐像素同左岛 (island 12 + row 8). These locks
// pin the primitives every right-island face inherits. 右岛内距单源:岛壳 12 唯一,body 不自包水平 pad;
// 内容左缘=岛缘+12(行族+20 到文字),与左岛同几何。

void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(child: SizedBox(width: 320, height: 480, child: AnIsland(child: child))),
          ),
        ),
      );

  double islandLeft(WidgetTester tester) => tester.getRect(find.byType(AnIsland)).left;

  testWidgets('AnInspectorHead label lands at island + 12 (head adds no horizontal pad)', (tester) async {
    await tester.pumpWidget(host(const AnInspectorHead(label: 'PROBE')));
    await tester.pump();
    final labelLeft = tester.getTopLeft(find.text('PROBE')).dx;
    expect(labelLeft - islandLeft(tester), moreOrLessEquals(AnSpace.s12, epsilon: 1),
        reason: 'head label flush with the island pad edge (single-source law)');
  });

  testWidgets('AnInspector headless child fills to the island pad edge (island + 12)', (tester) async {
    await tester.pumpWidget(host(const AnInspector(
      headless: true,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(key: ValueKey('probe'), width: 10, height: 10)),
    )));
    await tester.pump();
    final probeLeft = tester.getTopLeft(find.byKey(const ValueKey('probe'))).dx;
    expect(probeLeft - islandLeft(tester), moreOrLessEquals(AnSpace.s12, epsilon: 1));
  });

  testWidgets('AnInspector (with head) body block lands at island + 12 (no horizontal body pad)', (tester) async {
    await tester.pumpWidget(host(const AnInspector(
      title: 'Overview',
      children: [Align(alignment: Alignment.topLeft, child: SizedBox(key: ValueKey('probe'), width: 10, height: 10))],
    )));
    await tester.pump();
    final probeLeft = tester.getTopLeft(find.byKey(const ValueKey('probe'))).dx;
    expect(probeLeft - islandLeft(tester), moreOrLessEquals(AnSpace.s12, epsilon: 1),
        reason: 'body block flush at island + 12 (was island + 12 + 16 = 28)');
  });

  testWidgets('a row-family row inside the island lands its TEXT at island + 20 (+ its own s8 frame)',
      (tester) async {
    await tester.pumpWidget(host(const AnInspector(
      headless: true,
      child: AnRow(label: 'row-label', leadless: true),
    )));
    await tester.pump();
    final textLeft = tester.getTopLeft(find.text('row-label')).dx;
    // island 12 + AnRow's own s8 imaginary frame = 20 to the text — 逐像素同左岛 rail. 与左岛逐像素同几何。
    expect(textLeft - islandLeft(tester), moreOrLessEquals(AnSpace.s12 + AnSpace.s8, epsilon: 1.5),
        reason: 'row text at island + 20 (12 island + 8 row frame), matching the left island');
  });
}
