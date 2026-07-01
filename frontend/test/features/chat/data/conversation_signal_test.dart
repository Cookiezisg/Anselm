import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/conversation_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// The conversation lifecycle projection off the notifications stream. Frames arrive with
// scope.kind="notification", so the domain+action live in node.type ("conversation.auto_titled") and the
// id in the payload (conversationId). Pins: domain match, id extraction, action vocab, durability.

StreamEnvelope _notif(String type, Map<String, dynamic>? content, {int seq = 7}) => StreamEnvelope(
      seq: seq,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: FrameSignal(node: StreamNode(type: type, content: content)),
    );

void main() {
  test('projects a matching conversation frame (id + action + durable)', () {
    final s = ConversationSignal.fromEnvelope(_notif('conversation.created', {'conversationId': 'cv_1'}));
    expect(s, isNotNull);
    expect(s!.id, 'cv_1');
    expect(s.action, ConversationAction.created);
    expect(s.durable, isTrue);
  });

  test('drops a frame for a different domain', () {
    expect(ConversationSignal.fromEnvelope(_notif('function.created', {'functionId': 'fn_1'})), isNull);
  });

  test('drops a non-Signal frame and a frame missing the id', () {
    final delta = StreamEnvelope(
      seq: 7,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: const FrameDelta(chunk: 'x'),
    );
    expect(ConversationSignal.fromEnvelope(delta), isNull);
    expect(ConversationSignal.fromEnvelope(_notif('conversation.updated', null)), isNull);
    expect(ConversationSignal.fromEnvelope(_notif('conversation.updated', const {})), isNull);
  });

  test('ephemeral frame (seq 0) → durable false (list must NOT patch)', () {
    final s = ConversationSignal.fromEnvelope(_notif('conversation.updated', {'conversationId': 'cv_1'}, seq: 0));
    expect(s!.durable, isFalse);
  });

  test('action vocab collapses correctly', () {
    ConversationAction act(String type) =>
        ConversationSignal.fromEnvelope(_notif(type, {'conversationId': 'cv_1'}))!.action;

    expect(act('conversation.created'), ConversationAction.created);
    expect(act('conversation.deleted'), ConversationAction.deleted);
    expect(act('conversation.updated'), ConversationAction.updated);
    expect(act('conversation.auto_titled'), ConversationAction.updated);
    expect(act('conversation.archived'), ConversationAction.updated);
    expect(act('conversation.unarchived'), ConversationAction.updated);
    expect(act('conversation.pinned'), ConversationAction.updated);
    expect(act('conversation.unpinned'), ConversationAction.updated);
    expect(act('conversation.model_override'), ConversationAction.updated);
    expect(act('conversation.compacted'), ConversationAction.updated);
    expect(act('conversation.surprise'), ConversationAction.unknown);
  });
}
