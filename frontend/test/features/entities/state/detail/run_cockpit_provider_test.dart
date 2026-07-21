import 'dart:async';

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

FlowrunNode _node(String flr, String node, String status, {String? error}) =>
    FlowrunNode(
      id: 'frn_${flr}_$node',
      flowrunId: flr,
      nodeId: node,
      kind: 'action',
      ref: 'fn_$node',
      status: status,
      error: error,
      createdAt: _t,
      completedAt: _t,
      updatedAt: _t,
    );

FixtureEntityRepository _repo() {
  final wf = WorkflowEntity(
    id: 'wf_1',
    name: 'pipe',
    createdAt: _t,
    updatedAt: _t,
    activeVersionId: 'wf_1_v1',
    activeVersion: WorkflowVersion(
      id: 'wf_1_v1',
      workflowId: 'wf_1',
      version: 1,
      graph: _graph,
      createdAt: _t,
      updatedAt: _t,
    ),
  );
  Flowrun run(String id, String status) => Flowrun(
    id: id,
    workflowId: 'wf_1',
    versionId: 'wf_1_v1',
    status: status,
    startedAt: _t,
    completedAt: status == 'completed' || status == 'failed' ? _t : null,
    updatedAt: _t,
  );
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
        ],
      ),
      'flr_done': FlowrunComposite(
        flowrun: run('flr_done', 'completed'),
        nodes: [
          _node('flr_done', 'c0', 'completed'),
          _node('flr_done', 'c1', 'completed'),
          _node('flr_done', 'c2', 'completed'),
        ],
      ),
    },
  );
}

(ProviderContainer, RunCockpitNotifier) _harness(FixtureEntityRepository repo) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(runCockpitProvider(_ref), (_, _) {});
  return (c, c.read(runCockpitProvider(_ref).notifier));
}

WorkflowEntity _wf() => WorkflowEntity(
  id: 'wf_1',
  name: 'pipe',
  lifecycleState: 'active',
  active: true,
  createdAt: _t,
  updatedAt: _t,
  activeVersionId: 'wf_1_v1',
  activeVersion: WorkflowVersion(
    id: 'wf_1_v1',
    workflowId: 'wf_1',
    version: 1,
    graph: _graph,
    createdAt: _t,
    updatedAt: _t,
  ),
);

Flowrun _flr(String id, String status) => Flowrun(
  id: id,
  workflowId: 'wf_1',
  versionId: 'wf_1_v1',
  status: status,
  startedAt: _t,
  completedAt: status == 'completed' || status == 'failed' ? _t : null,
  updatedAt: _t,
);

FlowrunComposite _detail(String id, String status) => FlowrunComposite(
  flowrun: _flr(id, status),
  nodes: [_node(id, 'c0', 'completed')],
);

/// getFlowrun gated on a Completer so a selection can race the post-action refresh. getFlowrun 门控。
class _GatedRepo extends FixtureEntityRepository {
  _GatedRepo()
    : super(
        runDelay: Duration.zero,
        workflows: [_wf()],
        flowruns: {
          'wf_1': [_flr('flr_fail', 'failed'), _flr('flr_done', 'completed')],
        },
        flowrunDetail: {
          'flr_fail': _detail('flr_fail', 'failed'),
          'flr_done': _detail('flr_done', 'completed'),
        },
      );
  bool armed =
      false; // gate only AFTER the initial build (else build hangs) 仅 build 后门控
  Completer<void>? _gate;
  void release() => _gate?.complete();
  @override
  Future<FlowrunComposite> getFlowrun(
    String id, {
    String? cursor,
    int? limit,
  }) async {
    if (armed && id == 'flr_fail') {
      _gate = Completer<void>();
      await _gate!.future;
    }
    return super.getFlowrun(id, cursor: cursor, limit: limit);
  }
}

/// getFlowrun throws while [fail]. getFlowrun 在 fail 时抛。
class _FlakyRepo extends FixtureEntityRepository {
  _FlakyRepo()
    : super(
        runDelay: Duration.zero,
        workflows: [_wf()],
        flowruns: {
          'wf_1': [_flr('flr_fail', 'failed'), _flr('flr_done', 'completed')],
        },
        flowrunDetail: {
          'flr_fail': _detail('flr_fail', 'failed'),
          'flr_done': _detail('flr_done', 'completed'),
        },
      );
  bool fail = false;
  @override
  Future<FlowrunComposite> getFlowrun(
    String id, {
    String? cursor,
    int? limit,
  }) async {
    if (fail) throw StateError('boom');
    return super.getFlowrun(id, cursor: cursor, limit: limit);
  }
}

/// 45 flowruns to exercise loadMore + the kill cursor reset. 45 run 验翻页 + kill 游标重置。
class _ManyRunsRepo extends FixtureEntityRepository {
  _ManyRunsRepo()
    : super(
        runDelay: Duration.zero,
        workflows: [_wf()],
        flowruns: {
          'wf_1': [for (var i = 0; i < 45; i++) _flr('flr_$i', 'completed')],
        },
        flowrunDetail: {
          for (var i = 0; i < 45; i++) 'flr_$i': _detail('flr_$i', 'completed'),
        },
      );
}

