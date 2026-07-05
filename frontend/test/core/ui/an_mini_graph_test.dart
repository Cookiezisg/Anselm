import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/graph/graph_model.dart';
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

  // ── settle-then-replay growth (B2.4) ──

  test('graphRanks assigns a column index per node (left→right)', () {
    final layout = layoutGraph(_graph);
    final ranks = graphRanks(layout);
    expect(ranks['on_tick'], 0); // trigger = first column
    expect(ranks['fetch'], 1);
    expect(ranks['summarize'], 2);
  });

  test('nodeRevealAt sweeps left→right; ≥1 progress is fully shown', () {
    expect(nodeRevealAt(0, 2, 0.0), 0.0);
    expect(nodeRevealAt(0, 2, 1.0), 1.0);
    // rank 0 lands before rank 2 as progress grows. 越左越先浮现。
    expect(nodeRevealAt(0, 2, 0.4), greaterThan(nodeRevealAt(2, 2, 0.4)));
    expect(nodeRevealAt(2, 2, 0.3), 0.0); // the last rank hasn't started at 0.3
  });

  test('edgeDrawAt trails its source node (a small lead)', () {
    expect(edgeDrawAt(0, 2, 0.0), 0.0);
    expect(edgeDrawAt(0, 2, 1.0), 1.0);
    // An edge from a later rank draws later than one from an earlier rank. 源越靠后越晚画。
    expect(edgeDrawAt(0, 2, 0.5), greaterThanOrEqualTo(edgeDrawAt(1, 2, 0.5)));
  });

  testWidgets('revealProgress 0 makes every node fully transparent (present but hidden)', (tester) async {
    await _pump(tester, AnMiniGraph(graph: _graph, revealProgress: 0.0));
    // The nodes are in the tree (for a stable layout) but at opacity 0. 节点在树里但透明。
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity == 0.0);
    expect(opacities.length, greaterThanOrEqualTo(3));
  });

  testWidgets('AnMiniGraphGrowth settles to the full graph (reduced motion → instant)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AnTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true), // reduced → jump to settled
        child: Scaffold(body: Center(child: SizedBox(width: 520, child: AnMiniGraphGrowth(graph: _graph)))),
      ),
    ));
    await tester.pumpAndSettle(); // must converge (no eternal ticker under reduced) 必须收敛
    // Settled: all three nodes present and opaque (no lingering Opacity<1). 终态:三节点全在、不透。
    expect(find.text('trg_1'), findsOneWidget);
    expect(find.text('ag_3'), findsOneWidget);
    final faded = tester.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity < 1.0);
    expect(faded, isEmpty);
  });
}
