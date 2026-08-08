import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/detail/version_list_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 4 gate — the versions tab: kind-erased rows newest-first, the active flag against the entity's
// activeVersionId, the accordion's open sets (WRK-077 VT: the newest version opens with the tab,
// toggleExpanded flips one row, setFullSource implies open), per-row +N/−N counts, loadMore appends.

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
    'rows map newest-first with the active flag + the newest row opens; toggleExpanded flips one row',
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
      // WRK-077 VT: there is no single «selected index» any more — the accordion's open set is the
      // truth, and the NEWEST version opens with the tab (首屏自我解释). 无选中下标,开合集即真相。
      expect(st.expanded, {2});
      expect(st.fullSource, isEmpty);
      // v2 counts against v1 ('code v2' vs 'code v1' = one line replaced). 行计数对下一更旧行算。
      expect((st.versions[0].added, st.versions[0].removed), (1, 1));
      // The oldest LOADED row has no older neighbour → no counts (never a lying «+0 −0»). 末行无计数。
      expect(st.versions[1].added, isNull);
      expect(st.versions[1].removed, isNull);

      final n = c.read(versionListProvider(_ref).notifier);
      n.toggleExpanded(1);
      expect(c.read(versionListProvider(_ref)).value!.expanded, {2, 1});
      n.toggleExpanded(2);
      expect(c.read(versionListProvider(_ref)).value!.expanded, {1});

      // «Show all» on a collapsed row opens it too — a mode set on a closed card would be invisible.
      // 对收起的行「展开全部」会一并展开它(收起的卡上设模式=看不见)。
      n.setFullSource(2, true);
      final st2 = c.read(versionListProvider(_ref)).value!;
      expect(st2.fullSource, {2});
      expect(st2.expanded, {1, 2});
      n.setFullSource(2, false);
      expect(c.read(versionListProvider(_ref)).value!.fullSource, isEmpty);
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

  test(
    'control versions use the typed paged repository and active marker',
    () async {
      const ref = EntityRef(EntityKind.control, 'ctl_1');
      final c = ProviderContainer(
        overrides: [
          entityRepositoryProvider.overrideWithValue(
            FixtureEntityRepository(
              controlLogics: [
                ControlLogic(
                  id: 'ctl_1',
                  name: 'route',
                  activeVersionId: 'ctl_1_v2',
                  createdAt: _t,
                  updatedAt: _t,
                  activeVersion: ControlVersion(
                    id: 'ctl_1_v2',
                    controlId: 'ctl_1',
                    version: 2,
                    branches: const [
                      Branch(port: 'approve', when: 'input.score >= 0.8'),
                      Branch(port: 'review', when: 'true'),
                    ],
                    createdAt: _t,
                    updatedAt: _t,
                  ),
                ),
              ],
              controlVersions: {
                'ctl_1': [
                  ControlVersion(
                    id: 'ctl_1_v2',
                    controlId: 'ctl_1',
                    version: 2,
                    inputs: const [Field(name: 'score', type: 'number')],
                    branches: const [
                      Branch(port: 'approve', when: 'input.score >= 0.8'),
                      Branch(port: 'review', when: 'true'),
                    ],
                    changeReason: 'tighten threshold',
                    createdAt: _t,
                    updatedAt: _t,
                  ),
                  ControlVersion(
                    id: 'ctl_1_v1',
                    controlId: 'ctl_1',
                    version: 1,
                    inputs: const [Field(name: 'score', type: 'number')],
                    branches: const [
                      Branch(port: 'approve', when: 'input.score >= 0.7'),
                      Branch(port: 'review', when: 'true'),
                    ],
                    changeReason: 'initial gate',
                    createdAt: _t,
                    updatedAt: _t,
                  ),
                ],
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(ref), (_, _) {});
      await c.read(entityDetailProvider(ref).future);

      final st = await c.read(versionListProvider(ref).future);
      expect(st.versions.map((row) => row.version), [2, 1]);
      expect(st.versions.first.active, isTrue);
      expect(st.versions.first.changeReason, 'tighten threshold');
      expect(st.versions.first.src, contains('input.score >= 0.8'));
      expect(st.versions.first.src, isNot(contains('ctl_1_v2')));
      expect(st.expanded, {2});
    },
  );
}