void main() {
  test(
    'build: loads the run list, selects the newest, fetches its full composite',
    () async {
      final (c, _) = _harness(_repo());
      final st = await c.read(runCockpitProvider(_ref).future);
      expect(st.runs.map((r) => r.id), ['flr_fail', 'flr_done']);
      expect(st.selectedRunId, 'flr_fail'); // newest-first
      expect(st.selected?.nodes, hasLength(2));
      expect(st.selectedNode, isNull); // no node picked yet
    },
  );

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
            id: 'wf_1_v1',
            workflowId: 'wf_1',
            version: 1,
            graph: _graph,
            createdAt: _t,
            updatedAt: _t,
          ),
        ),
      ],
      flowruns: {
        'wf_1': [
          Flowrun(
            id: 'flr_live',
            workflowId: 'wf_1',
            versionId: 'wf_1_v1',
            status: 'running',
            startedAt: _t,
            updatedAt: _t,
          ),
        ],
      },
      flowrunDetail: {
        'flr_live': FlowrunComposite(
          flowrun: Flowrun(
            id: 'flr_live',
            workflowId: 'wf_1',
            versionId: 'wf_1_v1',
            status: 'running',
            startedAt: _t,
            updatedAt: _t,
          ),
          nodes: [_node('flr_live', 'c0', 'completed')],
        ),
      },
    );
    final (c, ctl) = _harness(repo);
    await c.read(runCockpitProvider(_ref).future);
    await ctl.kill();
    expect((await repo.getWorkflow('wf_1')).lifecycleState, 'inactive');
    final st = c.read(runCockpitProvider(_ref)).value!;
    expect(
      st.selectedRun?.status,
      'cancelled',
    ); // the in-flight run was cancelled
  });

  test(
    'busy is released even when the selection changes mid-refresh (no permanent lock)',
    () async {
      // A gated repo lets a run selection race the post-action refresh. 门控 repo 让选区赛过动作后刷新。
      final repo = _GatedRepo();
      final (c, ctl) = _harness(repo);
      await c.read(runCockpitProvider(_ref).future); // selected = flr_fail
      repo.armed = true; // now gate the post-replay refresh 现在门控刷新
      // Kick a replay: busy=true; its :replay resolves, then _refreshSelected awaits a GATED getFlowrun.
      final replaying = ctl.replaySelected();
      await pumpEventQueue();
      expect(c.read(runCockpitProvider(_ref)).value!.busy, isTrue); // in flight
      // Switch runs mid-refresh → the stale refresh's superseded guard must still release busy.
      await ctl.selectRun('flr_done');
      repo.release(); // let the stale getFlowrun(flr_fail) finally return
      await replaying;
      await pumpEventQueue();
      expect(
        c.read(runCockpitProvider(_ref)).value!.busy,
        isFalse,
      ); // NOT permanently locked 未永久锁死
    },
  );

  test(
    'a failed run fetch is retryable by re-selecting the same run',
    () async {
      final repo = _FlakyRepo();
      final (c, ctl) = _harness(repo);
      await c.read(runCockpitProvider(_ref).future);
      repo.fail = true;
      await ctl.selectRun('flr_done'); // fetch throws
      var st = c.read(runCockpitProvider(_ref)).value!;
      expect(st.selectedRunId, 'flr_done');
      expect(
        st.selected,
        isNull,
      ); // stale composite cleared, not showing flr_fail's nodes
      repo.fail = false;
      await ctl.selectRun('flr_done'); // re-click retries (not early-returned)
      st = c.read(runCockpitProvider(_ref)).value!;
      expect(st.selected?.flowrun.id, 'flr_done'); // now loaded
    },
  );

  test('kill resets the paging cursor (no lost middle after loadMore)', () async {
    final repo = _ManyRunsRepo();
    final (c, ctl) = _harness(repo);
    await c.read(runCockpitProvider(_ref).future);
    await ctl.loadMore();
    expect(c.read(runCockpitProvider(_ref)).value!.runs.length, 40);
    await ctl.kill();
    final st = c.read(runCockpitProvider(_ref)).value!;
    expect(st.runs.length, 20); // reset to first page
    // The cursor was reset too — the next loadMore continues from 20, not 40 (no skipped middle).
    await ctl.loadMore();
    final ids = c
        .read(runCockpitProvider(_ref))
        .value!
        .runs
        .map((r) => r.id)
        .toList();
    expect(ids, containsAll(['flr_20', 'flr_39'])); // the middle survived 中段没丢
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
            id: 'wf_1_v1',
            workflowId: 'wf_1',
            version: 1,
            graph: _graph,
            createdAt: _t,
            updatedAt: _t,
          ),
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
