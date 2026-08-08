import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:anselm/features/entities/state/rel_graph_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

EntityRelGraph _graph(String id) => EntityRelGraph(
  nodes: [EntityNode(kind: 'control', id: id, name: id)],
);

void main() {
  test(
    'durable support-kind signal refreshes the workspace relation graph',
    () async {
      final fixture = FixtureEntityRepository(relGraph: _graph('ctl_old'));
      final container = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(container.dispose);
      container.listen(relGraphProvider, (_, _) {});

      expect(
        (await container.read(relGraphProvider.future)).nodes.single.id,
        'ctl_old',
      );

      fixture.replaceRelGraph(_graph('ctl_new'));
      fixture.emitLifecycle(
        const EntitySignal(
          kind: EntityKind.control,
          id: 'ctl_old',
          action: EntityAction.deleted,
          durable: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(
        (await container.read(relGraphProvider.future)).nodes.single.id,
        'ctl_new',
      );
    },
  );

  test(
    'ephemeral relation activity never invalidates the durable snapshot',
    () async {
      final fixture = FixtureEntityRepository(relGraph: _graph('before'));
      final container = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(container.dispose);
      container.listen(relGraphProvider, (_, _) {});
      await container.read(relGraphProvider.future);

      fixture.replaceRelGraph(_graph('after'));
      fixture.emitLifecycle(
        const EntitySignal(
          kind: EntityKind.control,
          id: 'before',
          action: EntityAction.updated,
          durable: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(container.read(relGraphProvider).value!.nodes.single.id, 'before');
    },
  );

  test(
    'notification stream resync refreshes the relation graph immediately',
    () async {
      final fixture = FixtureEntityRepository(relGraph: _graph('before'));
      final container = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(fixture)],
      );
      addTearDown(container.dispose);
      container.listen(relGraphProvider, (_, _) {});
      await container.read(relGraphProvider.future);

      fixture.replaceRelGraph(_graph('after'));
      fixture.emitLifecycleResync();
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(relGraphProvider.future)).nodes.single.id,
        'after',
      );
    },
  );
}
