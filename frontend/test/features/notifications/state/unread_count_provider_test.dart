import 'package:anselm/core/contract/notification.dart';
import 'package:anselm/features/notifications/data/notification_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/notifications/state/unread_count_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The unread badge. Truth = the backend COUNT: the notifier NEVER +1s off a frame — it debounce-refetches
// the authoritative count on an inbox-worthy tick, refetches on 410, and drops optimistically on mark-read.
// Pins: initial fetch, candidate tick → refetch, non-candidate echo → NO refetch, resync → refetch,
// optimistic mark-one / mark-all.

NotificationItem _n(
  String id, {
  String type = 'function.created',
  bool read = false,
}) => NotificationItem(
  id: id,
  type: type,
  createdAt: DateTime.utc(2026, 7, 6, 9),
  readAt: read ? DateTime.utc(2026, 7, 6, 9, 5) : null,
);

void main() {
  (ProviderContainer, FixtureNotificationRepository) setup(
    List<NotificationItem> seed,
  ) {
    final repo = FixtureNotificationRepository(seed: seed);
    final c = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        // Zero debounce → the refetch fires on the next microtask (pumpEventQueue flushes it). 零去抖。
        notificationDebounceProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(c.dispose);
    c.listen(unreadCountProvider, (_, _) {});
    return (c, repo);
  }

  test('initial build reads the authoritative count', () async {
    final (c, _) = setup([_n('a'), _n('b'), _n('c', read: true)]);
    expect(await c.read(unreadCountProvider.future), 2);
  });

  test(
    'an inbox-candidate tick debounce-refetches (never +1) — picks up the new row',
    () async {
      final (c, repo) = setup([_n('a')]);
      await c.read(unreadCountProvider.future);
      expect(c.read(unreadCountProvider).value, 1);

      repo.emit(_n('b')); // prepends a row + pushes a candidate signal
      await pumpEventQueue();
      expect(c.read(unreadCountProvider).value, 2); // refetched authoritatively
    },
  );

  test('a non-candidate echo (conversation.*) triggers NO refetch', () async {
    final (c, repo) = setup([_n('a')]);
    await c.read(unreadCountProvider.future);
    final callsAfterBuild = repo.unreadCountCalls;

    // A row landed silently (as if during a disconnect) — a refetch WOULD see it; an ignored echo won't.
    repo.addSilently(_n('b'));
    repo.emitEcho('conversation.created'); // non-candidate → must not refetch
    await pumpEventQueue();

    expect(repo.unreadCountCalls, callsAfterBuild); // no extra read
    expect(
      c.read(unreadCountProvider).value,
      1,
    ); // badge unchanged, silent row not surfaced
  });

  test(
    'a 410 resync refetches immediately (surfaces the silently-landed row)',
    () async {
      final (c, repo) = setup([_n('a')]);
      await c.read(unreadCountProvider.future);
      repo.addSilently(_n('b'));
      repo.emitResync();
      await pumpEventQueue();
      expect(c.read(unreadCountProvider).value, 2);
    },
  );

  test('markedOneRead / markedAllRead drop the badge optimistically', () async {
    final (c, _) = setup([_n('a'), _n('b'), _n('c')]);
    await c.read(unreadCountProvider.future);
    expect(c.read(unreadCountProvider).value, 3);

    c.read(unreadCountProvider.notifier).markedOneRead();
    expect(c.read(unreadCountProvider).value, 2);

    c.read(unreadCountProvider.notifier).markedAllRead();
    expect(c.read(unreadCountProvider).value, 0);

    // never goes negative
    c.read(unreadCountProvider.notifier).markedOneRead();
    expect(c.read(unreadCountProvider).value, 0);
  });
}
