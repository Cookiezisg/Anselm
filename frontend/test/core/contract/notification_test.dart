import 'package:anselm/core/contract/notification.dart';
import 'package:flutter_test/flutter_test.dart';

// The notification-center row DTO — the backend projection (camelCase). Pins: readAt absent = unread,
// payload defaults to {}, domain/action split, and a present readAt = read.

void main() {
  test('parses an unread row (readAt absent → isUnread)', () {
    final n = NotificationItem.fromJson({
      'id': 'noti_1',
      'type': 'workflow.run_failed',
      'payload': {'workflowId': 'wf_1', 'flowrunId': 'fr_1', 'error': 'boom'},
      'createdAt': '2026-07-06T09:00:00Z',
    });
    expect(n.id, 'noti_1');
    expect(n.type, 'workflow.run_failed');
    expect(n.payload['workflowId'], 'wf_1');
    expect(n.readAt, isNull);
    expect(n.isUnread, isTrue);
    expect(n.domain, 'workflow');
    expect(n.action, 'run_failed');
  });

  test('parses a read row (readAt present → not unread)', () {
    final n = NotificationItem.fromJson({
      'id': 'noti_2',
      'type': 'function.created',
      'createdAt': '2026-07-06T09:00:00Z',
      'readAt': '2026-07-06T09:05:00Z',
    });
    expect(n.isUnread, isFalse);
    expect(n.readAt, DateTime.utc(2026, 7, 6, 9, 5));
    // payload absent on the wire → defaults to an empty map (never null). payload 缺席=空 map。
    expect(n.payload, isEmpty);
  });

  test('domain/action degrade gracefully for a dotless type', () {
    final n = NotificationItem.fromJson({
      'id': 'noti_3',
      'type': 'weird',
      'createdAt': '2026-07-06T09:00:00Z',
    });
    expect(n.domain, 'weird');
    expect(n.action, '');
  });
}
