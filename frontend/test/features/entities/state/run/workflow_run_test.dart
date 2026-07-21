import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/run/run_terminal_state.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W3 gate — the workflow run is reconcile-driven: ticks (self-filtered by flowrunId) upsert
// live rows, the debounced GET lands the truth, the run header decides the phase; a parked approval
// surfaces parkedNode and :decide resumes to terminal.

const _wfRef = EntityRef(EntityKind.workflow, 'wf_1');
final _t0 = DateTime.utc(2026, 6, 27);

const _approvalGraph =
    '{"nodes":[{"id":"start","kind":"trigger","ref":"tr_hook"},{"id":"gate","kind":"approval","ref":"apf_gate"},{"id":"ship","kind":"action","ref":"fn_ship"}],"edges":[{"id":"e1","from":"start","to":"gate"},{"id":"e2","from":"gate","fromPort":"yes","to":"ship"}]}';

FixtureEntityRepository _repo({String? graph}) => FixtureEntityRepository(
  runDelay: Duration.zero,
  workflows: [
    WorkflowEntity(
      id: 'wf_1',
      name: 'gated',
      createdAt: _t0,
      updatedAt: _t0,
      activeVersionId: 'wf_1_v1',
      activeVersion: WorkflowVersion(
        id: 'wf_1_v1',
        workflowId: 'wf_1',
        version: 1,
        graph: graph ?? _approvalGraph,
        createdAt: _t0,
        updatedAt: _t0,
      ),
    ),
  ],
);

const _chainGraph =
    '{"nodes":[{"id":"c0","kind":"trigger","ref":"tr_x"},{"id":"c1","kind":"action","ref":"fn_1"},{"id":"c2","kind":"action","ref":"fn_2"},{"id":"c3","kind":"action","ref":"fn_3"},{"id":"c4","kind":"action","ref":"fn_4"}],"edges":[{"id":"e1","from":"c0","to":"c1"},{"id":"e2","from":"c1","to":"c2"},{"id":"e3","from":"c2","to":"c3"},{"id":"e4","from":"c3","to":"c4"}]}';

/// Forces 2-row pages regardless of the caller's limit — proves the reconcile's page-through path.
/// 无视调用方 limit、强制 2 行/页——证对账翻页路径。
class _TinyPageRepo extends FixtureEntityRepository {
  _TinyPageRepo()
    : super(
        runDelay: Duration.zero,
        workflows: [
          WorkflowEntity(
            id: 'wf_1',
            name: 'chain',
            createdAt: _t0,
            updatedAt: _t0,
            activeVersionId: 'wf_1_v1',
            activeVersion: WorkflowVersion(
              id: 'wf_1_v1',
              workflowId: 'wf_1',
              version: 1,
              graph: _chainGraph,
              createdAt: _t0,
              updatedAt: _t0,
            ),
          ),
        ],
      );

  @override
  Future<FlowrunComposite> getFlowrun(
    String id, {
    String? cursor,
    int? limit,
  }) => super.getFlowrun(id, cursor: cursor, limit: 2);
}

