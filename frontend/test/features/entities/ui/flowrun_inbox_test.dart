import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/ui/flowrun_inbox.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// P1 · approval's runtime "second face" — the cross-run approval inbox (bell tray). Parked approval nodes
// render as decision cards (rendered prompt + reason note when allowed + approve/reject → :decide).

final _t = DateTime.utc(2026, 7, 4);

FlowrunComposite _parked({bool allowReason = true}) => FlowrunComposite(
      flowrun: Flowrun(id: 'flr_1', workflowId: 'wf_1', status: 'running', updatedAt: _t),
      nodes: [
        FlowrunNode(
          id: 'frn_1',
          flowrunId: 'flr_1',
          nodeId: 'deploy_gate',
          kind: 'approval',
          status: 'parked',
          result: {'rendered': 'Approve production deploy of v4?', 'allowReason': allowReason},
          createdAt: _t,
          updatedAt: _t,
        ),
      ],
    );

FixtureEntityRepository _repo({FlowrunComposite? comp}) =>
    FixtureEntityRepository(flowrunDetail: comp == null ? const {} : {'flr_1': comp});

Widget _host(FixtureEntityRepository repo) => ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(body: SizedBox(width: 340, height: 640, child: const FlowrunInbox())),
        ),
      ),
    );

void main() {
  testWidgets('parked approvals render as decision cards (prompt + reason + approve/reject)',
      (tester) async {
    await tester.pumpWidget(_host(_repo(comp: _parked())));
    await tester.pump(); // provider resolves
    await tester.pump();
    final r = t.entities.run;
    expect(find.text('Approve production deploy of v4?'), findsOneWidget); // rendered prompt
    expect(find.byType(AnInput), findsOneWidget); // reason input (allowReason = true)
    expect(find.text(r.approve), findsOneWidget);
    expect(find.text(r.reject), findsOneWidget);
  });

  testWidgets('no reason input when the form disallows it', (tester) async {
    await tester.pumpWidget(_host(_repo(comp: _parked(allowReason: false))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AnInput), findsNothing);
  });

  testWidgets('deciding sends :decide with the reason', (tester) async {
    final repo = _repo(comp: _parked());
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump();
    final r = t.entities.run;
    await tester.enterText(find.byType(AnInput), 'needs more soak time');
    await tester.tap(find.text(r.reject));
    await tester.pumpAndSettle();
    final node = (await repo.getFlowrun('flr_1')).nodes.firstWhere((n) => n.nodeId == 'deploy_gate');
    expect(node.result['decision'], 'no');
    expect(node.result['reason'], 'needs more soak time');
  });

  testWidgets('empty inbox shows the empty state', (tester) async {
    await tester.pumpWidget(_host(_repo()));
    await tester.pump();
    await tester.pump();
    final r = t.entities.run;
    expect(find.text(r.inboxEmpty), findsOneWidget);
    expect(find.byType(AnState), findsOneWidget);
  });
}
