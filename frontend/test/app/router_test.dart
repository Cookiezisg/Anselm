import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/router_harness.dart';

// STEP 6 — the routing seam: `:kind`/`:id` encode + decode, the kind-validation redirect, and selection
// derived ONE-WAY off the router's delegate. The full AppShell-on-router (buildAppRouter) is verified by
// the real-run capture harness (deep-link screenshots); here we cover the deterministic seam logic. The
// test router (router_harness) mirrors buildAppRouter's exact redirect, so the redirect behaviour is real.
//
// STEP 6 路由缝:kind/id 编解码、kind 校验 redirect、选区单向派生自 delegate。整壳挂路由(buildAppRouter)由真跑截图验。

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<ProviderContainer> _mount(WidgetTester tester, String initialLocation) async {
  final router = buildTestRouter(initialLocation: initialLocation, page: const SizedBox.shrink());
  await tester.pumpWidget(ProviderScope(
    overrides: [goRouterProvider.overrideWithValue(router)],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return _containerOf(tester);
}

void main() {
  group('route helpers (pure)', () {
    test('entityKindFromWire round-trips the four kinds, rejects everything else', () {
      expect(entityKindFromWire('function'), EntityKind.function);
      expect(entityKindFromWire('handler'), EntityKind.handler);
      expect(entityKindFromWire('agent'), EntityKind.agent);
      expect(entityKindFromWire('workflow'), EntityKind.workflow);
      expect(entityKindFromWire('Function'), isNull); // URLs are case-sensitive
      expect(entityKindFromWire('trigger'), isNull); // a rail-only kind, not routable in 4.1
      expect(entityKindFromWire('bogus'), isNull);
      expect(entityKindFromWire(''), isNull);
      expect(entityKindFromWire(null), isNull);
    });

    test('entityLocation builds /entities/<kind>/<id>', () {
      expect(entityLocation(EntityKind.function, 'fn_1'), '/entities/function/fn_1');
      expect(entityLocation(EntityKind.agent, 'ag_x'), '/entities/agent/ag_x');
    });
  });

  group('selectedEntityProvider derives from the route', () {
    testWidgets('root → null selection', (tester) async {
      final c = await _mount(tester, '/');
      expect(c.read(selectedEntityProvider), isNull);
    });

    testWidgets('valid deep-link → the EntityRef', (tester) async {
      final c = await _mount(tester, '/entities/agent/ag_7');
      expect(c.read(selectedEntityProvider), const EntityRef(EntityKind.agent, 'ag_7'));
    });

    testWidgets('bad kind → redirected home → null', (tester) async {
      final c = await _mount(tester, '/entities/bogus/x');
      expect(c.read(goRouterProvider).routerDelegate.currentConfiguration.uri.path, '/');
      expect(c.read(selectedEntityProvider), isNull);
    });

    testWidgets('go() updates the selection live (one-way route → provider)', (tester) async {
      final c = await _mount(tester, '/');
      expect(c.read(selectedEntityProvider), isNull);

      c.read(goRouterProvider).go('/entities/workflow/wf_1');
      await tester.pumpAndSettle();
      expect(c.read(selectedEntityProvider), const EntityRef(EntityKind.workflow, 'wf_1'));

      c.read(goRouterProvider).go('/'); // clear by navigating home
      await tester.pumpAndSettle();
      expect(c.read(selectedEntityProvider), isNull);
    });
  });

  testWidgets('constant page key → the shell never remounts across navigation', (tester) async {
    // Mirrors buildAppRouter: both locations resolve to ONE NoTransitionPage with the SAME constant key,
    // so the Navigator reuses the same Element (keepAlive run-terminal + scroll + rail state all survive).
    // 同 buildAppRouter:两 location 共用同一常量 key 的页 → 复用同一 Element、壳永不重挂。
    Page<void> page(BuildContext c, GoRouterState s) =>
        const NoTransitionPage(key: ValueKey('anselm-shell'), child: _Sentinel());
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', pageBuilder: page),
        GoRoute(
          path: '/entities/:kind/:id',
          redirect: (context, state) =>
              entityKindFromWire(state.pathParameters['kind']) == null ? '/' : null,
          pageBuilder: page,
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final before = tester.state<_SentinelState>(find.byType(_Sentinel));
    before.marker = 42; // mark the live State

    router.go('/entities/function/fn_1');
    await tester.pumpAndSettle();
    final after = tester.state<_SentinelState>(find.byType(_Sentinel));

    expect(identical(before, after), isTrue); // same State object → never remounted
    expect(after.marker, 42); // and its state survived the navigation
  });
}

/// A sentinel whose State identity reveals whether the page was remounted. 哨兵:State 身份揭示是否重挂。
class _Sentinel extends StatefulWidget {
  const _Sentinel();
  @override
  State<_Sentinel> createState() => _SentinelState();
}

class _SentinelState extends State<_Sentinel> {
  int marker = 0;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
