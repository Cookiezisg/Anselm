import 'dart:ui';

import 'package:anselm/core/graph/force_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Headless proofs for the v2 force-directed layout engine (WRK-072 涟漪焦点星图): four forces (adaptive
/// spring / repulsion / collision / weak centering) + connected-component packing + zero-degree isolate band.
/// No widget/socket — pure model layer. 无头证明:四力+分量打包+孤点带,纯模型层。
void main() {
  double edgeLen(ForceLayout l, String a, String b) =>
      (l.positionOf(a) - l.positionOf(b)).distance;

  group('ForceLayout — convergence', () {
    test('a single spring relaxes toward the ideal length', () {
      final l = ForceLayout(
        nodes: [ForceNode('a', radius: 6), ForceNode('b', radius: 6)],
        edges: const [ForceEdge('a', 'b')],
      );
      // Two leaf nodes (deg 1): rest length == idealLength, collision (minSep 12) irrelevant at this scale.
      final len = edgeLen(l, 'a', 'b');
      expect(
        (len - l.params.idealLength).abs(),
        lessThan(l.params.idealLength * 0.5),
        reason:
            'settled edge length $len should be within 50% of ${l.params.idealLength}',
      );
    });

    test(
      'the static layout is computed in the constructor and reports settled',
      () {
        final l = ForceLayout(
          nodes: [for (var i = 0; i < 12; i++) ForceNode('n$i')],
          edges: [
            for (var i = 1; i < 12; i++) ForceEdge('n0', 'n$i'),
          ], // a star
        );
        expect(
          l.settled,
          isTrue,
          reason: 'layout is terminal at construction → Ticker never starts',
        );
        expect(l.alpha, lessThan(l.params.alphaMin));
      },
    );

    test(
      'a settled sim tick() is a no-op (static-when-settled → zero repaint)',
      () {
        final l = ForceLayout(
          nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c')],
          edges: const [ForceEdge('a', 'b'), ForceEdge('b', 'c')],
        );
        final before = {
          for (final id in ['a', 'b', 'c']) id: l.positionOf(id),
        };
        final moved = l.tick();
        expect(
          moved,
          isFalse,
          reason:
              'a settled sim reports no displacement so the Ticker can stop',
        );
        for (final id in ['a', 'b', 'c']) {
          expect(l.positionOf(id), before[id]);
        }
      },
    );
  });

  group('ForceLayout — determinism (law 1)', () {
    test(
      'same nodes+edges settle to identical positions regardless of input order',
      () {
        final edgesA = const [
          ForceEdge('a', 'b'),
          ForceEdge('b', 'c'),
          ForceEdge('c', 'd'),
        ];
        final edgesB = const [
          ForceEdge('c', 'd'),
          ForceEdge('a', 'b'),
          ForceEdge('b', 'c'),
        ]; // reordered
        final l1 = ForceLayout(
          nodes: [
            ForceNode('a'),
            ForceNode('b'),
            ForceNode('c'),
            ForceNode('d'),
          ],
          edges: edgesA,
        );
        final l2 = ForceLayout(
          nodes: [
            ForceNode('d'),
            ForceNode('c'),
            ForceNode('b'),
            ForceNode('a'),
          ],
          edges: edgesB,
        );
        for (final id in ['a', 'b', 'c', 'd']) {
          expect(
            l1.positionOf(id),
            l2.positionOf(id),
            reason:
                'per-component phyllotaxis-by-sorted-id + stable summation → identical shape',
          );
        }
      },
    );

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

  group('ForceLayout — collision (no label/dot overlap)', () {
    test(
      'after settle no two field nodes overlap (dist ≥ radius sum, within relaxation tolerance)',
      () {
        // A dense star of fat nodes forces the collision constraint to do real work. 胖节点密星逼碰撞真干活。
        final l = ForceLayout(
          nodes: [
            ForceNode('hub', radius: 24),
            for (var i = 0; i < 8; i++) ForceNode('leaf$i', radius: 24),
          ],
          edges: [for (var i = 0; i < 8; i++) ForceEdge('hub', 'leaf$i')],
        );
        final ids = ['hub', for (var i = 0; i < 8; i++) 'leaf$i'];
        for (var a = 0; a < ids.length; a++) {
          for (var b = a + 1; b < ids.length; b++) {
            final d = edgeLen(l, ids[a], ids[b]);
            expect(
              d,
              greaterThan(48 * 0.85),
              reason:
                  '${ids[a]}/${ids[b]} distance $d should clear the 48px radius sum',
            );
          }
        }
      },
    );
  });

  group('ForceLayout — pin / reheat (drag)', () {
    test('a pinned node holds its exact position while neighbors adjust', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c')],
        edges: const [ForceEdge('a', 'b'), ForceEdge('b', 'c')],
      );
      const held = Offset(200, 200);
      l.pin('b', held);
      expect(l.settled, isFalse, reason: 'pin reheats the sim');
      l.settle();
      expect(
        l.positionOf('b'),
        held,
        reason: 'a pinned node never moves under physics',
      );
    });

    test('reheat wakes a settled sim', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b')],
        edges: const [ForceEdge('a', 'b')],
      );
      expect(l.settled, isTrue);
      l.reheat();
      expect(l.settled, isFalse);
      expect(l.tick(), isTrue);
    });
  });

  group('ForceLayout — components + isolates', () {
    test('two disconnected pairs stay bounded near the origin', () {
      final l = ForceLayout(
        nodes: [ForceNode('a'), ForceNode('b'), ForceNode('c'), ForceNode('d')],
        edges: const [ForceEdge('a', 'b'), ForceEdge('c', 'd')], // two islands
      );
      for (final id in ['a', 'b', 'c', 'd']) {
        final p = l.positionOf(id);
        expect(
          p.distance,
          lessThan(2000),
          reason: 'packing keeps islands bounded',
        );
        expect(p.dx.isFinite && p.dy.isFinite, isTrue);
      }
    });

    test(
      'a zero-degree isolate sits in a band BELOW the cloud and never enters the field',
      () {
        final l = ForceLayout(
          nodes: [ForceNode('hub'), ForceNode('leaf'), ForceNode('iso')],
          edges: const [ForceEdge('hub', 'leaf')], // iso has no edge → degree 0
        );
        final iso = l.positionOf('iso');
        expect(iso.dx.isFinite && iso.dy.isFinite, isTrue);
        expect(
          iso.dy,
          greaterThan(l.positionOf('hub').dy),
          reason: 'isolate band is below the cloud',
        );
        expect(iso.dy, greaterThan(l.positionOf('leaf').dy));
        // Dragging a field node reheats the sim; the frozen isolate must not budge. 拖场内节点,冻结孤点不动。
        l.pin('hub', const Offset(300, 0));
        l.settle();
        expect(
          l.positionOf('iso'),
          iso,
          reason: 'a frozen isolate is outside the force field',
        );
      },
    );

    test('a single isolated node does not crash and stays finite', () {
      final l = ForceLayout(nodes: [ForceNode('solo')], edges: const []);
      final p = l.positionOf('solo');
      expect(p.dx.isFinite && p.dy.isFinite, isTrue);
    });

    test('empty graph settles trivially', () {
      final l = ForceLayout(nodes: const [], edges: const []);
      expect(l.positions, isEmpty);
      expect(l.settled, isTrue);
    });

    test('all-isolate graph spreads to distinct band positions', () {
      final l = ForceLayout(
        nodes: [for (var i = 0; i < 12; i++) ForceNode('n$i', radius: 6)],
        edges: const [],
      );
      final seen = <Offset>{};
      for (var i = 0; i < 12; i++) {
        final p = l.positionOf('n$i');
        expect(
          seen.contains(p),
          isFalse,
          reason: 'isolates spread to distinct points',
        );
        seen.add(p);
      }
    });
  });

  group('connectedComponents — pure', () {
    test(
      'groups by union-find, deterministic order, singletons for isolates',
      () {
        final comps = connectedComponents(
          const ['a', 'b', 'c', 'd', 'e', 'f'],
          const [ForceEdge('a', 'b'), ForceEdge('b', 'c'), ForceEdge('e', 'd')],
        );
        expect(comps, [
          [
            'a',
            'b',
            'c',
          ], // component ids sorted, components sorted by first id
          ['d', 'e'],
          ['f'], // an isolate is its own singleton
        ]);
      },
    );

    test('self-loops do not connect a node to anything', () {
      final comps = connectedComponents(
        const ['x', 'y'],
        const [ForceEdge('x', 'x')],
      );
      expect(comps, [
        ['x'],
        ['y'],
      ]);
    });
  });

  group('packBoxes — pure', () {
    test('placed boxes never overlap and align to the input order', () {
      const boxes = [Size(120, 80), Size(90, 90), Size(60, 40), Size(200, 50)];
      final origins = packBoxes(boxes, gap: 20);
      expect(origins.length, boxes.length);
      Rect rect(int i) => origins[i] & boxes[i];
      for (var a = 0; a < boxes.length; a++) {
        for (var b = a + 1; b < boxes.length; b++) {
          expect(
            rect(a).overlaps(rect(b)),
            isFalse,
            reason: 'box $a and box $b must not overlap',
          );
        }
      }
    });

    test('empty input → empty output', () {
      expect(packBoxes(const [], gap: 20), isEmpty);
    });
  });

  group('inDegrees — degree→radius source', () {
    test('counts only incoming edges, ignores self-loops', () {
      final d = inDegrees(const [
        (from: 'hub', to: 'a'),
        (from: 'hub', to: 'b'),
        (from: 'x', to: 'a'),
        (from: 'self', to: 'self'),
      ]);
      expect(d['a'], 2);
      expect(d['b'], 1);
      expect(
        d['hub'],
        isNull,
        reason: 'a pure source has in-degree 0 (renders smallest/faintest)',
      );
      expect(d['self'], isNull);
    });
  });
}
