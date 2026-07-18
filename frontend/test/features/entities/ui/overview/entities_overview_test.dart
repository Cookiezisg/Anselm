import 'package:anselm/core/ui/an_ledger_row.dart';
import 'package:anselm/core/ui/an_relation_graph.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/ui/entity_ocean.dart';
import 'package:anselm/features/entities/ui/entity_rail.dart';
import 'package:anselm/features/entities/ui/overview/entities_overview.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// WRK-072 — the Entities Overview home (`/entities` with nothing selected): five clip tiles + the
// relationship graph + the «最近更新» ledger, and the fixed «总览» rail row.

Widget _ocean() => routedHost(
      const Scaffold(body: SizedBox(width: 900, height: 900, child: EntityOcean())),
      initialLocation: '/',
      repository: demoEntityRepository(),
    );

Widget _rail() => routedHost(
      const Scaffold(body: SizedBox(width: 320, height: 900, child: EntityRail())),
      initialLocation: '/',
      repository: demoEntityRepository(),
    );

void main() {
  final e = t.entities;

  testWidgets('default Overview: five tiles + graph + recent ledger', (tester) async {
    await tester.pumpWidget(_ocean());
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(EntitiesOverviewView), findsOneWidget);
    // Five clip tiles — the four Quadrinity labels + the folded "Parts" accessory tile. 五牌。
    expect(find.text(t.ref.function), findsWidgets);
    expect(find.text(t.ref.handler), findsWidgets);
    expect(find.text(t.ref.agent), findsWidgets);
    expect(find.text(t.ref.workflow), findsWidgets);
    expect(find.text(e.overview.accessory), findsOneWidget);
    // The relationship graph (the star) + the two section heads. 关系图 + 两段头。
    expect(find.byType(AnRelationGraph), findsOneWidget);
    expect(find.text(e.overview.graphHead), findsOneWidget);
    expect(find.text(e.overview.recentHead), findsOneWidget);
    // The recent ledger rows. 最近更新行。
    expect(find.byType(AnLedgerRow), findsWidgets);
  });

  testWidgets('the rail carries the fixed «总览» row (route home entry)', (tester) async {
    await tester.pumpWidget(_rail());
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text(e.overview.title), findsWidgets, reason: 'the pinned Overview rail row');
  });
}
