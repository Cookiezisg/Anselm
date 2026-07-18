import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_card.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/core/ui/icons.dart';
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

// ── sectioned-mode helpers (the bell tray's «Needs you» band) ──

FlowrunComposite _parkedNamed(String flr, String node) => FlowrunComposite(
      flowrun: Flowrun(id: flr, workflowId: 'wf_1', status: 'running', updatedAt: _t),
      nodes: [
        FlowrunNode(
          id: 'frn_$node',
          flowrunId: flr,
          nodeId: node,
          ref: node,
          kind: 'approval',
          status: 'parked',
          result: {'rendered': 'Approve $node?'},
          createdAt: _t,
          updatedAt: _t,
        ),
      ],
    );

Widget _sectionedHost(FixtureEntityRepository repo) => ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: Builder(builder: (context) {
          final navKey = GlobalKey<NavigatorState>();
          return MaterialApp(
            theme: AnTheme.light(),
            navigatorKey: navKey,
            builder: (context, child) => AnOverlayHost(navigatorKey: navKey, child: child!),
            home: const Scaffold(
              body: SizedBox(
                width: 340,
                height: 640,
                child: SingleChildScrollView(child: FlowrunInbox(sectioned: true)),
              ),
            ),
          );
        }),
      ),
    );

void main() {
  testWidgets('parked approvals render as decision cards (prompt + reason + approve/reject)',
      (tester) async {
    await tester.pumpWidget(_host(_repo(comp: _parked())));
    await tester.pump(); // provider resolves
    await tester.pump();
    final r = t.run; // gate copy lives in the core run namespace (S2b 上收) 门文案在 core run 命名空间
    expect(find.text('Approve production deploy of v4?'), findsOneWidget); // rendered prompt
    expect(find.text(t.run.addReason), findsOneWidget); // «+ 理由» pill (allowReason = true, B13 按需长出)
    expect(find.byType(AnInput), findsNothing); // 静息零输入框
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
    final r = t.run;
    await tester.tap(find.text(t.run.addReason));
    await tester.pump();
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

  // ── sectioned mode = the bell tray's collapsible «Needs you» group + per-group ⋯ bulk menu (0719) ──

  testWidgets('sectioned → collapsible «Needs you» head + cards; head collapse hides the cards', (tester) async {
    final repo = FixtureEntityRepository(
        flowrunDetail: {'flr_a': _parkedNamed('flr_a', 'gate_a'), 'flr_b': _parkedNamed('flr_b', 'gate_b')});
    await tester.pumpWidget(_sectionedHost(repo));
    await tester.pump();
    await tester.pump();
    expect(find.text(t.notifications.needsYou), findsOneWidget); // the group head
    expect(find.byType(AnCard), findsNWidgets(2)); // 2 approval cards
    await tester.tap(find.text(t.notifications.needsYou)); // collapse
    await tester.pumpAndSettle();
    expect(find.byType(AnCard), findsNothing);
    expect(find.text(t.notifications.needsYou), findsOneWidget); // head persists
  });

  testWidgets('⋯ bulk «Approve all» confirms (naming every node) then decides them all', (tester) async {
    final repo = FixtureEntityRepository(
        flowrunDetail: {'flr_a': _parkedNamed('flr_a', 'gate_a'), 'flr_b': _parkedNamed('flr_b', 'gate_b')});
    await tester.pumpWidget(_sectionedHost(repo));
    await tester.pump();
    await tester.pump();
    // open the per-group ⋯ bulk menu
    await tester.tap(find.byIcon(AnIcons.more));
    await tester.pumpAndSettle();
    expect(find.text(t.run.approveAll), findsOneWidget);
    expect(find.text(t.run.rejectAll), findsOneWidget);
    await tester.tap(find.text(t.run.approveAll));
    await tester.pumpAndSettle();
    // the confirm dialog names the count + lists every node (never a naked batch)
    expect(find.text(t.run.batchApproveTitle(n: '2')), findsOneWidget);
    expect(find.textContaining('gate_a'), findsWidgets);
    // tap the dialog's confirm button (disambiguated from the cards' Approve via the dialog subtree)
    final dialog = find.ancestor(of: find.text(t.run.batchApproveTitle(n: '2')), matching: find.byType(Material)).first;
    await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(AnButton, t.run.approve)));
    await tester.pumpAndSettle();
    // both parked nodes were decided 'yes'
    final a = (await repo.getFlowrun('flr_a')).nodes.firstWhere((n) => n.nodeId == 'gate_a');
    final b = (await repo.getFlowrun('flr_b')).nodes.firstWhere((n) => n.nodeId == 'gate_b');
    expect(a.result['decision'], 'yes');
    expect(b.result['decision'], 'yes');
  });
}
