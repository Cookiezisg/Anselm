import 'package:anselm/core/ui/an_sidebar_list.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/ui/entity_ocean.dart';
import 'package:anselm/features/entities/ui/entity_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_batteries.dart';
import '../../support/router_harness.dart';

// STEP 6 hardening — the five-battery matrix (空/超长/海量/极值/注入). The RAIL (list) is driven through all
// five; the OCEAN (detail) through the two that stress a single record's render (超长 + 注入). Universal
// invariant across every battery: NO uncaught exception (incl. a RenderFlex overflow, which the framework
// throws during layout and the test framework captures into takeException). A deliberately NARROW boundary
// (so long strings can't quietly fit) makes overflow real, not a false green.
//
// 五电池矩阵:rail 跑全五电池、ocean 跑压单条记录渲染的两电池(超长+注入)。通用不变式:无未捕获异常(含 RenderFlex
// 溢出,框架 layout 阶段抛、test 框架收进 takeException)。窄边界使长串无法悄悄塞下 → 溢出为真、非假绿。

void main() {
  final railBatteries = ValueVariant<Battery>(Battery.values.toSet());

  testWidgets('rail: every battery renders without overflow / exception', (tester) async {
    final b = railBatteries.currentValue!;
    await tester.pumpWidget(routedHost(
      // 280 logical px — a real left-island width; narrow enough that an unbounded long name overflows.
      const Scaffold(body: SizedBox(width: 280, height: 640, child: EntityRail())),
      repository: batteryRepo(b),
    ));
    await tester.pump(const Duration(milliseconds: 60)); // the 4 list futures resolve

    // The universal invariant — no overflow, no thrown error, for EVERY battery. 通用不变式。
    expect(tester.takeException(), isNull, reason: 'battery $b threw');

    switch (b) {
      case Battery.empty:
        expect(find.byType(AnSidebarList), findsNothing);
        expect(find.text(t.entities.emptyTitle), findsOneWidget);
      case Battery.overflow:
        // The 200-char Text is present as data (ellipsized visually, full string in the widget). 超长行在场。
        expect(find.text(overflowName), findsOneWidget);
        expect(find.byType(AnSidebarList), findsOneWidget);
      case Battery.huge:
        // 5000 seeded → the first page renders the list (lazy); the section is there, nothing choked. 海量首页。
        expect(find.byType(AnSidebarList), findsOneWidget);
        expect(find.text('function-0'), findsOneWidget);
      case Battery.extreme:
        expect(find.text(extremeName), findsOneWidget); // unicode/emoji/RTL/zero-width render
      case Battery.injection:
        // Flutter Text renders the literal — proof it is inert (no interpolation / no XSS). 注入惰性。
        expect(find.text(injectionScript), findsOneWidget);
        expect(find.text(injectionTemplate), findsOneWidget);
        expect(find.text(injectionDollar), findsOneWidget);
    }
  }, variant: railBatteries);

  testWidgets('ocean: an overflow name + description ellipsis, never overflow', (tester) async {
    await tester.pumpWidget(routedHost(
      const Scaffold(body: SizedBox(width: 420, height: 720, child: EntityOcean())),
      initialLocation: selectionLocation(EntityKind.function, 'fn_long'),
      repository: batteryRepo(Battery.overflow),
    ));
    await tester.pump(const Duration(milliseconds: 80)); // detail resolves
    expect(tester.takeException(), isNull);
    expect(find.text(overflowName), findsWidgets); // header title + description both carry the long string
  });

  testWidgets('ocean: injection in name + description renders inert', (tester) async {
    await tester.pumpWidget(routedHost(
      const Scaffold(body: SizedBox(width: 420, height: 720, child: EntityOcean())),
      initialLocation: selectionLocation(EntityKind.function, 'fn_s'),
      repository: batteryRepo(Battery.injection),
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    // The literal `<script>` string appears verbatim (rendered as text, never interpreted) — finding it
    // also proves the detail (not the "select an entity" empty state) actually rendered. 注入逐字 = 详情已渲。
    expect(find.text(injectionScript), findsWidgets);
  });
}
