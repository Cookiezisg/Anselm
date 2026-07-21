import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/detail/version_list_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 4 gate — the versions tab: kind-erased rows newest-first, the active flag against the entity's
// activeVersionId, select() moves the diff target, loadMore appends.

final _t = DateTime.utc(2026, 6, 26);
const _ref = EntityRef(EntityKind.function, 'fn_1');

FunctionVersion _v(int v) => FunctionVersion(
  id: 'fn_1_v$v',
  functionId: 'fn_1',
  version: v,
  code: 'code v$v',
  createdAt: _t,
  updatedAt: _t,
);

Future<ProviderContainer> _ready(FixtureEntityRepository repo) async {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(entityDetailProvider(_ref), (_, _) {});
  // Detail FIRST — the version build reads its activeVersionId; building the version provider before
  // detail resolves would flag nothing active. (Non-autoDispose family persists without a listener.)
  await c.read(entityDetailProvider(_ref).future);
  return c;
}

void main() {
  test(
    'rows map newest-first with the active flag + select moves the target',
    () async {
      final c = await _ready(
        FixtureEntityRepository(
          functions: [
            FunctionEntity(
              id: 'fn_1',
              name: 'f',
              activeVersionId: 'fn_1_v2',
              createdAt: _t,
              updatedAt: _t,
            ),
          ],
          functionVersions: {
            'fn_1': [_v(2), _v(1)],
          },
        ),
      );
      final st = await c.read(versionListProvider(_ref).future);
      expect(st.versions.map((r) => r.version), [2, 1]);
      expect(st.versions[0].active, isTrue); // v2 is the active version
      expect(st.versions[1].active, isFalse);
      expect(st.versions[0].src, 'code v2');
      expect(st.selectedIndex, 0);

      c.read(versionListProvider(_ref).notifier).select(1);
      expect(c.read(versionListProvider(_ref)).value!.selectedIndex, 1);
    },
  );

  test('loadMore appends the next page', () async {
    final c = await _ready(
      FixtureEntityRepository(
        functions: [
          FunctionEntity(id: 'fn_1', name: 'f', createdAt: _t, updatedAt: _t),
        ],
        functionVersions: {
          'fn_1': [for (var i = 25; i >= 1; i--) _v(i)],
        },
      ),
    );
    final p1 = await c.read(versionListProvider(_ref).future);
    expect(p1.versions, hasLength(20)); // _pageSize
    expect(p1.hasMore, isTrue);

    await c.read(versionListProvider(_ref).notifier).loadMore();
    final p2 = c.read(versionListProvider(_ref)).value!;
    expect(p2.versions, hasLength(25));
    expect(p2.hasMore, isFalse);
  });
}
