import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/run_cockpit_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W4 gate — the run cockpit provider: pages the flowrun history, keeps ONE run selected (its
// full composite paged through), toggles a node, and drives :replay / :kill / :decide by re-reading
// truth from the backend walk.

const _ref = EntityRef(EntityKind.workflow, 'wf_1');
final _t = DateTime.utc(2026, 6, 27);

const _graph =
    '{"nodes":[{"id":"c0","kind":"trigger","ref":"tr_x"},{"id":"c1","kind":"action","ref":"fn_1"},{"id":"c2","kind":"action","ref":"fn_2"}],"edges":[{"id":"e1","from":"c0","to":"c1"},{"id":"e2","from":"c1","to":"c2"}]}';

FlowrunNode _node(String flr, String node, String status, {String? error}) => FlowrunNode(
    id: 'frn_${flr}_$node',
    flowrunId: flr,
    nodeId: node,
    kind: 'action',
    ref: 'fn_$node',
    status: status,
    error: error,
    createdAt: _t,
    completedAt: _t,
    updatedAt: _t);

FixtureEntityRepository _repo() {
  final wf = WorkflowEntity(
    id: 'wf_1',
    name: 'pipe',
    createdAt: _t,
    updatedAt: _t,
    activeVersionId: 'wf_1_v1',
    activeVersion: WorkflowVersion(
        id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
  );
  Flowrun run(String id, String status) => Flowrun(
      id: id,
      workflowId: 'wf_1',
      versionId: 'wf_1_v1',
      status: status,
      startedAt: _t,
      completedAt: status == 'completed' || status == 'failed' ? _t : null,
      updatedAt: _t);
  return FixtureEntityRepository(
    runDelay: Duration.zero,
    workflows: [wf],
    flowruns: {
      'wf_1': [run('flr_fail', 'failed'), run('flr_done', 'completed')],
    },
    flowrunDetail: {
      'flr_fail': FlowrunComposite(
          flowrun: run('flr_fail', 'failed'),
          nodes: [
            _node('flr_fail', 'c0', 'completed'),
            _node('flr_fail', 'c1', 'failed', error: 'boom'),
          ]),
      'flr_done': FlowrunComposite(
          flowrun: run('flr_done', 'completed'),
          nodes: [
            _node('flr_done', 'c0', 'completed'),
            _node('flr_done', 'c1', 'completed'),
            _node('flr_done', 'c2', 'completed'),
          ]),
    },
  );
}

(ProviderContainer, RunCockpitNotifier) _harness(FixtureEntityRepository repo) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.listen(runCockpitProvider(_ref), (_, _) {});
  return (c, c.read(runCockpitProvider(_ref).notifier));
}

void main() {
  test('build: loads the run list, selects the newest, fetches its full composite', () async {
    final (c, _) = _harness(_repo());
    final st = await c.read(runCockpitProvider(_ref).future);
    expect(st.runs.map((r) => r.id), ['flr_fail', 'flr_done']);
    expect(st.selectedRunId, 'flr_fail'); // newest-first
    expect(st.selected?.nodes, hasLength(2));
    expect(st.selectedNode, isNull); // no node picked yet
  });

  test('selectRun swaps the composite; selectNode toggles', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(runCockpitProvider(_ref).future);
    await ctl.selectRun('flr_done');
    var st = c.read(runCockpitProvider(_ref)).value!;
    expect(st.selectedRunId, 'flr_done');
    expect(st.selected?.nodes, hasLength(3));
    ctl.selectNode('c1');
    st = c.read(runCockpitProvider(_ref)).value!;
    expect(st.selectedNode?.nodeId, 'c1');
    ctl.selectNode('c1'); // toggle off
    expect(c.read(runCockpitProvider(_ref)).value!.selectedNodeId, isNull);
  });

  test(':replay a failed run flips it to completed (re-read truth)', () async {
    final repo = _repo();
    final (c, ctl) = _harness(repo);
    await c.read(runCockpitProvider(_ref).future); // selected = flr_fail
    await ctl.replaySelected();
    final st = c.read(runCockpitProvider(_ref)).value!;
    expect(st.selectedRun?.status, 'completed'); // list header reconciled
    expect(st.selected?.flowrun.replayCount, 1);
    expect(st.selected?.nodes.every((n) => n.status == 'completed'), isTrue);
  });

  test(':kill deactivates the workflow and cancels in-flight runs', () async {
    final repo = FixtureEntityRepository(
      runDelay: Duration.zero,
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'pipe',
          lifecycleState: 'active',
          active: true,
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
        ),
      ],
      flowruns: {
        'wf_1': [
          Flowrun(id: 'flr_live', workflowId: 'wf_1', versionId: 'wf_1_v1', status: 'running', startedAt: _t, updatedAt: _t),
        ],
      },
      flowrunDetail: {
        'flr_live': FlowrunComposite(
            flowrun: Flowrun(id: 'flr_live', workflowId: 'wf_1', versionId: 'wf_1_v1', status: 'running', startedAt: _t, updatedAt: _t),
            nodes: [_node('flr_live', 'c0', 'completed')]),
      },
    );
    final (c, ctl) = _harness(repo);
    await c.read(runCockpitProvider(_ref).future);
    await ctl.kill();
    expect((await repo.getWorkflow('wf_1')).lifecycleState, 'inactive');
    final st = c.read(runCockpitProvider(_ref)).value!;
    expect(st.selectedRun?.status, 'cancelled'); // the in-flight run was cancelled
  });

  test('empty history: no selection, no composite, empty node', () async {
    final repo = FixtureEntityRepository(
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'pipe',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
        ),
      ],
    );
    final (c, _) = _harness(repo);
    final st = await c.read(runCockpitProvider(_ref).future);
    expect(st.runs, isEmpty);
    expect(st.selectedRunId, isNull);
    expect(st.selected, isNull);
  });
}
