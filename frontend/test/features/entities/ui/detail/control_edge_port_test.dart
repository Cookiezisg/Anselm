import 'package:anselm/core/contract/entities/control.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/workflow_editor_provider.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/workflow_editor_page.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// P1 · control 端口修复 — the workflow editor's edge inspector: a control-source edge's `fromPort` is a
// DROPDOWN of the referenced control's declared branch ports (via controlPortsProvider), not blind
// free-text. Mirrors approval's yes/no dropdown.

final _t = DateTime.utc(2026, 7, 4);

// trigger → control(gate, ctl_1) → post; the gate→post edge (e2) currently routes on port 'pass'.
const _graph =
    '{"nodes":[{"id":"start","kind":"trigger","ref":"tr_x"},{"id":"gate","kind":"control","ref":"ctl_1"},'
    '{"id":"post","kind":"action","ref":"fn_1"}],'
    '"edges":[{"id":"e1","from":"start","to":"gate"},{"id":"e2","from":"gate","fromPort":"pass","to":"post"}]}';

ControlLogic _ctl() => ControlLogic(
      id: 'ctl_1',
      name: 'quality',
      activeVersionId: 'ctlv_1',
      createdAt: _t,
      updatedAt: _t,
      activeVersion: ControlVersion(
        id: 'ctlv_1',
        controlId: 'ctl_1',
        version: 2,
        branches: const [
          Branch(port: 'pass', when: 'input.score > 0.8'),
          Branch(port: 'retry', when: 'true'),
        ],
        createdAt: _t,
        updatedAt: _t,
      ),
    );

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
      controlLogics: [_ctl()],
    );

Widget _host(FixtureEntityRepository repo) => ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: const WorkflowEditorPage(workflowId: 'wf_1'),
        ),
      ),
    );

const _ref = EntityRef(EntityKind.workflow, 'wf_1');

Future<ProviderContainer> _openEdge(WidgetTester tester, FixtureEntityRepository repo) async {
  tester.view.physicalSize = const Size(1400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(repo));
  await tester.pump(const Duration(milliseconds: 60)); // editor loads
  final container = ProviderScope.containerOf(tester.element(find.byType(WorkflowEditorPage)));
  container.read(workflowEditorProvider(_ref).notifier).selectEdge('e2');
  await tester.pump(); // inspector shows the edge editor
  await tester.pump(); // controlPortsProvider resolves (fixture returns immediately)
  return container;
}

void main() {
  testWidgets('control-source edge port is a dropdown of the control branch ports (not free-text)',
      (tester) async {
    await _openEdge(tester, _repo());
    // A dropdown, NOT a free-text input, carrying the current port.
    expect(find.byType(AnDropdown<String>), findsOneWidget);
    // Open it → the control's declared ports appear.
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.text('pass'), findsWidgets);
    expect(find.text('retry'), findsOneWidget); // only in the menu (current is 'pass')
  });

  testWidgets('picking a branch port patches the edge fromPort in the working graph', (tester) async {
    final container = await _openEdge(tester, _repo());
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    final working = container.read(workflowEditorProvider(_ref)).value!.working;
    expect(working.edges.firstWhere((e) => e.id == 'e2').fromPort, 'retry');
  });

  testWidgets('a stale port the control no longer declares stays selectable', (tester) async {
    // Edge routes on 'legacy', which the control does NOT declare — it must remain the shown value.
    const staleGraph =
        '{"nodes":[{"id":"gate","kind":"control","ref":"ctl_1"},{"id":"post","kind":"action","ref":"fn_1"}],'
        '"edges":[{"id":"e2","from":"gate","fromPort":"legacy","to":"post"}]}';
    final repo = FixtureEntityRepository(
      runDelay: Duration.zero,
      workflows: [
        WorkflowEntity(
          id: 'wf_1',
          name: 'pipe',
          createdAt: _t,
          updatedAt: _t,
          activeVersionId: 'wf_1_v1',
          activeVersion: WorkflowVersion(
              id: 'wf_1_v1', workflowId: 'wf_1', version: 1, graph: staleGraph, createdAt: _t, updatedAt: _t),
        ),
      ],
      controlLogics: [_ctl()],
    );
    await _openEdge(tester, repo);
    await tester.tap(find.byType(AnDropdown<String>));
    await tester.pumpAndSettle();
    // The stale 'legacy' is still an option alongside the real ports.
    expect(find.text('legacy'), findsWidgets);
    expect(find.text('pass'), findsOneWidget);
    expect(find.text('retry'), findsOneWidget);
  });

  testWidgets('selecting a control node shows a read-only branch peek (port / when / default)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 60)); // editor loads
    final container = ProviderScope.containerOf(tester.element(find.byType(WorkflowEditorPage)));
    container.read(workflowEditorProvider(_ref).notifier).selectNode('gate'); // the control node
    await tester.pump();
    await tester.pump(); // controlProvider resolves
    final ed = t.entities.detail.editor;
    expect(find.text(ed.branches), findsOneWidget); // "Routing branches" section
    expect(find.text('pass'), findsWidgets); // a branch port badge
    expect(find.text('input.score > 0.8'), findsOneWidget); // the first branch's when CEL
    expect(find.text(ed.branchDefault), findsOneWidget); // the catch-all (retry, when == "true")
  });
}
