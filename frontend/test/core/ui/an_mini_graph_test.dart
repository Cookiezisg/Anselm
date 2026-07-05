import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_mini_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnMiniGraph — the read-only fit-to-box workflow preview (reuses layoutGraph). Renders one kind-tinted
// chip per node + orthogonal edges, scaled to fill a framed box; empty graph → a placeholder.
// 只读迷你图:每节点一枚 kind 五色 chip + 正交边,fit 进定框;空图→占位。

final _graph = Graph(nodes: const [
  Node(id: 'on_tick', kind: NodeKind.trigger, ref: 'trg_1'),
  Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_2'),
  Node(id: 'summarize', kind: NodeKind.agent, ref: 'ag_3'),
], edges: const [
  Edge(id: 'e1', from: 'on_tick', to: 'fetch'),
  Edge(id: 'e2', from: 'fetch', to: 'summarize'),
]);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: Center(child: SizedBox(width: 520, child: child))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders one chip per node (labelled by ref) + fits the scene into the box', (tester) async {
    await _pump(tester, AnMiniGraph(graph: _graph));
    expect(find.text('trg_1'), findsOneWidget);
    expect(find.text('fn_2'), findsOneWidget);
    expect(find.text('ag_3'), findsOneWidget);
    expect(find.byType(FittedBox), findsOneWidget); // the whole graph is scaled to fit
    expect(find.byType(CustomPaint), findsWidgets); // the edge painter
  });

  testWidgets('an empty graph shows a placeholder, not a scaled scene', (tester) async {
    await _pump(tester, const AnMiniGraph(graph: Graph()));
    expect(find.byType(FittedBox), findsNothing);
    expect(find.text('trg_1'), findsNothing);
  });

  testWidgets('onNodeTap fires with the tapped node id', (tester) async {
    String? tapped;
    await _pump(tester, AnMiniGraph(graph: _graph, onNodeTap: (id) => tapped = id));
    await tester.tap(find.text('fn_2'));
    expect(tapped, 'fetch');
  });

  testWidgets('a node with no ref falls back to its id as the label', (tester) async {
    final g = Graph(nodes: const [Node(id: 'lonely', kind: NodeKind.control, ref: '')]);
    await _pump(tester, AnMiniGraph(graph: g));
    expect(find.text('lonely'), findsOneWidget);
  });

  testWidgets('nodeKindColor covers all 5 kinds + unknown (no crash on widen)', (tester) async {
    // A forward/unknown kind must still render (degrade, never crash). unknown 也渲。
    final g = Graph(nodes: const [Node(id: 'x', kind: NodeKind.unknown, ref: 'mystery')]);
    await _pump(tester, AnMiniGraph(graph: g));
    expect(find.text('mystery'), findsOneWidget);
  });
}
