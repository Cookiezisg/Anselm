import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/graph/entities_graph_page.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// WRK-072 — the full-page relationship-graph explore state (`/entities/graph`): the kind legend doubles as
// the show/hide filter, the "show provenance" toggle re-admits conversation nodes, the right island shows
// the selected node's card with its relation groups, and Esc returns to the Overview.

Widget _host({String initialLocation = '/entities/graph'}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Center(child: Text('HOME')))),
      GoRoute(path: '/entities/graph', builder: (_, _) => const EntitiesGraphPage()),
      GoRoute(path: '/entities/:kind/:id', builder: (_, _) => const Scaffold(body: Center(child: Text('DETAIL')))),
    ],
  );
  addTearDown(router.dispose);
  return ProviderScope(
    overrides: [
      goRouterProvider.overrideWithValue(router),
      entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
    ],
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

Finder _node(String id) => find.byKey(ValueKey('relNode_$id'));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // relGraph future
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  final g = t.entities.graph;

  testWidgets('a legend chip toggles its kind hidden (legend IS the filter)', (tester) async {
    await tester.pumpWidget(_host());
    await _settle(tester);
    expect(_node('sk_research'), findsOneWidget, reason: 'the skill node is on the graph');
    await tester.tap(find.text(t.ref.skill)); // the legend chip
    await tester.pump();
    expect(_node('sk_research'), findsNothing, reason: 'toggled off by its legend chip');
  });

  testWidgets('show-provenance reveals the conversation nodes', (tester) async {
    await tester.pumpWidget(_host());
    await _settle(tester);
    expect(_node('cv_1'), findsNothing, reason: 'provenance hidden by default');
    await tester.tap(find.text(g.showProvenance));
    await tester.pump();
    await _settle(tester);
    expect(_node('cv_1'), findsOneWidget, reason: 'conversation nodes admitted with provenance on');
  });

  testWidgets('the right-island card shows the selected node + its relation groups', (tester) async {
    await tester.pumpWidget(_host(initialLocation: '/entities/graph?sel=function:fn_normalize'));
    await _settle(tester);
    // fn_normalize (a hub) is referenced by wf_invoice + two agents → the «被引用» group is present.
    // AnGroupLabel uppercases the heading. 分组小标题 uppercase。
    expect(find.text('normalize-input'), findsWidgets, reason: 'card header + node label');
    expect(find.text(g.groupReferencedBy.toUpperCase()), findsOneWidget);
  });

  testWidgets('Esc returns to the Overview', (tester) async {
    await tester.pumpWidget(_host());
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('double-tapping a rail-kind node opens its detail page', (tester) async {
    await tester.pumpWidget(_host());
    await _settle(tester);
    final r = tester.getRect(_node('fn_normalize'));
    final dot = Offset(r.center.dx, r.top + 4);
    await tester.tapAt(dot);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(dot); // second tap within the window → double-tap navigation
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget, reason: 'double-tap → /entities/function/fn_normalize');
  });
}
