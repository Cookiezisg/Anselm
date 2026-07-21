import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/graph/graph_edit_ops.dart';
import 'package:flutter_test/flutter_test.dart';

Node n(
  String id,
  NodeKind k, {
  String? ref,
  Map<String, String> input = const {},
  NodePosition? pos,
}) =>
    Node(id: id, kind: k, ref: ref ?? '${k.name}_$id', input: input, pos: pos);
Edge e(String id, String from, String to, {String? port}) =>
    Edge(id: id, from: from, fromPort: port, to: to);

final base = Graph(
  nodes: [
    n('t', NodeKind.trigger),
    n('work', NodeKind.action),
    n('gate', NodeKind.control),
  ],
  edges: [e('e1', 't', 'work'), e('e2', 'work', 'gate')],
);

void main() {
  group('workflowEditOps (diff)', () {
    test('no changes → no ops', () {
      expect(workflowEditOps(base, base), isEmpty);
    });

    test('add node + edge', () {
      final w = base.copyWith(
        nodes: [...base.nodes, n('post', NodeKind.action)],
        edges: [
          ...base.edges,
          e('e3', 'gate', 'post', port: 'pass'),
        ],
      );
      final ops = workflowEditOps(base, w);
      expect(
        ops,
        contains(
          predicate(
            (o) =>
                (o as Map)['op'] == 'add_node' &&
                (o['node'] as Map)['id'] == 'post',
          ),
        ),
      );
      expect(
        ops,
        contains(
          predicate(
            (o) =>
                (o as Map)['op'] == 'add_edge' &&
                (o['edge'] as Map)['fromPort'] == 'pass',
          ),
        ),
      );
    });

    test(
      'delete node → delete_node, and its edges are NOT separately deleted (backend cascade)',
      () {
        final w = base.copyWith(
          nodes: base.nodes.where((x) => x.id != 'gate').toList(),
          edges: base.edges.where((x) => x.to != 'gate').toList(),
        );
        final ops = workflowEditOps(base, w);
        expect(ops.where((o) => o['op'] == 'delete_node'), hasLength(1));
        expect(
          ops.where((o) => o['op'] == 'delete_edge'),
          isEmpty,
        ); // e2 touches gate → cascaded
      },
    );

    test('change ref → update_node with a ref-only patch', () {
      final w = base.copyWith(
        nodes: [
          for (final node in base.nodes)
            node.id == 'work' ? node.copyWith(ref: 'fn_new') : node,
        ],
      );
      final ops = workflowEditOps(base, w);
      expect(ops, hasLength(1));
      expect(ops.first['op'], 'update_node');
      expect((ops.first['patch'] as Map), {'ref': 'fn_new'});
    });

    test('move node → update_node with a pos-only patch', () {
      final w = base.copyWith(
        nodes: [
          for (final node in base.nodes)
            node.id == 'work'
                ? node.copyWith(pos: const NodePosition(x: 300, y: 40))
                : node,
        ],
      );
      final ops = workflowEditOps(base, w);
      expect((ops.first['patch'] as Map)['pos'], {'x': 300, 'y': 40});
    });

    test('change input → whole-map replace', () {
      final w = base.copyWith(
        nodes: [
          for (final node in base.nodes)
            node.id == 'work'
                ? node.copyWith(input: {'x': 'trigger.payload'})
                : node,
        ],
      );
      final ops = workflowEditOps(base, w);
      expect((ops.first['patch'] as Map)['input'], {'x': 'trigger.payload'});
    });

    test('change edge port → update_edge', () {
      final w = base.copyWith(
        edges: [
          for (final edge in base.edges)
            edge.id == 'e2' ? edge.copyWith(fromPort: 'retry') : edge,
        ],
      );
      final ops = workflowEditOps(base, w);
      expect(ops.first, {
        'op': 'update_edge',
        'id': 'e2',
        'patch': {'fromPort': 'retry'},
      });
    });
  });

  group('applyEditOps (inverse) + round-trip', () {
    test('applying the diff of A→B reproduces B', () {
      final b = base.copyWith(
        nodes: [
          for (final node in base.nodes)
            node.id == 'work'
                ? node.copyWith(
                    ref: 'fn_x',
                    pos: const NodePosition(x: 5, y: 9),
                  )
                : node,
          n('post', NodeKind.approval),
        ],
        edges: [
          for (final edge in base.edges)
            edge.id == 'e2' ? edge.copyWith(fromPort: 'go') : edge,
          e('e3', 'gate', 'post', port: 'branch1'),
        ],
      );
      final ops = workflowEditOps(base, b);
      final result = applyEditOps(base, ops);
      // Compare by id-keyed maps (order-independent). 按 id 比对(不管顺序)。
      expect(
        {for (final x in result.nodes) x.id: x},
        {for (final x in b.nodes) x.id: x},
      );
      expect(
        {for (final x in result.edges) x.id: x},
        {for (final x in b.edges) x.id: x},
      );
    });

    test('delete_node cascades edges', () {
      final ops = [
        {'op': 'delete_node', 'id': 'gate'},
      ];
      final r = applyEditOps(base, ops);
      expect(r.nodes.any((x) => x.id == 'gate'), isFalse);
      expect(r.edges.any((x) => x.to == 'gate'), isFalse); // e2 cascaded
    });
  });
}
