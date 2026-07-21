import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/data/notification_repository.dart';
import 'package:anselm/features/notifications/state/notification_feed_provider.dart';
import 'package:anselm/features/notifications/state/unread_count_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The feed notifier. Pins: initial page, a durable inbox tick merges the new head (never fabricates off a
// frame — refetches), a non-candidate echo does NOT merge, 410 reloads, mark-read/all are optimistic and
// drop the badge, and a WINDOWED mark-all scopes to just that time-group + reconciles the badge by refetch.

NotificationItem _n(
  String id, {
  String type = 'function.created',
  bool read = false,
  DateTime? createdAt,
}) => NotificationItem(
  id: id,
  type: type,
  payload: const {'name': 'x'},
  createdAt: createdAt ?? DateTime.utc(2026, 7, 6, 12),
  readAt: read ? DateTime.utc(2026, 7, 6, 12) : null,
);

void main() {
  (ProviderContainer, FixtureNotificationRepository) setup(
    List<NotificationItem> seed,
  ) {
    final repo = FixtureNotificationRepository(seed: seed);
    final c = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        notificationDebounceProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(c.dispose);
    c.listen(notificationFeedProvider, (_, _) {});
    c.listen(unreadCountProvider, (_, _) {});
    return (c, repo);
  }

  test('initial build loads the first page newest-first', () async {
    final (c, _) = setup([_n('a'), _n('b')]);
    final s = await c.read(notificationFeedProvider.future);
    expect(s.rows.map((r) => r.id), ['a', 'b']);
  });

  test(
    'an inbox-candidate tick merges the new head (refetch, not fabricate)',
    () async {
      final (c, repo) = setup([_n('a')]);
      await c.read(notificationFeedProvider.future);
      repo.emit(_n('b')); // prepends a row + candidate signal
      await pumpEventQueue();
      expect(c.read(notificationFeedProvider).value!.rows.map((r) => r.id), [
        'b',
        'a',
      ]);
    },
  );

  test(
    'a non-candidate echo does NOT merge (conversation.* is frame-only)',
    () async {
      final (c, repo) = setup([_n('a')]);
      await c.read(notificationFeedProvider.future);
      repo.addSilently(_n('b')); // landed silently
      repo.emitEcho('conversation.created'); // non-candidate → no refetch
      await pumpEventQueue();
      expect(c.read(notificationFeedProvider).value!.rows.map((r) => r.id), [
        'a',
      ]);
    },
  );

  test('410 resync reloads the whole feed', () async {
    final (c, repo) = setup([_n('a')]);
    await c.read(notificationFeedProvider.future);
    repo.addSilently(_n('b'));
    repo.emitResync();
    await pumpEventQueue();
    expect(
      c.read(notificationFeedProvider).value!.rows.map((r) => r.id),
      containsAll(['a', 'b']),
    );
  });

  test('markRead is optimistic + drops the badge', () async {
    final (c, repo) = setup([_n('a'), _n('b')]);
    await c.read(notificationFeedProvider.future);
    await c.read(unreadCountProvider.future); // 2 unread
    expect(c.read(unreadCountProvider).value, 2);

    await c.read(notificationFeedProvider.notifier).markRead('a');
    final rowA = c
        .read(notificationFeedProvider)
        .value!
        .rows
        .firstWhere((r) => r.id == 'a');
    expect(rowA.isUnread, isFalse); // optimistically read
    expect(c.read(unreadCountProvider).value, 1); // badge dropped
    expect(await repo.unreadCount(), 1); // persisted
  });

  test('markAllRead zeroes the feed reads + the badge', () async {
    final (c, repo) = setup([_n('a'), _n('b'), _n('c')]);
    await c.read(notificationFeedProvider.future);
    await c.read(unreadCountProvider.future);
    await c.read(notificationFeedProvider.notifier).markAllRead();
    expect(
      c.read(notificationFeedProvider).value!.rows.every((r) => !r.isUnread),
      isTrue,
    );
    expect(c.read(unreadCountProvider).value, 0);
    expect(await repo.unreadCount(), 0);
  });

  test(
    'markAllUnread flips the feed rows unread + REFETCHES the authoritative badge (N0)',
    () async {
      final (c, repo) = setup([
        _n('a', read: true),
        _n('b', read: true),
        _n('c', read: true),
      ]);
      await c.read(notificationFeedProvider.future);
      await c.read(unreadCountProvider.future); // 0 unread
      expect(c.read(unreadCountProvider).value, 0);
      await c.read(notificationFeedProvider.notifier).markAllUnread();
      expect(
        c.read(notificationFeedProvider).value!.rows.every((r) => r.isUnread),
        isTrue,
      ); // optimistic flip
      expect(
        c.read(unreadCountProvider).value,
        3,
      ); // refetched authoritative count, not a local guess
      expect(await repo.unreadCount(), 3); // persisted
    },
  );

  test(
    'windowed markAllRead marks only in-window rows + REFETCHES the badge (never zeros past a window)',
    () async {
      // Two time-groups: an "earlier" row + a "today" row. Clearing the "today" window must leave the earlier
      // one unread — and the badge must reconcile to the authoritative COUNT (1), never optimistically zero.
      final earlier = _n('earlier', createdAt: DateTime.utc(2026, 7, 18, 9));
      final today = _n('today', createdAt: DateTime.utc(2026, 7, 20, 9));
      final (c, repo) = setup([earlier, today]);
      await c.read(notificationFeedProvider.future);
      await c.read(unreadCountProvider.future); // 2 unread
      expect(c.read(unreadCountProvider).value, 2);

      await c
          .read(notificationFeedProvider.notifier)
          .markAllRead(window: MarkWindow(after: DateTime.utc(2026, 7, 20)));

      final rows = c.read(notificationFeedProvider).value!.rows;
      expect(
        rows.firstWhere((r) => r.id == 'today').isUnread,
        isFalse,
      ); // in-window → optimistically read
      expect(
        rows.firstWhere((r) => r.id == 'earlier').isUnread,
        isTrue,
      ); // outside → untouched
      expect(
        c.read(unreadCountProvider).value,
        1,
      ); // refetched authoritative count (NOT zeroed)
      expect(await repo.unreadCount(), 1); // persisted
    },
  );

  test('windowed markAllUnread flips only in-window rows', () async {
    final earlier = _n(
      'earlier',
      read: true,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );
    final today = _n(
      'today',
      read: true,
      createdAt: DateTime.utc(2026, 7, 20, 9),
    );
    final (c, repo) = setup([earlier, today]);
    await c.read(notificationFeedProvider.future);
    await c.read(unreadCountProvider.future); // 0 unread

    await c
        .read(notificationFeedProvider.notifier)
        .markAllUnread(window: MarkWindow(after: DateTime.utc(2026, 7, 20)));

    final rows = c.read(notificationFeedProvider).value!.rows;
    expect(
      rows.firstWhere((r) => r.id == 'today').isUnread,
      isTrue,
    ); // in-window → unread
    expect(
      rows.firstWhere((r) => r.id == 'earlier').isUnread,
      isFalse,
    ); // outside → stays read
    expect(c.read(unreadCountProvider).value, 1); // authoritative refetch
    expect(await repo.unreadCount(), 1);
  });
}
