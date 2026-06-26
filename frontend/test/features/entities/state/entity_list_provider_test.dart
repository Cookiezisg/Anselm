import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:anselm/features/entities/state/entity_list_provider.dart';
import 'package:anselm/features/entities/state/rail_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 2 gate — the list state + reconcile, driven entirely through the fixture seam. Pins: first page
// + loadMore stay hasValue (loadingMore lives inside data); durable created/deleted/edited patch the
// list in place; an ephemeral (seq=0) signal never touches the list (DB-row-is-truth).

final _t = DateTime.utc(2026, 6, 26);
FunctionEntity _fn(String id, String name) =>
    FunctionEntity(id: id, name: name, createdAt: _t, updatedAt: _t);

ProviderContainer _container(FixtureEntityRepository fixture) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(fixture)]);
  addTearDown(c.dispose);
  // Keep the family notifier mounted so its SSE subscription stays live for the test.
  c.listen(entityListProvider(EntityKind.function), (_, _) {});
  return c;
}

List<String> _ids(ProviderContainer c) =>
    c.read(entityListProvider(EntityKind.function)).value!.rows.map((r) => r.id).toList();

EntitySignal _sig(EntityAction action, String id, {bool durable = true}) =>
    EntitySignal(kind: EntityKind.function, id: id, action: action, durable: durable);

void main() {
  test('first page loads → hasValue with seeded rows', () async {
    final c = _container(FixtureEntityRepository(functions: [_fn('fn_1', 'a'), _fn('fn_2', 'b')]));
    await c.read(entityListProvider(EntityKind.function).future);
    final v = c.read(entityListProvider(EntityKind.function));
    expect(v.hasValue, isTrue);
    expect(v.value!.rows.map((r) => r.id), ['fn_1', 'fn_2']);
    expect(v.value!.hasMore, isFalse);
  });

  test('loadMore appends the next keyset page, staying hasValue throughout', () async {
    final seed = List.generate(25, (i) => _fn('fn_${i.toString().padLeft(2, '0')}', 'f$i'));
    final c = _container(FixtureEntityRepository(functions: seed));
    final notifier = c.read(entityListProvider(EntityKind.function).notifier);
    await c.read(entityListProvider(EntityKind.function).future);

    final p1 = c.read(entityListProvider(EntityKind.function)).value!;
    expect(p1.rows, hasLength(20)); // _pageSize
    expect(p1.hasMore, isTrue);

    await notifier.loadMore();
    final p2 = c.read(entityListProvider(EntityKind.function));
    expect(p2.hasValue, isTrue);
    expect(p2.value!.rows, hasLength(25));
    expect(p2.value!.hasMore, isFalse);
    expect(p2.value!.loadingMore, isFalse);
  });

  test('durable created → fetch new row + prepend', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'a'), _fn('fn_2', 'b')]);
    final c = _container(fixture);
    await c.read(entityListProvider(EntityKind.function).future);

    fixture.upsertFunction(_fn('fn_9', 'new')); // server-side create, now fetchable
    fixture.emitLifecycle(_sig(EntityAction.created, 'fn_9'));
    await pumpEventQueue();

    expect(_ids(c), ['fn_9', 'fn_1', 'fn_2']);
  });

  test('durable deleted → drop by id', () async {
    final fixture = FixtureEntityRepository(
        functions: [_fn('fn_1', 'a'), _fn('fn_2', 'b'), _fn('fn_3', 'c')]);
    final c = _container(fixture);
    await c.read(entityListProvider(EntityKind.function).future);

    fixture.emitLifecycle(_sig(EntityAction.deleted, 'fn_2'));
    await pumpEventQueue();

    expect(_ids(c), ['fn_1', 'fn_3']);
  });

  test('durable edited → refetch that row + replace in place (length + order preserved)', () async {
    final fixture = FixtureEntityRepository(
        functions: [_fn('fn_1', 'a'), _fn('fn_2', 'OLD'), _fn('fn_3', 'c')]);
    final c = _container(fixture);
    await c.read(entityListProvider(EntityKind.function).future);

    fixture.upsertFunction(_fn('fn_2', 'NEW')); // same id, changed name
    fixture.emitLifecycle(_sig(EntityAction.edited, 'fn_2'));
    await pumpEventQueue();

    final rows = c.read(entityListProvider(EntityKind.function)).value!.rows;
    expect(rows.map((r) => r.id), ['fn_1', 'fn_2', 'fn_3']); // order preserved
    expect(rows[1].name, 'NEW'); // replaced in place
  });

  test('ephemeral signal (seq=0 / durable false) never touches the list', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'a'), _fn('fn_2', 'b')]);
    final c = _container(fixture);
    await c.read(entityListProvider(EntityKind.function).future);

    fixture.upsertFunction(_fn('fn_9', 'new'));
    fixture.emitLifecycle(_sig(EntityAction.created, 'fn_9', durable: false));
    fixture.emitLifecycle(_sig(EntityAction.deleted, 'fn_1', durable: false));
    await pumpEventQueue();

    expect(_ids(c), ['fn_1', 'fn_2']); // unchanged
  });

  test('edited for an id NOT on the loaded pages is ignored', () async {
    final fixture = FixtureEntityRepository(functions: [_fn('fn_1', 'a')]);
    final c = _container(fixture);
    await c.read(entityListProvider(EntityKind.function).future);

    fixture.upsertFunction(_fn('fn_off', 'x'));
    fixture.emitLifecycle(_sig(EntityAction.edited, 'fn_off'));
    await pumpEventQueue();

    expect(_ids(c), ['fn_1']);
  });

  test('railModelProvider fans the 4 kinds into ordered groups with counts', () async {
    final c = _container(FixtureEntityRepository(functions: [_fn('fn_1', 'a'), _fn('fn_2', 'b')]));
    // mount every group
    for (final k in EntityKind.values) {
      c.listen(entityListProvider(k), (_, _) {});
    }
    await c.read(entityListProvider(EntityKind.function).future);

    final rail = c.read(railModelProvider);
    expect(rail.map((g) => g.kind), EntityKind.values);
    expect(rail.firstWhere((g) => g.kind == EntityKind.function).count, 2);
    expect(rail.firstWhere((g) => g.kind == EntityKind.agent).count, 0);
  });
}
