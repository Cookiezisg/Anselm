import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/page.dart' as page_contract;
import 'package:anselm/core/contract/entities/trigger.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/detail/observability_list_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// STEP 4/6 gate — the detail provider's resolution + realtime contract: typed fetch per kind (agent also
// pulls mount-health), no auto-retry on error, durable lifecycle → re-fetch, deleted → navigates home
// (route-derived selection clears, STEP 6), ephemeral → no re-fetch (DB-row-is-truth).

final _t = DateTime.utc(2026, 6, 26);
FunctionEntity _fn(String id, String name) =>
    FunctionEntity(id: id, name: name, createdAt: _t, updatedAt: _t);
const _ref = EntityRef(EntityKind.function, 'fn_1');
const _triggerRef = EntityRef(EntityKind.trigger, 'trg_1');

class _SettlingFiringRepo extends FixtureEntityRepository {
  int _reads = 0;
  bool _seeded = false;

  @override
  Future<page_contract.Page<Firing>> listFirings(
    String id, {
    String? status,
    String? cursor,
    int? limit,
  }) async {
    _reads++;
    if (_reads >= 3 && !_seeded) {
      _seeded = true;
      upsertFiring(
        Firing(
          id: 'trf_skipped',
          triggerId: id,
          workflowId: 'wf_x',
          activationId: 'tra_1',
          status: FiringStatus.skipped,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
    }
    return super.listFirings(id, status: status, cursor: cursor, limit: limit);
  }
}

TriggerEntity _trigger({
  bool listening = true,
  bool paused = false,
  bool hasNextFireAt = true,
  DateTime? lastFiredAt,
}) => TriggerEntity(
  id: _triggerRef.id,
  name: 'heartbeat',
  kind: TriggerSource.cron,
  createdAt: _t,
  updatedAt: _t,
  listening: listening,
  paused: paused,
  lastFiredAt: lastFiredAt,
  nextFireAt: hasNextFireAt ? _t : null,
);

ProviderContainer _container(EntityRepository repo) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(
    entityDetailProvider(_ref),
    (_, _) {},
  ); // keep the notifier (and its SSE subs) alive
  return c;
}

class _ThrowRepo extends FixtureEntityRepository {
  @override
  Future<FunctionEntity> getFunction(String id) async =>
      throw Exception('boom');
}

void main() {
  test('resolves the typed entity for the selected ref', () async {
    final c = _container(
      FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]),
    );
    final d = await c.read(entityDetailProvider(_ref).future);
    expect(d.function?.name, 'sum');
    expect(d.ref, _ref);
  });

  test('agent detail also fetches mount-health', () async {
    const ar = EntityRef(EntityKind.agent, 'ag_1');
    final repo = FixtureEntityRepository(
      agents: [
        AgentEntity(
          id: 'ag_1',
          name: 'researcher',
          createdAt: _t,
          updatedAt: _t,
        ),
      ],
      mountHealth: {
        'ag_1': const MountHealthReport(
          mounts: [MountHealth(ref: 'fn_x', healthy: false, error: 'offline')],
          allHealthy: false,
        ),
      },
    );
    final c = ProviderContainer(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(entityDetailProvider(ar), (_, _) {});
    final d = await c.read(entityDetailProvider(ar).future);
    expect(d.agent?.id, 'ag_1');
    expect(d.mountHealth?.allHealthy, isFalse);
  });

  test('error → AsyncError, no auto-retry (stays error)', () async {
    final c = _container(_ThrowRepo());
    await expectLater(
      c.read(entityDetailProvider(_ref).future),
      throwsA(isA<Exception>()),
    );
    await pumpEventQueue();
    expect(c.read(entityDetailProvider(_ref)).hasError, isTrue);
  });

  test('durable edited → re-fetch (picks up the bumped entity)', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'old')]);
    final c = _container(fixture);
    await c.read(entityDetailProvider(_ref).future);
    expect(c.read(entityDetailProvider(_ref)).value?.function?.name, 'old');

    fixture.upsertFunction(_fn('fn_1', 'new')); // server-side edit
    fixture.emitLifecycle(
      const EntitySignal(
        kind: EntityKind.function,
        id: 'fn_1',
        action: EntityAction.edited,
        durable: true,
      ),
    );
    await pumpEventQueue();

    expect(c.read(entityDetailProvider(_ref)).value?.function?.name, 'new');
  });

  // Route-derived selection (STEP 6): "clear" = navigate home. Driven through a real router (the
  // delegate only parses when attached to MaterialApp.router), so this one is a widget test. 经真路由验。
  testWidgets('durable deleted → navigates home (selection clears)', (
    tester,
  ) async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]);
    final router = buildTestRouter(
      initialLocation: '/entities/function/fn_1',
      page: const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entityRepositoryProvider.overrideWithValue(fixture),
          goRouterProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    final c = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    c.listen(
      entityDetailProvider(_ref),
      (_, _) {},
    ); // keep the notifier (+ SSE subs) alive
    await c.read(entityDetailProvider(_ref).future);
    expect(
      c.read(selectedEntityProvider),
      _ref,
    ); // selection derived from the deep link

    fixture.emitLifecycle(
      const EntitySignal(
        kind: EntityKind.function,
        id: 'fn_1',
        action: EntityAction.deleted,
        durable: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(c.read(selectedEntityProvider), isNull);
  });

  test('ephemeral signal → no re-fetch (same value instance)', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]);
    final c = _container(fixture);
    await c.read(entityDetailProvider(_ref).future);
    final before = c.read(entityDetailProvider(_ref)).value;

    fixture.upsertFunction(_fn('fn_1', 'changed'));
    fixture.emitLifecycle(
      const EntitySignal(
        kind: EntityKind.function,
        id: 'fn_1',
        action: EntityAction.edited,
        durable: false,
      ),
    );
    await pumpEventQueue();

    expect(identical(c.read(entityDetailProvider(_ref)).value, before), isTrue);
  });

  test(
    'trigger status panel signal → re-fetches the live detail projection',
    () async {
      final fixture = FixtureEntityRepository(triggerEntities: [_trigger()]);
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(_triggerRef), (_, _) {});

      await c.read(entityDetailProvider(_triggerRef).future);
      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.listening,
        isTrue,
      );
      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.nextFireAt,
        _t,
      );

      fixture.upsertTrigger(
        _trigger(listening: false, paused: true, hasNextFireAt: false),
      );
      final scope = _triggerRef.kind.scope(_triggerRef.id);
      fixture.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: _triggerRef.id,
          frame: const FrameSignal(
            node: StreamNode(type: 'status', content: {'paused': true}),
          ),
        ),
      );
      await pumpEventQueue();

      final trigger = c.read(entityDetailProvider(_triggerRef)).value?.trigger;
      expect(trigger?.paused, isTrue);
      expect(trigger?.listening, isFalse);
      expect(trigger?.nextFireAt, isNull);
    },
  );

  test(
    'workflow lifecycle signal → refreshes derived trigger listening state',
    () async {
      final fixture = FixtureEntityRepository(triggerEntities: [_trigger()]);
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(_triggerRef), (_, _) {});

      await c.read(entityDetailProvider(_triggerRef).future);
      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.listening,
        isTrue,
      );

      fixture.upsertTrigger(_trigger(listening: false, hasNextFireAt: false));
      fixture.emitLifecycle(
        const EntitySignal(
          kind: EntityKind.workflow,
          id: 'wf_1',
          action: EntityAction.updated,
          durable: true,
        ),
      );
      await pumpEventQueue();

      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.listening,
        isFalse,
      );
    },
  );

  test(
    'trigger fire panel signal → refreshes last-fired detail from REST truth',
    () async {
      final fixture = FixtureEntityRepository(triggerEntities: [_trigger()]);
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(_triggerRef), (_, _) {});

      await c.read(entityDetailProvider(_triggerRef).future);
      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.lastFiredAt,
        isNull,
      );

      final firedAt = _t.add(const Duration(minutes: 1));
      fixture.upsertTrigger(_trigger(lastFiredAt: firedAt));
      final scope = _triggerRef.kind.scope(_triggerRef.id);
      fixture.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: _triggerRef.id,
          frame: const FrameSignal(
            node: StreamNode(
              type: 'fire',
              content: {'activationId': 'tra_1', 'fired': true},
            ),
          ),
        ),
      );
      await pumpEventQueue();

      expect(
        c.read(entityDetailProvider(_triggerRef)).value?.trigger?.lastFiredAt,
        firedAt,
      );
    },
  );

  test(
    'trigger fire panel signal → refreshes an empty filtered firing view',
    () async {
      final fixture = FixtureEntityRepository(triggerEntities: [_trigger()]);
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(_triggerRef), (_, _) {});
      final filtered = firingListProvider((
        triggerId: _triggerRef.id,
        status: FiringStatus.pending.name,
      ));
      c.listen(filtered, (_, _) {});

      await c.read(entityDetailProvider(_triggerRef).future);
      await c.read(filtered.future);
      expect(c.read(filtered).value?.rows, isEmpty);

      fixture.upsertFiring(
        Firing(
          id: 'trf_pending',
          triggerId: _triggerRef.id,
          workflowId: 'wf_x',
          activationId: 'tra_1',
          status: FiringStatus.pending,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      final scope = _triggerRef.kind.scope(_triggerRef.id);
      fixture.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: 'sig_fire',
          frame: const FrameSignal(
            node: StreamNode(type: 'fire', content: {'fired': true}),
          ),
        ),
      );
      await pumpEventQueue();

      expect(c.read(filtered).value?.rows, hasLength(1));
      expect(c.read(filtered).value?.rows.single.id, 'trf_pending');
    },
  );

  test(
    'trigger fire panel signal → terminal filter waits for scheduler settling',
    () async {
      final fixture = _SettlingFiringRepo();
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(c.dispose);
      final filtered = firingListProvider((
        triggerId: _triggerRef.id,
        status: FiringStatus.skipped.name,
      ));
      c.listen(filtered, (_, _) {});

      await c.read(filtered.future);
      expect(c.read(filtered).value?.rows, isEmpty);

      final scope = _triggerRef.kind.scope(_triggerRef.id);
      fixture.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: 'sig_fire',
          frame: const FrameSignal(
            node: StreamNode(type: 'fire', content: {'fired': true}),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 650));

      expect(c.read(filtered).value?.rows.map((row) => row.id), [
        'trf_skipped',
      ]);
    },
  );
}
