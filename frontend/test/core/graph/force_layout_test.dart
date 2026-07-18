import 'dart:math' as math;

import 'package:anselm/core/graph/force_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless physics proofs for the force-directed layout engine (WRK-072 three engineering laws:
/// determinism, static-when-settled, degree→radius). No widget/socket — pure model layer.
void main() {
  double edgeLen(ForceLayout l, String a, String b) =>
      (l.positionOf(a) - l.positionOf(b)).distance;

  group('ForceLayout — convergence', () {
    test('a single spring relaxes toward the ideal length', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b')],
        edges: const [ForceEdge('a', 'b')],
      );
      l.settle();
      // Two nodes, one spring: repulsion pushes apart, spring pulls to rest — converges near idealLength.
      final len = edgeLen(l, 'a', 'b');
      expect((len - l.params.idealLength).abs(), lessThan(l.params.idealLength * 0.5),
          reason: 'settled edge length $len should be within 50% of ${l.params.idealLength}');
    });

    test('settle terminates and leaves the sim settled', () {
      final l = ForceLayout(
        nodes: [for (var i = 0; i < 12; i++) ForceNode('n$i')],
        edges: [for (var i = 1; i < 12; i++) ForceEdge('n0', 'n$i')], // a star
      );
      l.settle();
      expect(l.settled, isTrue);
      expect(l.alpha, lessThan(l.params.alphaMin));
    });

    test('a settled sim tick() is a no-op (static-when-settled → zero repaint)', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c')],
        edges: const [ForceEdge('a', 'b'), ForceEdge('b', 'c')],
      );
      l.settle();
      final before = {for (final id in ['a', 'b', 'c']) id: l.positionOf(id)};
      final moved = l.tick();
      expect(moved, isFalse, reason: 'a settled sim must report no displacement so the Ticker can stop');
      for (final id in ['a', 'b', 'c']) {
        expect(l.positionOf(id), before[id], reason: 'no position changes after settle');
      }
    });
  });

  group('ForceLayout — determinism (law 1)', () {
    test('same nodes+edges settle to identical positions regardless of input order', () {
      final nodesA = [ForceNode('a'), ForceNode('b'), ForceNode('c'), ForceNode('d')];
      final nodesB = [ForceNode('d'), ForceNode('c'), ForceNode('b'), ForceNode('a')]; // reversed
      final edgesA = const [ForceEdge('a', 'b'), ForceEdge('b', 'c'), ForceEdge('c', 'd')];
      final edgesB = const [ForceEdge('c', 'd'), ForceEdge('a', 'b'), ForceEdge('b', 'c')]; // reordered
      final l1 = ForceLayout(nodes: nodesA, edges: edgesA)..settle();
      final l2 = ForceLayout(nodes: nodesB, edges: edgesB)..settle();
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(l1.positionOf(id), l2.positionOf(id),
            reason: 'phyllotaxis-by-sorted-id + stable summation → identical shape (no shuffle)');
      }
    });

    test('two fresh instances of the same graph seed identically', () {
      List<ForceNode> ns() => [for (var i = 0; i < 8; i++) ForceNode('x$i')];
      final edges = [for (var i = 1; i < 8; i++) ForceEdge('x0', 'x$i')];
      final l1 = ForceLayout(nodes: ns(), edges: edges);
      final l2 = ForceLayout(nodes: ns(), edges: edges);
      for (var i = 0; i < 8; i++) {
        expect(l1.positionOf('x$i'), l2.positionOf('x$i'));
      }
    });
  });

  group('ForceLayout — pin / reheat (drag)', () {
    test('a pinned node holds its exact position while neighbors adjust', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c')],
        edges: const [ForceEdge('a', 'b'), ForceEdge('b', 'c')],
      )..settle();
      const held = Offset(200, 200);
      l.pin('b', held);
      expect(l.settled, isFalse, reason: 'pin reheats the sim');
      l.settle();
      expect(l.positionOf('b'), held, reason: 'a pinned node never moves under physics');
    });

    test('reheat wakes a settled sim', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b')],
        edges: const [ForceEdge('a', 'b')],
      )..settle();
      expect(l.settled, isTrue);
      l.reheat();
      expect(l.settled, isFalse);
      expect(l.tick(), isTrue);
    });
  });

  group('ForceLayout — disconnected components (law: bounded)', () {
    test('two disconnected pairs stay bounded near the origin (gravity)', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c'), ForceNode('d')],
        edges: const [ForceEdge('a', 'b'), ForceEdge('c', 'd')], // two islands
      );
      l.settle();
      for (final id in ['a', 'b', 'c', 'd']) {
        final p = l.positionOf(id);
        expect(p.distance, lessThan(2000), reason: 'gravity keeps islands from drifting to infinity');
        expect(p.dx.isFinite && p.dy.isFinite, isTrue);
      }
    });

    test('a single isolated node does not crash and stays finite', () {
      final l = ForceLayout(nodes: [ForceNode('solo')], edges: const []);
      l.settle();
      final p = l.positionOf('solo');
      expect(p.dx.isFinite && p.dy.isFinite, isTrue);
    });

    test('empty graph settles trivially', () {
      final l = ForceLayout(nodes: const [], edges: const []);
      l.settle();
      expect(l.positions, isEmpty);
    });
  });

  group('inDegrees — degree→radius source', () {
    test('counts only incoming edges, ignores self-loops', () {
      final d = inDegrees(const [
        (from: 'hub', to: 'a'),
        (from: 'hub', to: 'b'),
        (from: 'x', to: 'a'),
        (from: 'self', to: 'self'), // ignored
      ]);
      expect(d['a'], 2);
      expect(d['b'], 1);
      expect(d['hub'], isNull, reason: 'a pure source has in-degree 0 (renders smallest/faintest)');
      expect(d['self'], isNull);
    });

    test('phyllotaxis seed positions are all distinct (no overlap)', () {
      final l = ForceLayout(
        nodes: [for (var i = 0; i < 30; i++) ForceNode('n$i')],
        edges: const [],
      );
      final seen = <Offset>{};
      for (var i = 0; i < 30; i++) {
        final p = l.positionOf('n$i');
        expect(seen.contains(p), isFalse, reason: 'phyllotaxis spreads nodes to distinct points');
        seen.add(p);
      }
      expect(math.max(seen.length, 0), 30);
    });
  });
}
