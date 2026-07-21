import 'package:anselm/core/model/partial_json.dart';
import 'package:anselm/features/chat/ui/tool_card_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

// C-042 — the workflow stage + card rebuild graphFromWorkflowOps every merge frame while args stream, but
// the closed-op set only grows on an op close. Memoized by closed-op count → the SAME Graph instance is
// returned between op closes, so AnGraphCanvas skips its O(V+E) deep-compare + re-layout by identity.
// 按闭合 op 数记忆化:op 未变返回同一 Graph 实例,canvas 跳深比较+重布局。
void main() {
  test('same session, no new op → the SAME Graph instance (identity)', () {
    final s = PartialJsonSession()
      ..append('{"ops":[{"op":"add_node","node":{"id":"a","kind":"trigger"}},');
    final g1 = graphFromWorkflowOps(s);
    final g1b = graphFromWorkflowOps(s);
    expect(identical(g1, g1b), isTrue, reason: 'op 数未变→同实例');
    expect(g1.nodes.length, 1);
  });

  test('a new closed op → a NEW instance with the added node', () {
    final s = PartialJsonSession()
      ..append('{"ops":[{"op":"add_node","node":{"id":"a","kind":"trigger"}},');
    final g1 = graphFromWorkflowOps(s);
    s.append('{"op":"add_node","node":{"id":"b","kind":"action"}},');
    final g2 = graphFromWorkflowOps(s);
    expect(identical(g1, g2), isFalse, reason: 'op 增→新实例');
    expect(g2.nodes.length, 2);
    expect(g2.nodes.map((n) => n.id), containsAll(['a', 'b']));
  });

  test('edges surface too, and the memo holds across a stable read', () {
    final s = PartialJsonSession()
      ..append(
        '{"ops":[{"op":"add_node","node":{"id":"a","kind":"trigger"}},'
        '{"op":"add_edge","edge":{"id":"e1","from":"a","to":"b"}},',
      );
    final g = graphFromWorkflowOps(s);
    expect(g.nodes.length, 1);
    expect(g.edges.length, 1);
    expect(identical(graphFromWorkflowOps(s), g), isTrue);
  });
}
