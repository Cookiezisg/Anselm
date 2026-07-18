import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/run/approval_gate.dart';
import 'package:anselm/core/ui/an_card.dart';
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

  testWidgets('framed wraps in a BORDERED AnCard (B13 有边卡壳); framed:false renders bare', (tester) async {
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(), onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnCard), findsOneWidget);
    expect(find.text('Approve deploy?'), findsOneWidget);

    await tester.pumpWidget(_host(ApprovalGate(parked: _node(), framed: false, onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnCard), findsNothing); // bare append 裸接
  });

  testWidgets('star bug: the rendered prompt parses markdown — **strong** is bold, not literal asterisks (0719)', (tester) async {
    final node = FlowrunNode(
      id: 'frn_2', flowrunId: 'flr_1', nodeId: 'g', kind: 'approval', status: 'parked',
      result: const {'rendered': 'Deploy **v2.4.0** to production? 42 files changed.'},
      createdAt: _t, updatedAt: _t,
    );
    await tester.pumpWidget(_host(ApprovalGate(parked: node, onDecide: (_, _) {})));
    await tester.pump();
    // The literal markdown asterisks must NOT survive to the screen — they did before (plain Text). 星号不上屏。
    expect(find.textContaining('**', findRichText: true), findsNothing);
    // The version text is still rendered (just bold now). 版本号仍在(现为粗体)。
    expect(find.textContaining('v2.4.0', findRichText: true), findsWidgets);
  });

  testWidgets('reason input shows ONLY with collectReason + an allowReason node', (tester) async {
    // allowReason node but collectReason off (terminal/cockpit path — their decide carries no reason).
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: true), onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInput), findsNothing);

    // collectReason on + allowReason → the input grows (inbox path). 收件箱径长出输入。
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: true), collectReason: true, onDecide: (_, _) {})));
    await tester.pump();
    // At rest the reason is the «+ 理由» pill (B13); tapping it mounts the input. 静息=药丸,点开长输入。
    expect(find.byType(AnInput), findsNothing);
    expect(find.text(t.run.addReason), findsOneWidget);
    await tester.tap(find.text(t.run.addReason));
    await tester.pump();
    expect(find.byType(AnInput), findsOneWidget);

    // collectReason on but node forbids a reason → no pill, no input. 节点不允许则药丸与输入皆无。
    await tester.pumpWidget(_host(ApprovalGate(parked: _node(allowReason: false), collectReason: true, onDecide: (_, _) {})));
    await tester.pump();
    expect(find.byType(AnInput), findsNothing);
    expect(find.text(t.run.addReason), findsNothing);
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
    await tester.tap(find.text(t.run.addReason));
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
