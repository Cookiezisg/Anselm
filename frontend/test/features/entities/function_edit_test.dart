import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_format.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/detail/version_list_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-054 F2 gate — the function write plane: fixture edit/revert semantics, the ops diff summary,
// and the setActive reconcile route.

final _t = DateTime.utc(2026, 6, 26);
const _ref = EntityRef(EntityKind.function, 'fn_1');

FunctionVersion _v(int v, {String? code, List<Field> inputs = const [], List<String> deps = const []}) =>
    FunctionVersion(
        id: 'fn_1_v$v',
        functionId: 'fn_1',
        version: v,
        code: code ?? 'code v$v',
        inputs: inputs,
        dependencies: deps,
        createdAt: _t,
        updatedAt: _t);

FixtureEntityRepository _repo() => FixtureEntityRepository(
      functions: [
        FunctionEntity(
            id: 'fn_1',
            name: 'f',
            activeVersionId: 'fn_1_v2',
            activeVersion: _v(2),
            createdAt: _t,
            updatedAt: _t),
      ],
      functionVersions: {
        'fn_1': [_v(2), _v(1)]
      },
    );

void main() {
  group('fixture write plane', () {
    test('revertVersion moves the active pointer', () async {
      final repo = _repo();
      await repo.revertVersion(EntityKind.function, 'fn_1', 1);
      final e = await repo.getFunction('fn_1');
      expect(e.activeVersionId, 'fn_1_v1');
      expect(e.activeVersion!.version, 1);
    });

    test('patchFunctionMeta updates meta without touching versions', () async {
      final repo = _repo();
      final e = await repo.patchFunctionMeta('fn_1', {'name': 'renamed'});
      expect(e.name, 'renamed');
      expect(e.activeVersionId, 'fn_1_v2');
      expect((await repo.listFunctionVersions('fn_1')).items, hasLength(2));
    });
  });

  group('functionVersionSummary', () {
    test('fields / deps / python deltas become chips; code changes are silent', () {
      final prev = _v(1, inputs: const [Field(name: 'a', type: 'string')], deps: const ['x']);
      final cur = FunctionVersion(
          id: 'fn_1_v2',
          functionId: 'fn_1',
          version: 2,
          code: 'changed',
          inputs: const [Field(name: 'a', type: 'number'), Field(name: 'b', type: 'string')],
          outputs: const [Field(name: 'r', type: 'string')],
          dependencies: const ['y'],
          pythonVersion: '3.13',
          createdAt: _t,
          updatedAt: _t);
      final s = functionVersionSummary(cur, prev);
      expect(s, containsAll(['+ in b', 'in a: string→number', '+ out r', '+ dep y', '− dep x', 'py 3.12→3.13']));
      expect(s.any((x) => x.contains('code')), isFalse);
    });

    test('identical signature → no chips', () {
      expect(functionVersionSummary(_v(2), _v(1)), isEmpty);
    });
  });

  group('setActive reconcile', () {
    test('setActive reverts + re-derives the active flag', () async {
      final repo = _repo();
      final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      c.listen(entityDetailProvider(_ref), (_, _) {});
      await c.read(entityDetailProvider(_ref).future);
      c.listen(versionListProvider(_ref), (_, _) {});
      final st = await c.read(versionListProvider(_ref).future);
      expect(st.versions[0].active, isTrue); // v2

      await c.read(versionListProvider(_ref).notifier).setActive(1);
      await c.read(entityDetailProvider(_ref).future);
      final st2 = await c.read(versionListProvider(_ref).future);
      expect(st2.versions.firstWhere((r) => r.version == 1).active, isTrue);
      expect(st2.versions.firstWhere((r) => r.version == 2).active, isFalse);
    });
  });

}
