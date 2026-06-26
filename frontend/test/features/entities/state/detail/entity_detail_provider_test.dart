import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 4 gate — the detail provider's resolution + realtime contract: typed fetch per kind (agent also
// pulls mount-health), no auto-retry on error, durable lifecycle → re-fetch, deleted → clears selection,
// ephemeral → no re-fetch (DB-row-is-truth).

final _t = DateTime.utc(2026, 6, 26);
FunctionEntity _fn(String id, String name) =>
    FunctionEntity(id: id, name: name, createdAt: _t, updatedAt: _t);
const _ref = EntityRef(EntityKind.function, 'fn_1');

ProviderContainer _container(EntityRepository repo) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.listen(entityDetailProvider(_ref), (_, _) {}); // keep the notifier (and its SSE subs) alive
  return c;
}

class _ThrowRepo extends FixtureEntityRepository {
  @override
  Future<FunctionEntity> getFunction(String id) async => throw Exception('boom');
}

void main() {
  test('resolves the typed entity for the selected ref', () async {
    final c = _container(FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]));
    final d = await c.read(entityDetailProvider(_ref).future);
    expect(d.function?.name, 'sum');
    expect(d.ref, _ref);
  });

  test('agent detail also fetches mount-health', () async {
    const ar = EntityRef(EntityKind.agent, 'ag_1');
    final repo = FixtureEntityRepository(
      agents: [AgentEntity(id: 'ag_1', name: 'researcher', createdAt: _t, updatedAt: _t)],
      mountHealth: {
        'ag_1': const MountHealthReport(
          mounts: [MountHealth(ref: 'fn_x', healthy: false, error: 'offline')],
          allHealthy: false,
        ),
      },
    );
    final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    c.listen(entityDetailProvider(ar), (_, _) {});
    final d = await c.read(entityDetailProvider(ar).future);
    expect(d.agent?.id, 'ag_1');
    expect(d.mountHealth?.allHealthy, isFalse);
  });

  test('error → AsyncError, no auto-retry (stays error)', () async {
    final c = _container(_ThrowRepo());
    await expectLater(c.read(entityDetailProvider(_ref).future), throwsA(isA<Exception>()));
    await pumpEventQueue();
    expect(c.read(entityDetailProvider(_ref)).hasError, isTrue);
  });

  test('durable edited → re-fetch (picks up the bumped entity)', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'old')]);
    final c = _container(fixture);
    await c.read(entityDetailProvider(_ref).future);
    expect(c.read(entityDetailProvider(_ref)).value?.function?.name, 'old');

    fixture.upsertFunction(_fn('fn_1', 'new')); // server-side edit
    fixture.emitLifecycle(const EntitySignal(
        kind: EntityKind.function, id: 'fn_1', action: EntityAction.edited, durable: true));
    await pumpEventQueue();

    expect(c.read(entityDetailProvider(_ref)).value?.function?.name, 'new');
  });

  test('durable deleted → clears the selection', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]);
    final c = _container(fixture);
    c.read(selectedEntityProvider.notifier).select(_ref);
    await c.read(entityDetailProvider(_ref).future);

    fixture.emitLifecycle(const EntitySignal(
        kind: EntityKind.function, id: 'fn_1', action: EntityAction.deleted, durable: true));
    await pumpEventQueue();

    expect(c.read(selectedEntityProvider), isNull);
  });

  test('ephemeral signal → no re-fetch (same value instance)', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'sum')]);
    final c = _container(fixture);
    await c.read(entityDetailProvider(_ref).future);
    final before = c.read(entityDetailProvider(_ref)).value;

    fixture.upsertFunction(_fn('fn_1', 'changed'));
    fixture.emitLifecycle(const EntitySignal(
        kind: EntityKind.function, id: 'fn_1', action: EntityAction.edited, durable: false));
    await pumpEventQueue();

    expect(identical(c.read(entityDetailProvider(_ref)).value, before), isTrue);
  });
}
