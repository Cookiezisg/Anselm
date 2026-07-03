import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/graph/flowrun_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

Node n(String id, NodeKind k) => Node(id: id, kind: k, ref: '${k.name}_$id');
Edge e(String id, String from, String to) => Edge(id: id, from: from, to: to);

final _t = DateTime.utc(2026, 7, 3, 12);
FlowrunNode row(String nodeId, String status,
        {int iteration = 0, int startSec = 0, int? endSec}) =>
    FlowrunNode(
        id: 'frn_${nodeId}_$iteration',
        flowrunId: 'flr_1',
        nodeId: nodeId,
        iteration: iteration,
        status: status,
        createdAt: _t.add(Duration(seconds: startSec)),
        completedAt: endSec == null ? null : _t.add(Duration(seconds: endSec)),
        updatedAt: _t);

FlowrunComposite comp(List<FlowrunNode> nodes, {String status = 'completed'}) => FlowrunComposite(
    flowrun: Flowrun(
        id: 'flr_1',
        workflowId: 'wf_1',
        status: status,
        startedAt: _t,
        completedAt: status == 'completed' ? _t.add(const Duration(seconds: 10)) : null,
        updatedAt: _t),
    nodes: nodes);

final g = Graph(nodes: [
  n('t', NodeKind.trigger),
  n('work', NodeKind.action),
  n('gate', NodeKind.approval),
  n('post', NodeKind.action),
], edges: [
  e('e1', 't', 'work'),
  e('e2', 'work', 'gate'),
  e('e3', 'gate', 'post'),
]);

void main() {
  group('flowrunTimeline', () {
    test('rows in graph declaration order; unrun node → empty stub', () {
      final rows = flowrunTimeline(g, comp([row('t', 'completed', endSec: 1)]));
      expect(rows.map((r) => r.nodeId), ['t', 'work', 'gate', 'post']);
      expect(rows[0].segments, hasLength(1)); // t ran
      expect(rows[1].segments, isEmpty); // work never ran → 未运行
      expect(rows[1].iterations, 0);
    });

    test('time-mode positions bars by createdAt/completedAt over the run span', () {
      final rows = flowrunTimeline(
          g,
          comp([
            row('t', 'completed', startSec: 0, endSec: 1),
            row('work', 'completed', startSec: 1, endSec: 5), // the slow one 慢节点
            row('gate', 'completed', startSec: 5, endSec: 6),
          ]));
      final work = rows.firstWhere((r) => r.nodeId == 'work');
      final t = rows.firstWhere((r) => r.nodeId == 't');
      // work's bar is wider (4s vs 1s) and starts later. 慢节点条更宽、起点更靠右。
      expect(work.segments.first.w, greaterThan(t.segments.first.w));
      expect(work.segments.first.at, greaterThan(t.segments.first.at));
    });

    test('loop iterations → N segments + iterations count', () {
      final rows = flowrunTimeline(
          g,
          comp([
            row('t', 'completed', endSec: 1),
            row('work', 'completed', iteration: 0, startSec: 1, endSec: 2),
            row('work', 'completed', iteration: 1, startSec: 2, endSec: 3),
            row('work', 'completed', iteration: 2, startSec: 3, endSec: 4),
          ]));
      final work = rows.firstWhere((r) => r.nodeId == 'work');
      expect(work.segments, hasLength(3));
      expect(work.iterations, 3);
    });

    test('parked node → parked flag + latest status', () {
      final rows = flowrunTimeline(
          g,
          comp([
            row('t', 'completed', endSec: 1),
            row('gate', 'parked', startSec: 1),
          ], status: 'running'));
      final gate = rows.firstWhere((r) => r.nodeId == 'gate');
      expect(gate.parked, isTrue);
      expect(gate.status, 'parked');
    });

    test('zero-span run falls back to sequential slots (still reads left→right)', () {
      // All same timestamp (a sub-ms run). 全同一时刻。
      final rows = flowrunTimeline(
          g,
          comp([
            row('t', 'completed'),
            row('work', 'completed'),
            row('gate', 'completed'),
          ]));
      final positions = [
        for (final id in ['t', 'work', 'gate']) rows.firstWhere((r) => r.nodeId == id).segments.first.at
      ];
      // Strictly increasing slots. 严格递增槽位。
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
    });

    test('all fractions stay in [0,1]', () {
      final rows = flowrunTimeline(
          g,
          comp([
            row('t', 'completed', startSec: 0, endSec: 1),
            row('work', 'completed', startSec: 1, endSec: 10),
          ]));
      for (final r in rows) {
        for (final s in r.segments) {
          expect(s.at, inInclusiveRange(0, 1));
          expect(s.at + s.w, lessThanOrEqualTo(1.0001));
        }
      }
    });

    test('orphan row (nodeId not in graph) is appended, not dropped', () {
      final rows = flowrunTimeline(g, comp([row('ghost', 'completed', endSec: 1)]));
      expect(rows.map((r) => r.nodeId), contains('ghost'));
      expect(rows.firstWhere((r) => r.nodeId == 'ghost').kind, NodeKind.unknown);
    });
  });
}
