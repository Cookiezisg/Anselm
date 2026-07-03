import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_graph_canvas.dart';
import 'package:anselm/core/ui/an_run_board.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:anselm/features/entities/ui/detail/run_cockpit_tab.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// WRK-055 W4 gate (widget) — the run cockpit: the board (run list + gantt) + the run graph, all
// strong-linked; a node pick reveals the debug; a failed run offers :replay.

final _t = DateTime.utc(2026, 6, 27);
const _ref = EntityRef(EntityKind.workflow, 'wf_1');
const _graph =
    '{"nodes":[{"id":"c0","kind":"trigger","ref":"tr_x"},{"id":"c1","kind":"action","ref":"fn_1"},{"id":"c2","kind":"action","ref":"fn_2"}],"edges":[{"id":"e1","from":"c0","to":"c1"},{"id":"e2","from":"c1","to":"c2"}]}';

FlowrunNode _node(String flr, String node, String status, {String? error, Map<String, Object?> result = const {}}) =>
    FlowrunNode(
        id: 'frn_${flr}_$node',
        flowrunId: flr,
        nodeId: node,
        kind: 'action',
        ref: 'fn_$node',
        status: status,
        error: error,
        result: result,
        createdAt: _t,
        completedAt: _t,
        updatedAt: _t);

Flowrun _run(String id, String status) => Flowrun(
    id: id,
    workflowId: 'wf_1',
    versionId: 'wf_1_v1',
    status: status,
    startedAt: _t,
    completedAt: _t,
    updatedAt: _t);

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
      flowruns: {
        'wf_1': [_run('flr_fail', 'failed')],
      },
      flowrunDetail: {
        'flr_fail': FlowrunComposite(flowrun: _run('flr_fail', 'failed'), nodes: [
          _node('flr_fail', 'c0', 'completed'),
          _node('flr_fail', 'c1', 'failed', error: 'ValueError: boom', result: {'partial': 1}),
        ]),
      },
    );

Widget _host(FixtureEntityRepository repo) => routedHost(
      Scaffold(body: SingleChildScrollView(child: SizedBox(width: 900, child: RunCockpitTab(_ref)))),
      initialLocation: selectionLocation(_ref.kind, _ref.id),
      repository: repo,
    );

void main() {
  final d = t.entities.detail;

  testWidgets('board + run graph render; run list shows the flowrun', (tester) async {
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 80)); // cockpit + detail load
    expect(find.byType(AnRunBoard), findsOneWidget);
    expect(find.byType(AnGraphCanvas), findsOneWidget); // the run graph
    expect(find.text('flr_fail'), findsWidgets); // run row + run-info card
    expect(find.text('c1'), findsWidgets); // gantt lane + graph node
  });

  testWidgets('failed run offers :replay → run flips to completed', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.widgetWithText(AnButton, d.cockpit.replay), findsOneWidget);
    await tester.tap(find.widgetWithText(AnButton, d.cockpit.replay));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect((await repo.getFlowrun('flr_fail')).flowrun.status, 'completed');
  });

  testWidgets('pick a node → the debug card appears with its error', (tester) async {
    await tester.pumpWidget(_host(_repo()));
    await tester.pump(const Duration(milliseconds: 80));
    // Tap the gantt lane for c1 (the failed node). 点甘特 c1 行。
    await tester.tap(find.text('c1').first);
    await tester.pump();
    expect(find.text(d.cockpit.nodeDetail(id: 'c1')), findsOneWidget);
    expect(find.textContaining('ValueError: boom'), findsOneWidget);
  });

  testWidgets('empty history → the board shows its empty state', (tester) async {
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
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text(d.cockpit.noRuns), findsOneWidget);
  });
}
