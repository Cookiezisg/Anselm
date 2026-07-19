import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/graph/flowrun_timeline.dart';
import 'package:anselm/core/ui/an_node_gantt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 W4 — the gantt widget: a track narrower than the min-bar width must not throw (the
// clamp(s4, w) lowerLimit>upperLimit crash), and its rows render bars/stubs/parked boxes.

GanttRow _r(String id, String status, List<GanttSegment> segs, {bool parked = false, int iters = 1}) =>
    GanttRow(nodeId: id, kind: NodeKind.action, ref: 'fn_$id', status: status, segments: segs, parked: parked, iterations: iters);

Widget _host(Widget child, {double width = 600}) => MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: SingleChildScrollView(child: child)))),
    );

void main() {
  final rows = [
    _r('a', 'completed', const [GanttSegment(0, 0.3)]),
    _r('b', 'failed', const [GanttSegment(0.3, 0.4)]),
    _r('c', 'parked', const [GanttSegment(0.7, 0.2)], parked: true),
    _r('d', '', const []), // never ran
  ];

  testWidgets('renders bars, parked box, and the not-run stub', (tester) async {
    await tester.pumpWidget(_host(AnNodeGantt(rows: rows, notRunLabel: 'not run', waitingLabel: 'waiting')));
    await tester.pump();
    expect(find.text('a'), findsOneWidget);
    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('not run'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an ultra-narrow track does not ArgumentError (the clamp guard)', (tester) async {
    // 150px host: lane 132 + gaps → track <4px. Without the minBar guard, clamp(s4, w) throws an
    // ArgumentError (a release-mode crash, not just a debug overflow). 极窄轨:无 minBar 护栏则 clamp 抛
    // ArgumentError(release 崩溃、非仅 debug 溢出)。
    await tester.pumpWidget(_host(AnNodeGantt(rows: rows, notRunLabel: 'x', waitingLabel: 'w'), width: 150));
    await tester.pump();
    // A RenderFlex overflow at this absurd width (never seen in the >=480px ocean) is acceptable;
    // an ArgumentError is the bug. 该荒谬窄度的溢出可接受,ArgumentError 才是 bug。
    var arg = false;
    for (var ex = tester.takeException(); ex != null; ex = tester.takeException()) {
      if (ex is ArgumentError) arg = true;
    }
    expect(arg, isFalse);
  });

  testWidgets('50-node gantt renders without exploding', (tester) async {
    final many = [for (var i = 0; i < 50; i++) _r('n$i', 'completed', [GanttSegment(i / 50, 0.02)])];
    await tester.pumpWidget(_host(AnNodeGantt(rows: many, notRunLabel: 'x', waitingLabel: 'w')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
