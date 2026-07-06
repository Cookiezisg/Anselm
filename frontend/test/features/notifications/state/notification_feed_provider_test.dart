import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/state/notification_feed_provider.dart';
import 'package:anselm/features/notifications/state/unread_count_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The feed notifier. Pins: initial page, a durable inbox tick merges the new head (never fabricates off a
// frame — refetches), a non-candidate echo does NOT merge, 410 reloads, mark-read/all are optimistic and
// drop the badge.

NotificationItem _n(String id, {String type = 'function.created', bool read = false}) => NotificationItem(
      id: id,
      type: type,
      payload: const {'name': 'x'},
      createdAt: DateTime.utc(2026, 7, 6, 12),
      readAt: read ? DateTime.utc(2026, 7, 6, 12) : null,
    );

void main() {
  (ProviderContainer, FixtureNotificationRepository) setup(List<NotificationItem> seed) {
    final repo = FixtureNotificationRepository(seed: seed);
    final c = ProviderContainer(overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
      notificationDebounceProvider.overrideWithValue(Duration.zero),
    ]);
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

  test('an inbox-candidate tick merges the new head (refetch, not fabricate)', () async {
    final (c, repo) = setup([_n('a')]);
    await c.read(notificationFeedProvider.future);
    repo.emit(_n('b')); // prepends a row + candidate signal
    await pumpEventQueue();
    expect(c.read(notificationFeedProvider).value!.rows.map((r) => r.id), ['b', 'a']);
  });

  test('a non-candidate echo does NOT merge (conversation.* is frame-only)', () async {
    final (c, repo) = setup([_n('a')]);
    await c.read(notificationFeedProvider.future);
    repo.addSilently(_n('b')); // landed silently
    repo.emitEcho('conversation.created'); // non-candidate → no refetch
    await pumpEventQueue();
    expect(c.read(notificationFeedProvider).value!.rows.map((r) => r.id), ['a']);
  });

  test('410 resync reloads the whole feed', () async {
    final (c, repo) = setup([_n('a')]);
    await c.read(notificationFeedProvider.future);
    repo.addSilently(_n('b'));
    repo.emitResync();
    await pumpEventQueue();
    expect(c.read(notificationFeedProvider).value!.rows.map((r) => r.id), containsAll(['a', 'b']));
  });

  test('markRead is optimistic + drops the badge', () async {
    final (c, repo) = setup([_n('a'), _n('b')]);
    await c.read(notificationFeedProvider.future);
    await c.read(unreadCountProvider.future); // 2 unread
    expect(c.read(unreadCountProvider).value, 2);

    await c.read(notificationFeedProvider.notifier).markRead('a');
    final rowA = c.read(notificationFeedProvider).value!.rows.firstWhere((r) => r.id == 'a');
    expect(rowA.isUnread, isFalse); // optimistically read
    expect(c.read(unreadCountProvider).value, 1); // badge dropped
    expect(await repo.unreadCount(), 1); // persisted
  });

  test('markAllRead zeroes the feed reads + the badge', () async {
    final (c, repo) = setup([_n('a'), _n('b'), _n('c')]);
    await c.read(notificationFeedProvider.future);
    await c.read(unreadCountProvider.future);
    await c.read(notificationFeedProvider.notifier).markAllRead();
    expect(c.read(notificationFeedProvider).value!.rows.every((r) => !r.isUnread), isTrue);
    expect(c.read(unreadCountProvider).value, 0);
    expect(await repo.unreadCount(), 0);
  });
}
