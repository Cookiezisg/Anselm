import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/workflow_editor_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W5 gate — the graph editor: local structural edits over a working graph, validated edge
// creation, and a diff-based save (:edit → new version).

const _ref = EntityRef(EntityKind.workflow, 'wf_1');
final _t = DateTime.utc(2026, 6, 27);
const _graph =
    '{"nodes":[{"id":"start","kind":"trigger","ref":"tr_x"},{"id":"work","kind":"action","ref":"fn_1"},{"id":"gate","kind":"control","ref":"ctl_q"}],"edges":[{"id":"e1","from":"start","to":"work"},{"id":"e2","from":"work","to":"gate"}]}';

FixtureEntityRepository _repo() => FixtureEntityRepository(
  runDelay: Duration.zero,
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
  workflowVersions: {
    'wf_1': [
      WorkflowVersion(
        id: 'wf_1_v1',
        workflowId: 'wf_1',
        version: 1,
        graph: _graph,
        createdAt: _t,
        updatedAt: _t,
      ),
    ],
  },
);

(ProviderContainer, WorkflowEditorNotifier) _harness(
  FixtureEntityRepository repo,
) {
  final c = ProviderContainer(
    overrides: [entityRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  c.listen(workflowEditorProvider(_ref), (_, _) {});
  return (c, c.read(workflowEditorProvider(_ref).notifier));
}

void main() {
  test(
    'build loads the active-version graph into original == working (not dirty)',
    () async {
      final (c, _) = _harness(_repo());
      final st = await c.read(workflowEditorProvider(_ref).future);
      expect(st.working.nodes.map((n) => n.id), ['start', 'work', 'gate']);
      expect(st.dirty, isFalse);
    },
  );

  test('addNode makes it dirty + selects the new node', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.addNode(NodeKind.action);
    final st = c.read(workflowEditorProvider(_ref)).value!;
    expect(st.dirty, isTrue);
    expect(st.working.nodes, hasLength(4));
    expect(st.selectedNode?.kind, NodeKind.action);
  });

  test('deleteSelected removes a node and cascades its edges', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.selectNode('work');
    ctl.deleteSelected();
    final st = c.read(workflowEditorProvider(_ref)).value!;
    expect(st.working.nodes.any((n) => n.id == 'work'), isFalse);
    expect(
      st.working.edges.any((e) => e.from == 'work' || e.to == 'work'),
      isFalse,
    );
  });

  test(
    'connect validates: self-loop and duplicate rejected; back-edge only from control/approval',
    () async {
      final (c, ctl) = _harness(_repo());
      await c.read(workflowEditorProvider(_ref).future);
      expect(ctl.connect('work', 'work'), 'selfLoop');
      expect(ctl.connect('start', 'work'), 'duplicateEdge'); // e1 exists
      // A back edge gate→work is OK (gate is control); work→start would be a back edge from a
      // non-control action → rejected. gate→work 合法(control);work→start 回边从 action → 拒。
      expect(ctl.connect('gate', 'work'), isNull); // control back edge allowed
      expect(ctl.connect('work', 'start'), 'backEdgeSource');
    },
  );

  test('connect from an approval assigns yes then no', () async {
    final repo = FixtureEntityRepository(
      runDelay: Duration.zero,
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'a',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
            id: 'wf_1_v1',
            workflowId: 'wf_1',
            version: 1,
            graph:
                '{"nodes":[{"id":"gate","kind":"approval","ref":"apf_x"},{"id":"a","kind":"action","ref":"fn_a"},{"id":"b","kind":"action","ref":"fn_b"}],"edges":[]}',
            createdAt: _t,
            updatedAt: _t,
          ),
        ),
      ],
    );
    final (c, ctl) = _harness(repo);
    await c.read(workflowEditorProvider(_ref).future);
    ctl.connect('gate', 'a');
    ctl.connect('gate', 'b');
    final st = c.read(workflowEditorProvider(_ref)).value!;
    final ports = st.working.edges
        .where((e) => e.from == 'gate')
        .map((e) => e.fromPort)
        .toSet();
    expect(ports, {'yes', 'no'});
  });

  // Regression (rework review, MEDIUM): the backend forbids duplicate edge IDs, NOT duplicate
  // endpoints, so an approval's yes AND no may target the SAME node. The old unconditional (from,to)
  // reject wrongly blocked this legal fan-in.
  test(
    'approval fan-in: yes and no may target the SAME node (only exact dup rejected)',
    () async {
      final repo = FixtureEntityRepository(
        runDelay: Duration.zero,
        workflows: [
          WorkflowEntity(
            id: 'wf_1',
            name: 'a',
            createdAt: _t,
            updatedAt: _t,
            activeVersionId: 'wf_1_v1',
            activeVersion: WorkflowVersion(
              id: 'wf_1_v1',
              workflowId: 'wf_1',
              version: 1,
              createdAt: _t,
              updatedAt: _t,
              graph:
                  '{"nodes":[{"id":"gate","kind":"approval","ref":"apf_x"},{"id":"target","kind":"action","ref":"fn_t"}],"edges":[]}',
            ),
          ),
        ],
      );
      final (c, ctl) = _harness(repo);
      await c.read(workflowEditorProvider(_ref).future);
      expect(ctl.connect('gate', 'target'), isNull); // yes → target
      expect(
        ctl.connect('gate', 'target'),
        isNull,
      ); // no → SAME target (different port) — allowed
      final st = c.read(workflowEditorProvider(_ref)).value!;
      final ports = st.working.edges
          .where((e) => e.to == 'target')
          .map((e) => e.fromPort)
          .toSet();
      expect(ports, {'yes', 'no'});
      // A THIRD to the same target has no free port left → approvalPortsFull, not a silent duplicate.
      expect(ctl.connect('gate', 'target'), 'approvalPortsFull');
    },
  );

  test('moveNode materializes all positions then persists the drag', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.moveNode('work', const NodePosition(x: 500, y: 200));
    final st = c.read(workflowEditorProvider(_ref)).value!;
    // Every node now has a pos (materialized), and work is where we dropped it. 全节点已定位。
    expect(st.working.nodes.every((n) => n.pos != null), isTrue);
    expect(
      st.working.nodes.firstWhere((n) => n.id == 'work').pos,
      const NodePosition(x: 500, y: 200),
    );
  });

  // Regression (stage-2 review, MEDIUM): changing a node's kind changes its ref FAMILY, so the ref must
  // reset to the new kind's placeholder — not linger as a cross-family target. 改 kind → ref 重置占位。
  test(
    'setNodeKind resets the ref to the new kind placeholder (no cross-family leftover)',
    () async {
      final (c, ctl) = _harness(_repo());
      await c.read(workflowEditorProvider(_ref).future);
      // 'work' is an action with ref 'fn_1'. 'work' 是 action、ref fn_1。
      ctl.setNodeKind('work', NodeKind.agent);
      final n = c
          .read(workflowEditorProvider(_ref))
          .value!
          .working
          .nodes
          .firstWhere((n) => n.id == 'work');
      expect(n.kind, NodeKind.agent);
      expect(
        n.ref,
        'ag_new',
      ); // reset to the agent placeholder, NOT the stale 'fn_1'
      // A no-op kind set (same kind) leaves the ref untouched. 同 kind 不动 ref。
      ctl.setNodeKind('work', NodeKind.agent);
      expect(
        c
            .read(workflowEditorProvider(_ref))
            .value!
            .working
            .nodes
            .firstWhere((n) => n.id == 'work')
            .ref,
        'ag_new',
      );
    },
  );

  test('autoLayout clears every pos (auto-layout takes over)', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.moveNode('work', const NodePosition(x: 5, y: 5)); // materializes pos
    ctl.autoLayout();
    final st = c.read(workflowEditorProvider(_ref)).value!;
    expect(st.working.nodes.every((n) => n.pos == null), isTrue);
  });

  test(
    'save diffs → :edit → a new version; original becomes the working baseline',
    () async {
      final repo = _repo();
      final (c, ctl) = _harness(repo);
      await c.read(workflowEditorProvider(_ref).future);
      ctl.selectNode('work');
      ctl.setNodeRef('work', 'fn_renamed');
      final ok = await ctl.save();
      expect(ok, isTrue);
      final st = c.read(workflowEditorProvider(_ref)).value!;
      expect(st.dirty, isFalse); // baseline moved
      // The backend has a new version with the renamed ref. 后端新版本带改名。
      final wf = await repo.getWorkflow('wf_1');
      expect(wf.activeVersion!.version, 2);
    },
  );

  // Regression (W5 review, HIGH): an edit made WHILE a save is in flight must not be swallowed. The
  // baseline moves to the SNAPSHOT that was sent, not the live working copy — so the mid-flight edit
  // stays a re-saveable diff instead of being falsely marked "saved" (data loss + stuck-clean editor).
  test(
    'an edit made during save survives as a re-saveable diff (no silent loss)',
    () async {
      final repo = _repo();
      final (c, ctl) = _harness(repo);
      await c.read(workflowEditorProvider(_ref).future);
      ctl.setNodeRef('work', 'fn_first');
      final saving = ctl.save(); // starts; parks on `await editWorkflow`
      ctl.setNodeRef(
        'gate',
        'ctl_midflight',
      ); // edit while the save is in flight
      expect(await saving, isTrue);
      final st = c.read(workflowEditorProvider(_ref)).value!;
      // The mid-flight edit is still present AND still pending (not falsely clean). 在途编辑仍在且仍待存。
      expect(
        st.working.nodes.firstWhere((n) => n.id == 'gate').ref,
        'ctl_midflight',
      );
      expect(st.dirty, isTrue);
      // The server received only the first edit so far. 服务器此刻只收到第一处编辑。
      var wf = await repo.getWorkflow('wf_1');
      expect(wf.activeVersion!.graph.contains('fn_first'), isTrue);
      expect(wf.activeVersion!.graph.contains('ctl_midflight'), isFalse);
      // A second save persists the mid-flight edit — nothing was lost. 二次保存落盘在途编辑,无丢失。
      expect(await ctl.save(), isTrue);
      wf = await repo.getWorkflow('wf_1');
      expect(wf.activeVersion!.graph.contains('ctl_midflight'), isTrue);
    },
  );

  // Regression (W5 review, HIGH): a reopened editor must not regenerate an edge id already saved into
  // the graph (the old per-session counter reset to 'e0_new' and collided → the new edge was silently
  // dropped at diff time). Fresh random `edg_<hex>` ids never collide across sessions.
  test(
    'reopening the editor and connecting again yields a distinct edge id (no collision)',
    () async {
      final repo = _repo();
      final (c, ctl) = _harness(repo);
      await c.read(workflowEditorProvider(_ref).future);
      expect(ctl.connect('gate', 'work'), isNull); // control back-edge, valid
      final firstId = c
          .read(workflowEditorProvider(_ref))
          .value!
          .working
          .edges
          .last
          .id;
      expect(await ctl.save(), isTrue);
      // Reopen: the autoDispose family rebuilds fresh, loading the now-3-edge graph. 重开:全新加载。
      c.invalidate(workflowEditorProvider(_ref));
      final ctl2 = c.read(workflowEditorProvider(_ref).notifier);
      await c.read(workflowEditorProvider(_ref).future);
      expect(ctl2.connect('start', 'gate'), isNull); // forward edge, valid
      final ids = c
          .read(workflowEditorProvider(_ref))
          .value!
          .working
          .edges
          .map((e) => e.id)
          .toList();
      expect(ids.toSet().length, ids.length); // all ids unique 全唯一
      expect(
        ids.where((id) => id == firstId),
        hasLength(1),
      ); // the saved edge appears exactly once
    },
  );

  // Regression (W5 review, MEDIUM): back-edge validation must use the SAME gray-node DFS as the
  // backend, not a lone reachability test on the new edge. Here adding c→a (c is control) closes
  // a→b→c→a, and the backend's DFS (rooted at t, node order t,a,b,c) marks a→b (from an ACTION) as the
  // back edge → the graph is INVALID even though c→a itself leaves a control node. Reject up front.
  test(
    'back-edge validation matches the backend DFS (a cycle can make ANOTHER edge the back edge)',
    () async {
      final repo = FixtureEntityRepository(
        runDelay: Duration.zero,
        workflows: [
          WorkflowEntity(
            id: 'wf_1',
            name: 'x',
            createdAt: _t,
            updatedAt: _t,
            activeVersionId: 'wf_1_v1',
            activeVersion: WorkflowVersion(
              id: 'wf_1_v1',
              workflowId: 'wf_1',
              version: 1,
              createdAt: _t,
              updatedAt: _t,
              graph:
                  '{"nodes":['
                  '{"id":"t","kind":"trigger","ref":"trg_x"},'
                  '{"id":"a","kind":"action","ref":"fn_a"},'
                  '{"id":"b","kind":"action","ref":"fn_b"},'
                  '{"id":"c","kind":"control","ref":"ctl_c"}],'
                  '"edges":['
                  '{"id":"tb","from":"t","to":"b"},'
                  '{"id":"ta","from":"t","to":"a"},'
                  '{"id":"ab","from":"a","to":"b"},'
                  '{"id":"bc","from":"b","to":"c"}]}',
            ),
          ),
        ],
      );
      final (c, ctl) = _harness(repo);
      await c.read(workflowEditorProvider(_ref).future);
      // c→a leaves a control node, but the cycle it closes makes a→b (an action) the back edge → reject.
      // 旧的单边可达性会误判为合法;新的整图 DFS 与后端一致 → 拒。
      expect(ctl.connect('c', 'a'), 'backEdgeSource');
    },
  );

  test('discard resets working to original', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.addNode(NodeKind.agent);
    expect(c.read(workflowEditorProvider(_ref)).value!.dirty, isTrue);
    ctl.discard();
    expect(c.read(workflowEditorProvider(_ref)).value!.dirty, isFalse);
  });
}
