import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// The in-memory fixture repository — paging, idempotent mark-read/all (with the optional [MarkWindow]), live
// unread count, and emit that prepends a row + pushes a signal.

NotificationItem _n(String id, {bool read = false, DateTime? createdAt}) => NotificationItem(
      id: id,
      type: 'function.created',
      createdAt: createdAt ?? DateTime.utc(2026, 7, 6, 9),
      readAt: read ? DateTime.utc(2026, 7, 6, 9, 5) : null,
    );

void main() {
  test('lists newest-first with keyset paging', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b'), _n('c')]);
    final p1 = await repo.listNotifications(limit: 2);
    expect(p1.items.map((n) => n.id), ['a', 'b']);
    expect(p1.hasMore, isTrue);
    final p2 = await repo.listNotifications(cursor: p1.nextCursor, limit: 2);
    expect(p2.items.map((n) => n.id), ['c']);
    expect(p2.hasMore, isFalse);
  });

  test('unreadCount counts only unread; markRead is idempotent', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b', read: true), _n('c')]);
    expect(await repo.unreadCount(), 2);
    await repo.markRead('a');
    expect(await repo.unreadCount(), 1);
    await repo.markRead('a'); // idempotent — already read
    await repo.markRead('missing'); // unknown id — no throw
    expect(await repo.unreadCount(), 1);
  });

  test('markAllRead zeroes the count', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b'), _n('c')]);
    await repo.markAllRead();
    expect(await repo.unreadCount(), 0);
  });

  test('markAllUnread restores the full count (mirror of markAllRead)', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a'), _n('b', read: true), _n('c', read: true)]);
    expect(await repo.unreadCount(), 1);
    await repo.markAllUnread();
    expect(await repo.unreadCount(), 3); // every row now unread
  });

  test('markAllRead with a window marks only in-window rows (half-open [after, before))', () async {
    final earlier = _n('earlier', createdAt: DateTime.utc(2026, 7, 18, 9));
    final today = _n('today', createdAt: DateTime.utc(2026, 7, 20, 9));
    final repo = FixtureNotificationRepository(seed: [earlier, today]);
    // Window = [2026-07-20T00:00Z, ∞): only the "today" row falls inside.
    await repo.markAllRead(window: MarkWindow(after: DateTime.utc(2026, 7, 20)));
    final rows = (await repo.listNotifications()).items;
    expect(rows.firstWhere((r) => r.id == 'today').isUnread, isFalse); // in-window → read
    expect(rows.firstWhere((r) => r.id == 'earlier').isUnread, isTrue); // below the floor → untouched
    expect(await repo.unreadCount(), 1);
  });

  test('markAllRead window ceiling is exclusive (a row AT `before` is NOT marked)', () async {
    final atCeiling = _n('at', createdAt: DateTime.utc(2026, 7, 20));
    final below = _n('below', createdAt: DateTime.utc(2026, 7, 19, 23));
    final repo = FixtureNotificationRepository(seed: [atCeiling, below]);
    await repo.markAllRead(window: MarkWindow(before: DateTime.utc(2026, 7, 20)));
    final rows = (await repo.listNotifications()).items;
    expect(rows.firstWhere((r) => r.id == 'below').isUnread, isFalse); // strictly below → read
    expect(rows.firstWhere((r) => r.id == 'at').isUnread, isTrue); // == before → excluded (half-open)
  });

  test('markAllUnread with a window flips only in-window read rows', () async {
    final earlier = _n('earlier', read: true, createdAt: DateTime.utc(2026, 7, 18, 9));
    final today = _n('today', read: true, createdAt: DateTime.utc(2026, 7, 20, 9));
    final repo = FixtureNotificationRepository(seed: [earlier, today]);
    expect(await repo.unreadCount(), 0);
    await repo.markAllUnread(window: MarkWindow(after: DateTime.utc(2026, 7, 20)));
    final rows = (await repo.listNotifications()).items;
    expect(rows.firstWhere((r) => r.id == 'today').isUnread, isTrue); // in-window → unread
    expect(rows.firstWhere((r) => r.id == 'earlier').isUnread, isFalse); // outside → stays read
    expect(await repo.unreadCount(), 1);
  });

  test('emit prepends a row AND pushes an inbox-candidate signal', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a')]);
    final sigs = [];
    final sub = repo.signals().listen(sigs.add);
    repo.emit(_n('new'));
    await pumpEventQueue();
    final page = await repo.listNotifications();
    expect(page.items.first.id, 'new'); // prepended
    expect(await repo.unreadCount(), 2);
    expect(sigs.length, 1);
    expect(sigs.first.inboxCandidate, isTrue);
    await sub.cancel();
    repo.dispose();
  });

  test('emitEcho pushes a signal WITHOUT adding a row (frame-only)', () async {
    final repo = FixtureNotificationRepository(seed: [_n('a')]);
    final sigs = [];
    final sub = repo.signals().listen(sigs.add);
    repo.emitEcho('conversation.created');
    await pumpEventQueue();
    expect((await repo.listNotifications()).items.length, 1); // no new row
    expect(sigs.single.inboxCandidate, isFalse); // conversation.* is a non-candidate
    await sub.cancel();
    repo.dispose();
  });
}
