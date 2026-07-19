import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 1 gate — the lifecycle projection. Notifications all arrive with scope.kind="notification", so
// the entity kind+action live in node.type ("function.created") and the id in the payload; this is the
// one place that reconciliation is parsed. Pins: kind match, id extraction, action vocab, durability.

StreamEnvelope _notif(String type, Map<String, dynamic>? content, {int seq = 7}) => StreamEnvelope(
      seq: seq,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: FrameSignal(node: StreamNode(type: type, content: content)),
    );

void main() {
  test('projects a matching lifecycle frame (kind + id + action + durable)', () {
    final s = EntitySignal.fromEnvelope(
        EntityKind.function, _notif('function.created', {'functionId': 'fn_1'}));
    expect(s, isNotNull);
    expect(s!.kind, EntityKind.function);
    expect(s.id, 'fn_1');
    expect(s.action, EntityAction.created);
    expect(s.durable, isTrue);
  });

  test('drops a frame for a different kind', () {
    expect(
      EntitySignal.fromEnvelope(EntityKind.handler, _notif('function.created', {'functionId': 'fn_1'})),
      isNull,
    );
  });

  test('drops a non-Signal frame and a frame missing the id', () {
    final delta = StreamEnvelope(
      seq: 7,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: const FrameDelta(chunk: 'x'),
    );
    expect(EntitySignal.fromEnvelope(EntityKind.function, delta), isNull);
    expect(EntitySignal.fromEnvelope(EntityKind.function, _notif('function.created', null)), isNull);
    expect(EntitySignal.fromEnvelope(EntityKind.function, _notif('function.created', const {})), isNull);
  });

  test('ephemeral frame (seq 0) → durable false (list must NOT patch)', () {
    final s = EntitySignal.fromEnvelope(
        EntityKind.agent, _notif('agent.updated', {'agentId': 'ag_1'}, seq: 0));
    expect(s!.durable, isFalse);
  });

  test('action vocab collapses correctly', () {
    EntityAction act(EntityKind k, String type, String idField, String id) =>
        EntitySignal.fromEnvelope(k, _notif(type, {idField: id}))!.action;

    expect(act(EntityKind.function, 'function.created', 'functionId', 'fn_1'), EntityAction.created);
    expect(act(EntityKind.function, 'function.deleted', 'functionId', 'fn_1'), EntityAction.deleted);
    expect(act(EntityKind.function, 'function.edited', 'functionId', 'fn_1'), EntityAction.edited);
    expect(act(EntityKind.function, 'function.reverted', 'functionId', 'fn_1'), EntityAction.edited);
    expect(act(EntityKind.function, 'function.env_rebuilt', 'functionId', 'fn_1'), EntityAction.updated);
    expect(act(EntityKind.handler, 'handler.crashed', 'handlerId', 'hd_1'), EntityAction.updated);
    expect(act(EntityKind.handler, 'handler.config_updated', 'handlerId', 'hd_1'), EntityAction.updated);
    expect(act(EntityKind.workflow, 'workflow.lifecycle_changed', 'workflowId', 'wf_1'), EntityAction.updated);
    expect(act(EntityKind.workflow, 'workflow.attention_changed', 'workflowId', 'wf_1'), EntityAction.updated);
    expect(act(EntityKind.workflow, 'workflow.surprise', 'workflowId', 'wf_1'), EntityAction.unknown);
  });
}
