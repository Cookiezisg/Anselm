import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/ui/run/run_terminal.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/router_harness.dart';

// WRK-055 W3 gate (widget) — a parked workflow run grows the approval gate in the right island;
// Approve fires :decide and the terminal settles honestly (running until the truth says otherwise).

final _t0 = DateTime.utc(2026, 6, 27);

const _approvalGraph =
    '{"nodes":[{"id":"start","kind":"trigger","ref":"tr_hook"},{"id":"gate","kind":"approval","ref":"apf_gate"},{"id":"ship","kind":"action","ref":"fn_ship"}],"edges":[{"id":"e1","from":"start","to":"gate"},{"id":"e2","from":"gate","fromPort":"yes","to":"ship"}]}';

FixtureEntityRepository _fix() => FixtureEntityRepository(
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
            graph: _approvalGraph,
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ),
      ],
    );

void main() {
  final r = t.entities.run;

  testWidgets('parked run shows the approval gate; Approve resumes to ok', (tester) async {
    await tester.pumpWidget(routedHost(
      const Scaffold(body: SizedBox(width: 340, height: 800, child: RunTerminal())),
      initialLocation: selectionLocation(EntityKind.workflow, 'wf_1'),
      repository: _fix(),
    ));
    await tester.pump(const Duration(milliseconds: 50)); // detail loads
    await tester.tap(find.widgetWithText(AnButton, t.entities.detail.verb.trigger));
    await tester.pump(); // trigger returns (202), walk scheduled
    await tester.pump(); // walk parks at the gate
    await tester.pump(const Duration(milliseconds: 400)); // debounced reconcile lands truth
    expect(find.text(r.approvalTitle), findsOneWidget);
    expect(find.text('Approve this step to continue.'), findsOneWidget);
    expect(find.text(r.approve), findsOneWidget);
    expect(find.text(r.reject), findsOneWidget);

    await tester.tap(find.text(r.approve));
    await tester.pump(); // :decide snapshot applies
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(r.approvalTitle), findsNothing); // gate gone 门收
    expect(find.text(t.status.done), findsOneWidget); // ok badge
  });

  testWidgets('while walking, the terminal is honestly running (no premature ok)', (tester) async {
    await tester.pumpWidget(routedHost(
      const Scaffold(body: SizedBox(width: 340, height: 800, child: RunTerminal())),
      initialLocation: selectionLocation(EntityKind.workflow, 'wf_1'),
      repository: _fix(),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(AnButton, t.entities.detail.verb.trigger));
    await tester.pump();
    await tester.pump();
    // Before the reconcile lands, the phase must NOT read ok (the old one-shot bug). 对账未落不许 ok。
    expect(find.text(t.status.done), findsNothing);
  });
}
