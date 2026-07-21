import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 1 gate — the fixture is the single seam the whole feature is driven by. Pins: it returns the
// real Page / PageWithAggregate shapes with correct keyset paging, derives rail rows (incl. badges)
// from the same seed the Live path would parse, scripts realtime signals, and swaps in at one provider.

final _t = DateTime.utc(2026, 6, 26);

FunctionEntity _fn(String id, String name) =>
    FunctionEntity(id: id, name: name, createdAt: _t, updatedAt: _t);

FunctionExecution _exec(String id, String status) => FunctionExecution(
  id: id,
  functionId: 'fn_1',
  status: status,
  createdAt: _t,
);

FixtureEntityRepository _repo() => FixtureEntityRepository(
  functions: [_fn('fn_1', 'sum'), _fn('fn_2', 'diff'), _fn('fn_3', 'prod')],
  handlers: [
    HandlerEntity(
      id: 'hd_1',
      name: 'slack',
      createdAt: _t,
      updatedAt: _t,
      configState: 'partially_configured',
      runtimeState: 'running',
      missingConfig: const ['token'],
    ),
  ],
  functionExecutions: {
    'fn_1': [
      _exec('x1', 'ok'),
      _exec('x2', 'ok'),
      _exec('x3', 'ok'),
      _exec('x4', 'failed'),
    ],
  },
);

void main() {
  test('listEntities returns a Page of rows', () async {
    final page = await _repo().listEntities(EntityKind.function);
    expect(page.items.map((r) => r.name), ['sum', 'diff', 'prod']);
    expect(page.isLastPage, isTrue);
  });

  test(
    'keyset paging: limit slices + nextCursor + isLastPage (loadMore path)',
    () async {
      final repo = _repo();
      final p1 = await repo.listEntities(EntityKind.function, limit: 2);
      expect(p1.items.map((r) => r.id), ['fn_1', 'fn_2']);
      expect(p1.hasMore, isTrue);
      expect(p1.nextCursor, '2');

      final p2 = await repo.listEntities(
        EntityKind.function,
        cursor: p1.nextCursor,
        limit: 2,
      );
      expect(p2.items.map((r) => r.id), ['fn_3']);
      expect(p2.isLastPage, isTrue);
    },
  );

  test(
    'rail rows carry kind-specific badges (derived from the seed)',
    () async {
      final page = await _repo().listEntities(EntityKind.handler);
      final row = page.items.single;
      expect(row.kind, EntityKind.handler);
      expect(row.runtimeState, 'running');
      expect(row.configState, 'partially_configured');
      expect(row.missingConfigCount, 1);
    },
  );

  test(
    'listFunctionExecutions returns PageWithAggregate (ok/failed tally)',
    () async {
      final page = await _repo().listFunctionExecutions('fn_1');
      expect(page.items, hasLength(4));
      expect(page.aggregate.okCount, 3);
      expect(page.aggregate.failedCount, 1);
    },
  );

  test('scripted lifecycle signal flows to the kind stream', () async {
    final repo = _repo();
    const signal = EntitySignal(
      kind: EntityKind.function,
      id: 'fn_9',
      action: EntityAction.created,
      durable: true,
    );
    final received = expectLater(
      repo.lifecycleSignals(EntityKind.function),
      emits(signal),
    );
    repo.emitLifecycle(signal);
    await received;
    await repo.dispose();
  });

  test('scripted panel frame flows to the scope stream', () async {
    final repo = _repo();
    final scope = EntityKind.workflow.scope('wf_1');
    final env = StreamEnvelope(
      seq: 0,
      scope: scope,
      id: 'n1',
      frame: const FrameDelta(chunk: 'tick'),
    );
    final received = expectLater(repo.panelSignals(scope), emits(env));
    repo.emitPanel(scope, env);
    await received;
    await repo.dispose();
  });

  test('override 接线: ProviderScope swaps Live → Fixture at one seam', () {
    final fixture = _repo();
    final container = ProviderContainer(
      overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
    );
    addTearDown(container.dispose);
    expect(container.read(entityRepositoryProvider), same(fixture));
    expect(container.read(entityRepositoryProvider), isA<EntityRepository>());
  });
}
