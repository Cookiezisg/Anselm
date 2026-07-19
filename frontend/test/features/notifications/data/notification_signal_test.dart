import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/notifications/data/notification_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// The notifications-stream nudge projection. Pins: only Signal frames project; durability rides the seq;
// inboxCandidate drops the guaranteed-frame-only echoes (conversation.* + document tree refresh) but KEEPS
// the ambiguous ⤳ types (memory.updated pin, sandbox installing) so a real sibling row is never missed.

StreamEnvelope _notif(String type, {int seq = 7}) => StreamEnvelope(
      seq: seq,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: FrameSignal(node: StreamNode(type: type, content: const {})),
    );

void main() {
  test('projects an inbox-worthy frame as a durable candidate', () {
    final s = NotificationSignal.fromEnvelope(_notif('workflow.run_failed'));
    expect(s, isNotNull);
    expect(s!.type, 'workflow.run_failed');
    expect(s.durable, isTrue);
    expect(s.inboxCandidate, isTrue);
  });

  test('drops non-Signal frames and dotless types', () {
    final delta = StreamEnvelope(
      seq: 7,
      scope: const StreamScope(kind: 'notification', id: 'noti_1'),
      id: 'noti_1',
      frame: const FrameDelta(chunk: 'x'),
    );
    expect(NotificationSignal.fromEnvelope(delta), isNull);
    expect(NotificationSignal.fromEnvelope(_notif('nodot')), isNull);
  });

  test('ephemeral frame (seq 0) → durable false', () {
    expect(NotificationSignal.fromEnvelope(_notif('function.created', seq: 0))!.durable, isFalse);
  });

  test('conversation.* + document tree refresh are NON-candidates (guaranteed frame-only)', () {
    for (final t in [
      'conversation.created',
      'conversation.updated',
      'conversation.pinned',
      'conversation.deleted',
      'document.created',
      'document.updated',
      'document.moved',
    ]) {
      expect(NotificationSignal.fromEnvelope(_notif(t))!.inboxCandidate, isFalse, reason: t);
    }
  });

  test('ambiguous ⤳ types stay candidates (must not miss a real sibling row)', () {
    // memory.updated is a pin echo OR a content write; sandbox installing OR ready — same type. The signal
    // can't tell, so it stays a candidate and the count refetch reconciles. document.deleted IS an inbox row.
    for (final t in [
      'memory.updated',
      'handler.restarted',
      'sandbox.env_status_changed',
      'sandbox.env_deleted',
      'document.deleted',
    ]) {
      expect(NotificationSignal.fromEnvelope(_notif(t))!.inboxCandidate, isTrue, reason: t);
    }
  });
}
