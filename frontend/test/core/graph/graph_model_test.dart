import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/graph/graph_model.dart';
import 'package:flutter_test/flutter_test.dart';

Node n(String id, NodeKind k, {NodePosition? pos}) =>
    Node(id: id, kind: k, ref: '${k.name}_$id', pos: pos);
Edge e(String id, String from, String to, {String? port}) =>
    Edge(id: id, from: from, fromPort: port, to: to);

// The demo reference shape: trigger → action → control —fail→ approval —yes→ action,
// plus a control→action retry back edge. 参照图:分支 + 回边。
final Graph branchGraph = Graph(nodes: [
  n('t', NodeKind.trigger),
  n('run', NodeKind.action),
  n('br', NodeKind.control),
  n('gate', NodeKind.approval),
  n('roll', NodeKind.action),
], edges: [
  e('e1', 't', 'run'),
  e('e2', 'run', 'br'),
  e('e3', 'br', 'gate', port: 'fail'),
  e('e4', 'gate', 'roll', port: 'yes'),
  e('back', 'br', 'run', port: 'retry'),
]);

void main() {
  group('backEdgeIds', () {
    test('classifies the loop edge and only it', () {
      expect(backEdgeIds(branchGraph), {'back'});
    });

    test('pure DAG has none; empty graph has none', () {
      final dag = Graph(
        nodes: [n('a', NodeKind.trigger), n('b', NodeKind.action)],
        edges: [e('e1', 'a', 'b')],
      );
      expect(backEdgeIds(dag), isEmpty);
      expect(backEdgeIds(const Graph()), isEmpty);
    });

    test('two independent loops classify one back edge each', () {
      final g = Graph(nodes: [
        n('t', NodeKind.trigger),
        n('a', NodeKind.action),
        n('c1', NodeKind.control),
        n('b', NodeKind.action),
        n('c2', NodeKind.control),
      ], edges: [
        e('e1', 't', 'a'),
        e('e2', 'a', 'c1'),
        e('l1', 'c1', 'a', port: 'again'),
        e('e3', 'c1', 'b', port: 'ok'),
        e('e4', 'b', 'c2'),
        e('l2', 'c2', 'b', port: 'again'),
      ]);
      expect(backEdgeIds(g), {'l1', 'l2'});
    });
  });

  group('layoutGraph auto layout', () {
    test('ranks advance left→right along the forward path (LR)', () {
      final l = layoutGraph(branchGraph);
      double x(String id) => l.nodeRects[id]!.left;
      expect(x('t'), lessThan(x('run')));
      expect(x('run'), lessThan(x('br')));
      expect(x('br'), lessThan(x('gate')));
      expect(x('gate'), lessThan(x('roll')));
      // Layer pitch mirrors the demo constants. 层距与 demo 常量一致。
      expect(x('run') - x('t'), GraphGeometry.nodeW + GraphGeometry.gapX);
    });

    test('TB flips the main axis', () {
      final l = layoutGraph(branchGraph, dir: GraphDirection.tb);
      double y(String id) => l.nodeRects[id]!.top;
      expect(y('t'), lessThan(y('run')));
      expect(y('gate'), lessThan(y('roll')));
    });

    test('back edge does not feed ranks (loop target keeps its early layer)', () {
      final l = layoutGraph(branchGraph);
      expect(l.nodeRects['run']!.left, lessThan(l.nodeRects['br']!.left));
    });

    test('layout is deterministic', () {
      final a = layoutGraph(branchGraph);
      final b = layoutGraph(branchGraph);
      expect(a.nodeRects, b.nodeRects);
    });

    test('empty graph yields padded-only size and no routes', () {
      final l = layoutGraph(const Graph());
      expect(l.routes, isEmpty);
      expect(l.size.width, GraphGeometry.nodeW + GraphGeometry.pad);
    });
  });

  group('layoutGraph pinned positions', () {
    test('all-pos graph uses authored coords normalized to the pad', () {
      final g = Graph(nodes: [
        n('a', NodeKind.trigger, pos: const NodePosition(x: 100, y: 40)),
        n('b', NodeKind.action, pos: const NodePosition(x: 400, y: 200)),
      ], edges: [
        e('e1', 'a', 'b'),
      ]);
      final l = layoutGraph(g);
      expect(l.nodeRects['a']!.topLeft, const Offset(GraphGeometry.pad, GraphGeometry.pad));
      expect(
        l.nodeRects['b']!.topLeft,
        const Offset(GraphGeometry.pad + 300, GraphGeometry.pad + 160),
      );
    });

    test('one node missing pos → whole graph auto-lays (no mixed geometry)', () {
      final g = Graph(nodes: [
        n('a', NodeKind.trigger, pos: const NodePosition(x: 999, y: 999)),
        n('b', NodeKind.action),
      ], edges: [
        e('e1', 'a', 'b'),
      ]);
      final l = layoutGraph(g);
      // Auto layout puts the root at the pad origin, ignoring the authored 999.
      // 自动布局把根放在留白原点、忽略 999。
      expect(l.nodeRects['a']!.left, GraphGeometry.pad);
    });
  });

  group('edge routing', () {
    test('forward routes leave/enter facing sides with stubs', () {
      final l = layoutGraph(branchGraph);
      final r = l.routes.firstWhere((r) => r.edge.id == 'e1');
      final a = l.nodeRects['t']!, b = l.nodeRects['run']!;
      expect(r.isBack, isFalse);
      expect(r.points.first, Offset(a.right, a.center.dy));
      expect(r.points.last, Offset(b.left, b.center.dy));
    });

    test('back edge routes through the below-bounds channel (LR)', () {
      final l = layoutGraph(branchGraph);
      final r = l.routes.firstWhere((r) => r.edge.id == 'back');
      expect(r.isBack, isTrue);
      final maxBottom =
          l.nodeRects.values.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
      // The channel leg sits past every node. 通道段在所有节点之外。
      expect(r.points[1].dy, greaterThan(maxBottom));
      // And the content size reserves it. 内容尺寸为其留位。
      expect(l.size.height, greaterThan(maxBottom + GraphGeometry.pad));
    });

    test('mid point sits on the polyline extent (port pill anchor)', () {
      final l = layoutGraph(branchGraph);
      for (final r in l.routes) {
        final xs = r.points.map((p) => p.dx);
        final ys = r.points.map((p) => p.dy);
        expect(r.mid.dx, inInclusiveRange(xs.reduce((a, b) => a < b ? a : b), xs.reduce((a, b) => a > b ? a : b)));
        expect(r.mid.dy, inInclusiveRange(ys.reduce((a, b) => a < b ? a : b), ys.reduce((a, b) => a > b ? a : b)));
      }
    });

    test('dangling edges are skipped, never crash', () {
      final g = Graph(
        nodes: [n('a', NodeKind.trigger)],
        edges: [e('e1', 'a', 'ghost'), e('e2', 'ghost', 'a')],
      );
      final l = layoutGraph(g);
      expect(l.routes, isEmpty);
    });

    test('median ordering is construction-stable on wide layers (≥34 ties)', () {
      // 34 same-parent siblings tie on the median; Dart's unstable sort (quicksort past 33
      // elements) would permute them without the index tiebreak — the JS reference is stable.
      // 34 个同父兄弟中位数并列;无 tiebreak 时 Dart 不稳定排序(>33 切 quicksort)会置换,JS 参照稳定。
      final g = Graph(nodes: [
        n('r1', NodeKind.trigger),
        n('r2', NodeKind.trigger),
        for (var i = 0; i < 34; i++) n('c$i', NodeKind.action),
        n('d', NodeKind.action),
      ], edges: [
        for (var i = 0; i < 34; i++) e('e$i', 'r1', 'c$i'),
        e('ed', 'r2', 'd'),
      ]);
      final l = layoutGraph(g);
      final tops = [for (var i = 0; i < 34; i++) l.nodeRects['c$i']!.top];
      // Declaration order must survive the 8 passes verbatim. 声明序须原样穿过 8 趟排序。
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]),
            reason: 'c${i - 1} → c$i out of order (unstable sort leak)');
      }
    });

    test('huge fan-out stays finite and collision-free on the main axis', () {
      final g = Graph(nodes: [
        n('t', NodeKind.trigger),
        for (var i = 0; i < 40; i++) n('x$i', NodeKind.action),
      ], edges: [
        for (var i = 0; i < 40; i++) e('e$i', 't', 'x$i'),
      ]);
      final l = layoutGraph(g);
      expect(l.size.width.isFinite && l.size.height.isFinite, isTrue);
      // Siblings must not overlap. 兄弟不重叠。
      final tops = [for (var i = 0; i < 40; i++) l.nodeRects['x$i']!.top]..sort();
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i] - tops[i - 1], greaterThanOrEqualTo(GraphGeometry.nodeH));
      }
    });
  });
}
