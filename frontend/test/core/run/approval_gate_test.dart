import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/run/approval_gate.dart';
import 'package:anselm/core/ui/an_info_card.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A-011 — the shared parked-approval decision gate (core/run since WRK-069 S2b — the Scheduler joined
// the entities trio as a consumer). Pins the distinct knobs: framed shell, reason gating, verdict+
// reason forwarding.

final _t = DateTime.utc(2026, 7, 13);

FlowrunNode _node({bool allowReason = true}) => FlowrunNode(
      id: 'frn_1',
      flowrunId: 'flr_1',
      nodeId: 'deploy_gate',
      kind: 'approval',
      status: 'parked',
      result: {'rendered': 'Approve deploy?', 'allowReason': allowReason},
      createdAt: _t,
      updatedAt: _t,
    );

Widget _host(Widget child) => TranslationProvider(
      child: MaterialApp(theme: AnTheme.light(), home: Scaffold(body: child)));

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('framed wraps in AnInfoCard; framed:false renders bare', (tester) async {
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(), onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInfoCard), findsOneWidget);
    expect(find.text('Approve deploy?'), findsOneWidget);

    await tester.pumpWidget(_host(ApprovalGate(parked: _node(), framed: false, onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInfoCard), findsNothing); // bare append 裸接
  });

  testWidgets('reason input shows ONLY with collectReason + an allowReason node', (tester) async {
    // allowReason node but collectReason off (terminal/cockpit path — their decide carries no reason).
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: true), onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInput), findsNothing);

    // collectReason on + allowReason → the input grows (inbox path). 收件箱径长出输入。
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: true), collectReason: true, onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInput), findsOneWidget);

    // collectReason on but node forbids a reason → still no input. 节点不允许则仍无。
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: false), collectReason: true, onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInput), findsNothing);
  });

  testWidgets('Approve forwards the typed reason; Reject forwards the verdict', (tester) async {
    String? gotVerdict;
    String? gotReason;
    await tester.pumpWidget(_host(ApprovalGate(
      parked: _node(allowReason: true),
      collectReason: true,
      onDecide: (v, r) {
        gotVerdict = v;
        gotReason = r;
      },
    )));
    await tester.pump();
    await tester.enterText(find.byType(AnInput), '  budget signed off  ');
    await tester.tap(find.text(Translations.of(tester.element(find.byType(ApprovalGate))).run.approve));
    await tester.pump();
    expect(gotVerdict, 'yes');
    expect(gotReason, 'budget signed off'); // trimmed 去空白
  });

  testWidgets('busy disables both buttons', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(), busy: true, onDecide: (_, _) => fired++)));
    await tester.pump();
    final t = Translations.of(tester.element(find.byType(ApprovalGate)));
    await tester.tap(find.text(t.run.approve), warnIfMissed: false);
    await tester.tap(find.text(t.run.reject), warnIfMissed: false);
    expect(fired, 0);
  });
}
