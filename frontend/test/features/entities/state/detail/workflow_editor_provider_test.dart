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
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
        ),
      ],
      workflowVersions: {
        'wf_1': [
          WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: _graph, createdAt: _t, updatedAt: _t),
        ],
      },
    );

(ProviderContainer, WorkflowEditorNotifier) _harness(FixtureEntityRepository repo) {
  final c = ProviderContainer(overrides: [entityRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  c.listen(workflowEditorProvider(_ref), (_, _) {});
  return (c, c.read(workflowEditorProvider(_ref).notifier));
}

void main() {
  test('build loads the active-version graph into original == working (not dirty)', () async {
    final (c, _) = _harness(_repo());
    final st = await c.read(workflowEditorProvider(_ref).future);
    expect(st.working.nodes.map((n) => n.id), ['start', 'work', 'gate']);
    expect(st.dirty, isFalse);
  });

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
    expect(st.working.edges.any((e) => e.from == 'work' || e.to == 'work'), isFalse);
  });

  test('connect validates: self-loop and duplicate rejected; back-edge only from control/approval',
      () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    expect(ctl.connect('work', 'work'), 'selfLoop');
    expect(ctl.connect('start', 'work'), 'duplicateEdge'); // e1 exists
    // A back edge gate→work is OK (gate is control); work→start would be a back edge from a
    // non-control action → rejected. gate→work 合法(control);work→start 回边从 action → 拒。
    expect(ctl.connect('gate', 'work'), isNull); // control back edge allowed
    expect(ctl.connect('work', 'start'), 'backEdgeSource');
  });

  test('connect from an approval assigns yes then no', () async {
    final repo = FixtureEntityRepository(runDelay: Duration.zero, workflows: [
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
    ]);
    final (c, ctl) = _harness(repo);
    await c.read(workflowEditorProvider(_ref).future);
    ctl.connect('gate', 'a');
    ctl.connect('gate', 'b');
    final st = c.read(workflowEditorProvider(_ref)).value!;
    final ports = st.working.edges.where((e) => e.from == 'gate').map((e) => e.fromPort).toSet();
    expect(ports, {'yes', 'no'});
  });

  test('moveNode materializes all positions then persists the drag', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.moveNode('work', const NodePosition(x: 500, y: 200));
    final st = c.read(workflowEditorProvider(_ref)).value!;
    // Every node now has a pos (materialized), and work is where we dropped it. 全节点已定位。
    expect(st.working.nodes.every((n) => n.pos != null), isTrue);
    expect(st.working.nodes.firstWhere((n) => n.id == 'work').pos, const NodePosition(x: 500, y: 200));
  });

  test('autoLayout clears every pos (auto-layout takes over)', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.moveNode('work', const NodePosition(x: 5, y: 5)); // materializes pos
    ctl.autoLayout();
    final st = c.read(workflowEditorProvider(_ref)).value!;
    expect(st.working.nodes.every((n) => n.pos == null), isTrue);
  });

  test('save diffs → :edit → a new version; original becomes the working baseline', () async {
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
  });

  test('discard resets working to original', () async {
    final (c, ctl) = _harness(_repo());
    await c.read(workflowEditorProvider(_ref).future);
    ctl.addNode(NodeKind.agent);
    expect(c.read(workflowEditorProvider(_ref)).value!.dirty, isTrue);
    ctl.discard();
    expect(c.read(workflowEditorProvider(_ref)).value!.dirty, isFalse);
  });
}
