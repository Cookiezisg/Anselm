import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/log_list_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 4 gate — the logs tab: function executions carry the ok/failed aggregate + expand; workflow
// flowruns carry no aggregate and lazily fetch the node list on first expand.

final _t = DateTime.utc(2026, 6, 26);

FunctionExecution _exec(String id, String status) =>
    FunctionExecution(id: id, functionId: 'fn_1', status: status, triggeredBy: 'user', createdAt: _t);

ProviderContainer _container(FixtureEntityRepository repo, EntityRef ref) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.listen(logListProvider(ref), (_, _) {});
  return c;
}

void main() {
  const fnRef = EntityRef(EntityKind.function, 'fn_1');
  const wfRef = EntityRef(EntityKind.workflow, 'wf_1');

  test('function logs carry ok/failed aggregate + expand', () async {
    final c = _container(
      FixtureEntityRepository(functionExecutions: {
        'fn_1': [_exec('x1', 'ok'), _exec('x2', 'ok'), _exec('x3', 'ok'), _exec('x4', 'failed')],
      }),
      fnRef,
    );
    final st = await c.read(logListProvider(fnRef).future);
    expect(st.rows, hasLength(4));
    expect(st.hasAggregate, isTrue);
    expect(st.aggregates.okCount, 3);
    expect(st.aggregates.failedCount, 1);
    expect(st.rows.first.detailRows, isNotEmpty);

    await c.read(logListProvider(fnRef).notifier).toggle('x1');
    expect(c.read(logListProvider(fnRef)).value!.openIds, contains('x1'));
  });

  test('workflow logs have no aggregate; first expand lazily fetches the flowrun node list', () async {
    final comp = FlowrunComposite(
      flowrun: Flowrun(id: 'flr_1', workflowId: 'wf_1', status: 'completed', updatedAt: _t),
      nodes: [
        FlowrunNode(id: 'n', flowrunId: 'flr_1', nodeId: 'n1', kind: 'trigger', status: 'completed', createdAt: _t, updatedAt: _t),
      ],
    );
    final c = _container(
      FixtureEntityRepository(
        flowruns: {'wf_1': [Flowrun(id: 'flr_1', workflowId: 'wf_1', status: 'completed', updatedAt: _t)]},
        flowrunDetail: {'flr_1': comp},
      ),
      wfRef,
    );
    final st = await c.read(logListProvider(wfRef).future);
    expect(st.rows.single.id, 'flr_1');
    expect(st.hasAggregate, isFalse); // workflow flowruns have no tally

    await c.read(logListProvider(wfRef).notifier).toggle('flr_1');
    final after = c.read(logListProvider(wfRef)).value!;
    expect(after.openIds, contains('flr_1'));
    expect(after.flowruns['flr_1']?.nodes, hasLength(1)); // lazily loaded
  });
}
