import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/graph/graph_run_state.dart';
import 'package:flutter_test/flutter_test.dart';

Node n(String id, NodeKind k) => Node(id: id, kind: k, ref: '${k.name}_$id');
Edge e(String id, String from, String to, {String? port}) =>
    Edge(id: id, from: from, fromPort: port, to: to);

final _t = DateTime.utc(2026, 7, 3);
FlowrunNode row(String nodeId, String status,
        {int iteration = 0, Map<String, Object?> result = const {}}) =>
    FlowrunNode(
        id: 'frn_${nodeId}_$iteration',
        flowrunId: 'flr_1',
        nodeId: nodeId,
        iteration: iteration,
        status: status,
        result: result,
        createdAt: _t,
        updatedAt: _t);

// trigger → action → control —pass→ action / —retry(back)→ action. 分支 + 回边参照图。
final g = Graph(nodes: [
  n('t', NodeKind.trigger),
  n('work', NodeKind.action),
  n('gate', NodeKind.control),
  n('post', NodeKind.action),
], edges: [
  e('e1', 't', 'work'),
  e('e2', 'work', 'gate'),
  e('e3', 'gate', 'post', port: 'pass'),
  e('back', 'gate', 'work', port: 'retry'),
]);

void main() {
  group('deriveRunState', () {
    test('empty rows → empty overlay', () {
      expect(deriveRunState(g, rows: const [], runStatus: 'running'), same(GraphRunState.empty));
    });

    test('linear walk: completed nodes, taken edges, running successor synthesized', () {
      final s = deriveRunState(g,
          rows: [row('t', 'completed'), row('work', 'completed')], runStatus: 'running');
      expect(s.nodes['t'], GraphNodeRun.completed);
      expect(s.nodes['work'], GraphNodeRun.completed);
      // gate has no row yet → synthesized running via e2. gate 无行 → 经 e2 合成 running。
      expect(s.nodes['gate'], GraphNodeRun.running);
      expect(s.liveEdges, {'e2'});
      expect(s.takenEdges, {'e1'});
      expect(s.nodes.containsKey('post'), isFalse); // future 未走到
    });

    test('control port gates its out-edges: only the recorded __port is taken', () {
      final s = deriveRunState(g,
          rows: [
            row('t', 'completed'),
            row('work', 'completed'),
            row('gate', 'completed', result: {'__port': 'pass'}),
            row('post', 'completed'),
          ],
          runStatus: 'completed');
      expect(s.takenEdges, {'e1', 'e2', 'e3'});
      expect(s.takenEdges.contains('back'), isFalse); // retry 未选,不亮
      expect(s.liveEdges, isEmpty); // terminal run 无合成
    });

    test('retry loop: back edge targets iteration+1; ×N counts; running re-run lights', () {
      final s = deriveRunState(g,
          rows: [
            row('t', 'completed'),
            row('work', 'completed', iteration: 0),
            row('gate', 'completed', iteration: 0, result: {'__port': 'retry'}),
          ],
          runStatus: 'running');
      // gate@0 chose retry → work due at iteration 1, no row → running ×2 via the back edge.
      // gate@0 选 retry → work 应跑 iter1、无行 → 经回边合成 running ×2。
      expect(s.nodes['work'], GraphNodeRun.running);
      expect(s.iters['work'], 2);
      expect(s.liveEdges, {'back'});
      // …and once iteration 1 lands, the back edge is TAKEN. iter1 落行后回边 taken。
      final s2 = deriveRunState(g,
          rows: [
            row('t', 'completed'),
            row('work', 'completed', iteration: 0),
            row('gate', 'completed', iteration: 0, result: {'__port': 'retry'}),
            row('work', 'completed', iteration: 1),
          ],
          runStatus: 'running');
      expect(s2.takenEdges.contains('back'), isTrue);
      expect(s2.iters['work'], 2);
      expect(s2.nodes['gate'], GraphNodeRun.running); // gate due at iter 1 now gate 应跑 iter1
    });

    test('parked node blocks running synthesis (the run waits on a human)', () {
      final ga = Graph(nodes: [
        n('t', NodeKind.trigger),
        n('gate', NodeKind.approval),
        n('post', NodeKind.action),
      ], edges: [
        e('e1', 't', 'gate'),
        e('e2', 'gate', 'post', port: 'yes'),
      ]);
      final s = deriveRunState(ga,
          rows: [row('t', 'completed'), row('gate', 'parked')], runStatus: 'running');
      expect(s.nodes['gate'], GraphNodeRun.parked);
      expect(s.liveEdges, isEmpty);
      expect(s.nodes.containsKey('post'), isFalse);
    });

    test('approval decision gates the yes/no edge', () {
      final ga = Graph(nodes: [
        n('t', NodeKind.trigger),
        n('gate', NodeKind.approval),
        n('ok', NodeKind.action),
        n('no', NodeKind.action),
      ], edges: [
        e('ey', 't', 'gate'),
        e('yes', 'gate', 'ok', port: 'yes'),
        e('noe', 'gate', 'no', port: 'no'),
      ]);
      final s = deriveRunState(ga,
          rows: [
            row('t', 'completed'),
            row('gate', 'completed', result: {'decision': 'yes'}),
            row('ok', 'completed'),
          ],
          runStatus: 'completed');
      expect(s.takenEdges, {'ey', 'yes'});
      expect(s.takenEdges.contains('noe'), isFalse);
    });

    test('failed run: no synthesis, failed node red', () {
      final s = deriveRunState(g,
          rows: [row('t', 'completed'), row('work', 'failed')], runStatus: 'failed');
      expect(s.nodes['work'], GraphNodeRun.failed);
      expect(s.liveEdges, isEmpty);
    });

    test('tick rows (no result) leave port edges honestly unlit until reconcile', () {
      final s = deriveRunState(g,
          rows: [
            row('t', 'completed'),
            row('work', 'completed'),
            row('gate', 'completed'), // tick 无 __port
            row('post', 'completed'),
          ],
          runStatus: 'completed');
      expect(s.takenEdges.contains('e3'), isFalse); // 不瞎猜端口
      expect(s.nodes['post'], GraphNodeRun.completed);
    });

    test('rows referencing unknown node ids are harmless', () {
      final s = deriveRunState(g,
          rows: [row('ghost', 'completed'), row('t', 'completed')], runStatus: 'running');
      expect(s.nodes['ghost'], GraphNodeRun.completed); // 存在于 map,但画布查不到就不渲
      expect(s.nodes['t'], GraphNodeRun.completed);
    });
  });
}
