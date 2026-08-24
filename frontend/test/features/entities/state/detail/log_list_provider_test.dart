import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/sse/frame.dart';
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

FunctionExecution _exec(String id, String status) => FunctionExecution(
  id: id,
  functionId: 'fn_1',
  status: status,
  triggeredBy: 'user',
  createdAt: _t,
);

HandlerCall _call(String id, String status, {String? logs}) => HandlerCall(
  id: id,
  handlerId: 'hd_1',
  method: 'ping',
  status: status,
  triggeredBy: 'user',
  logs: logs,
  createdAt: _t,
);

ProviderContainer _container(FixtureEntityRepository repo, EntityRef ref) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(logListProvider(ref), (_, _) {});
  return c;
}

void main() {
  const fnRef = EntityRef(EntityKind.function, 'fn_1');
  const hdRef = EntityRef(EntityKind.handler, 'hd_1');
  const agRef = EntityRef(EntityKind.agent, 'ag_1');
  const wfRef = EntityRef(EntityKind.workflow, 'wf_1');

  test(
    'function logs carry ok/failed aggregate and lazy-load full logs on expand',
    () async {
      final c = _container(
        FixtureEntityRepository(
          functionExecutions: {
            'fn_1': [
              _exec('x1', 'ok').copyWith(logs: 'printed by function'),
              _exec('x2', 'ok'),
              _exec('x3', 'ok'),
              _exec('x4', 'failed'),
            ],
          },
        ),
        fnRef,
      );
      final st = await c.read(logListProvider(fnRef).future);
      expect(st.rows, hasLength(4));
      expect(st.hasAggregate, isTrue);
      expect(st.aggregates.okCount, 3);
      expect(st.aggregates.failedCount, 1);
      expect(st.rows.first.detailRows, isNotEmpty);
      expect(
        st.rows.first.detailRows.any((r) => r.$2.contains('printed')),
        isFalse,
      );

      await c.read(logListProvider(fnRef).notifier).toggle('x1');
      final after = c.read(logListProvider(fnRef)).value!;
      expect(after.openIds, contains('x1'));
      expect(after.rows.first.detailsLoaded, isTrue);
      expect(
        after.rows.first.detailRows.any((r) => r.$2 == 'printed by function'),
        isTrue,
      );
    },
  );

  test('function logs refresh after a durable empty-run close', () async {
    final executions = <FunctionExecution>[];
    final repo = FixtureEntityRepository(
      functionExecutions: {'fn_1': executions},
    );
    final c = _container(repo, fnRef);

    final initial = await c.read(logListProvider(fnRef).future);
    expect(initial.rows, isEmpty);

    executions.add(_exec('fx_empty', 'ok'));
    final scope = EntityKind.function.scope(fnRef.id);
    repo.emitPanel(
      scope,
      StreamEnvelope(
        seq: 1,
        scope: scope,
        id: 'blk_empty_run',
        frame: const FrameClose(status: 'completed'),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final after = c.read(logListProvider(fnRef)).value!;
    expect(after.rows.single.id, 'fx_empty');
    expect(after.aggregates.totalCount, 1);
    expect(after.aggregates.okCount, 1);
  });

  test('handler logs lazy-load the single call record on expand', () async {
    final c = _container(
      FixtureEntityRepository(
        handlerCalls: {
          'hd_1': [
            _call('hcl_1', 'failed', logs: 'printed by handler'),
            _call('hcl_2', 'ok'),
          ],
        },
      ),
      hdRef,
    );
    final st = await c.read(logListProvider(hdRef).future);
    expect(st.rows, hasLength(2));
    expect(st.rows.first.detailsLoaded, isFalse);
    expect(
      st.rows.first.detailRows.any((r) => r.$2.contains('printed')),
      isFalse,
    );

    await c.read(logListProvider(hdRef).notifier).toggle('hcl_1');
    final after = c.read(logListProvider(hdRef)).value!;
    expect(after.openIds, contains('hcl_1'));
    expect(after.rows.first.detailsLoaded, isTrue);
    expect(
      after.rows.first.detailRows.any((r) => r.$2 == 'printed by handler'),
      isTrue,
    );
  });

  test(
    'durable external close refreshes agent logs and preserves an expanded row',
    () async {
      final old = AgentExecution(
        id: 'agx_old',
        agentId: 'ag_1',
        status: 'ok',
        triggeredBy: 'manual',
        output: 16,
        elapsedMs: 20,
        createdAt: _t,
      );
      final executions = <AgentExecution>[old];
      final repo = FixtureEntityRepository(
        agentExecutions: {'ag_1': executions},
      );
      final c = _container(repo, agRef);
      await c.read(logListProvider(agRef).future);
      await c.read(logListProvider(agRef).notifier).toggle(old.id);

      executions.insert(
        0,
        AgentExecution(
          id: 'agx_new',
          agentId: 'ag_1',
          status: 'ok',
          triggeredBy: 'manual',
          output: 49,
          elapsedMs: 25,
          createdAt: _t.add(const Duration(seconds: 1)),
        ),
      );
      final scope = EntityKind.agent.scope(agRef.id);
      repo.emitPanel(
        scope,
        StreamEnvelope(
          seq: 1,
          scope: scope,
          id: 'blk_external',
          frame: const FrameClose(status: 'completed'),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 180));
      final after = c.read(logListProvider(agRef)).value!;
      expect(after.rows.map((row) => row.id), ['agx_new', 'agx_old']);
      expect(after.aggregates.totalCount, 2);
      expect(after.aggregates.okCount, 2);
      expect(after.openIds, contains(old.id));
    },
  );

  test(
    'agent logs lazy-load the single record and hydrate its durable transcript',
    () async {
      final execution = AgentExecution(
        id: 'agx_detail',
        agentId: 'ag_1',
        versionId: 'agv_1',
        status: 'ok',
        triggeredBy: 'manual',
        input: {'number': 42},
        output: '1764',
        provider: 'anselm',
        modelId: 'anselm-auto',
        elapsedMs: 12,
        startedAt: _t,
        endedAt: _t.add(const Duration(milliseconds: 12)),
        transcript: [
          {
            'id': 'blk_reasoning',
            'type': 'reasoning',
            'content': 'Thinking',
            'status': 'completed',
          },
          {
            'id': 'blk_text',
            'type': 'text',
            'content': '1764',
            'status': 'completed',
          },
        ],
        createdAt: _t,
      );
      final repo = FixtureEntityRepository(
        agentExecutions: {
          'ag_1': [execution],
        },
      );
      final c = _container(repo, agRef);

      final initial = await c.read(logListProvider(agRef).future);
      expect(initial.rows.single.detailsLoaded, isFalse);
      expect(initial.rows.single.transcriptRoots, isEmpty);

      await c.read(logListProvider(agRef).notifier).toggle(execution.id);
      final after = c.read(logListProvider(agRef)).value!;
      final row = after.rows.single;
      expect(after.openIds, contains(execution.id));
      expect(row.detailsLoaded, isTrue);
      expect(row.transcriptBlockCount, 2);
      expect(row.transcriptRoots.map((n) => n.displayText), [
        'Thinking',
        '1764',
      ]);
      expect(row.detailRows.any((r) => r.$2 == '12ms'), isTrue);
    },
  );

  test(
    'workflow logs have no aggregate; first expand lazily fetches the flowrun node list',
    () async {
      final comp = FlowrunComposite(
        flowrun: Flowrun(
          id: 'flr_1',
          workflowId: 'wf_1',
          status: 'completed',
          updatedAt: _t,
        ),
        nodes: [
          FlowrunNode(
            id: 'n',
            flowrunId: 'flr_1',
            nodeId: 'n1',
            kind: 'trigger',
            status: 'completed',
            createdAt: _t,
            updatedAt: _t,
          ),
        ],
      );
      final c = _container(
        FixtureEntityRepository(
          flowruns: {
            'wf_1': [
              Flowrun(
                id: 'flr_1',
                workflowId: 'wf_1',
                status: 'completed',
                updatedAt: _t,
              ),
            ],
          },
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
    },
  );
}