(ProviderContainer, RunTerminalController) _harness(
  FixtureEntityRepository repo,
) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(runTerminalProvider(_wfRef), (_, _) {});
  return (c, c.read(runTerminalProvider(_wfRef).notifier));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'approval graph: run parks (phase stays running, parkedNode surfaces the prompt)',
    () async {
      final (c, ctl) = _harness(_repo());
      await ctl.run();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final st = c.read(runTerminalProvider(_wfRef));
      expect(st.phase, RunPhase.running); // parked = still in flight 停车仍在途
      expect(st.flowrunStatus, 'running');
      final parked = st.parkedNode;
      expect(parked, isNotNull);
      expect(parked!.nodeId, 'gate');
      expect(parked.result['rendered'], isNotEmpty);
    },
  );

  test('decide yes → 202 snapshot applies, run terminal reaches ok', () async {
    final (c, ctl) = _harness(_repo());
    await ctl.run();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await ctl.decide('gate', 'yes');
    await pumpEventQueue();
    final st = c.read(runTerminalProvider(_wfRef));
    expect(st.phase, RunPhase.ok);
    expect(st.parkedNode, isNull);
    expect(
      st.flowNodes.firstWhere((n) => n.nodeId == 'gate').result['decision'],
      'yes',
    );
  });

  test('a lost first-wins race reconciles instead of throwing', () async {
    final (c, ctl) = _harness(_repo());
    await ctl.run();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await ctl.decide('gate', 'yes'); // wins 先到生效
    await ctl.decide(
      'gate',
      'no',
    ); // loses → fixture throws → falls back to reconcile 输了回落对账
    await pumpEventQueue();
    final st = c.read(runTerminalProvider(_wfRef));
    expect(st.phase, RunPhase.ok);
    expect(
      st.flowNodes.firstWhere((n) => n.nodeId == 'gate').result['decision'],
      'yes',
    );
  });

  test(
    'ticks for a DIFFERENT flowrun are dropped (workflow scope interleaves runs)',
    () async {
      final (c, ctl) = _harness(_repo());
      await ctl.run();
      await pumpEventQueue();
      final mine = c.read(runTerminalProvider(_wfRef)).flowrunId!;
      final scope = EntityKind.workflow.scope('wf_1');
      c.read(entityRepositoryProvider); // repo held below anyway
      final repo = c.read(entityRepositoryProvider) as FixtureEntityRepository;
      repo.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: 'sig_other',
          frame: const FrameSignal(
            node: StreamNode(
              type: 'run',
              content: {
                'flowrunId': 'flr_SOMEONE_ELSE',
                'nodeId': 'ghost',
                'iteration': 0,
                'status': 'completed',
              },
            ),
          ),
        ),
      );
      await pumpEventQueue();
      final st = c.read(runTerminalProvider(_wfRef));
      expect(st.flowrunId, mine);
      expect(st.flowNodes.any((n) => n.nodeId == 'ghost'), isFalse); // 混流帧被丢
    },
  );

  test(
    'cancel is immune to late ticks — the phase never resurrects to running',
    () async {
      final (c, ctl) = _harness(_repo());
      await ctl.run();
      await pumpEventQueue();
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      ); // parked 落定
      final mine = c.read(runTerminalProvider(_wfRef)).flowrunId!;
      ctl.cancel();
      expect(c.read(runTerminalProvider(_wfRef)).phase, RunPhase.cancelled);
      final scope = EntityKind.workflow.scope('wf_1');
      final repo = c.read(entityRepositoryProvider) as FixtureEntityRepository;
      repo.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: 'sig_late',
          frame: FrameSignal(
            node: StreamNode(
              type: 'run',
              content: {
                'flowrunId': mine,
                'nodeId': 'ship',
                'iteration': 0,
                'status': 'completed',
              },
            ),
          ),
        ),
      );
      await pumpEventQueue();
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      ); // 若有对账也让它跑完
      expect(
        c.read(runTerminalProvider(_wfRef)).phase,
        RunPhase.cancelled,
      ); // 不复活
    },
  );

  test(
    'first reconcile pages through the FULL node history (newest-first page ≠ whole run)',
    () async {
      final (c, ctl) = _harness(_TinyPageRepo());
      await ctl.run();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final st = c.read(runTerminalProvider(_wfRef));
      expect(st.phase, RunPhase.ok);
      // Every node of the 5-node chain is present even though a page holds only 2 rows —
      // early nodes must NOT degrade to future. 每页仅 2 行,5 节点仍全在——早期节点不得退化 future。
      expect(
        {for (final n in st.flowNodes) n.nodeId},
        {'c0', 'c1', 'c2', 'c3', 'c4'},
      );
    },
  );

  test(
    'tick rows that raced past a reconcile survive the merge until covered',
    () async {
      final (c, ctl) = _harness(_repo());
      await ctl.run();
      await pumpEventQueue();
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      ); // parked reconcile 落定
      final mine = c.read(runTerminalProvider(_wfRef)).flowrunId!;
      final scope = EntityKind.workflow.scope('wf_1');
      final repo = c.read(entityRepositoryProvider) as FixtureEntityRepository;
      // A tick the composite does not know yet (e.g. dropped-then-replayed edge case). 对账未覆盖的 tick。
      repo.emitPanel(
        scope,
        StreamEnvelope(
          seq: 0,
          scope: scope,
          id: 'sig_extra',
          frame: FrameSignal(
            node: StreamNode(
              type: 'run',
              content: {
                'flowrunId': mine,
                'nodeId': 'ship',
                'iteration': 0,
                'status': 'completed',
              },
            ),
          ),
        ),
      );
      await pumpEventQueue();
      var st = c.read(runTerminalProvider(_wfRef));
      expect(
        st.flowNodes.any((n) => n.nodeId == 'ship' && n.id.startsWith('tick_')),
        isTrue,
      );
      // The debounced reconcile does NOT know 'ship' (composite has start+gate only) — the tick row
      // must survive the merge. 对账不识 ship——tick 行须在合并中存活。
      await Future<void>.delayed(const Duration(milliseconds: 400));
      st = c.read(runTerminalProvider(_wfRef));
      expect(st.flowNodes.any((n) => n.nodeId == 'ship'), isTrue);
    },
  );
}
