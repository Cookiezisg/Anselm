import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
import 'package:anselm/features/chat/state/conversation_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 2 gate — the conversation list notifier: first page on build, loadMore appends the next keyset
// page (no dup/miss), and switching sort / toggling show-archived re-pages from the top (the watched
// query providers re-run build → fresh first page, which is the cursor-reset-on-switch rule).

DateTime _at(int hour) => DateTime.utc(2026, 6, 26, hour);

Conversation _c(String id, String title, {bool pinned = false, bool archived = false, int hour = 12}) =>
    Conversation(
      id: id,
      title: title,
      pinned: pinned,
      archived: archived,
      createdAt: _at(hour),
      updatedAt: _at(hour),
      lastMessageAt: _at(hour),
    );

ProviderContainer _container(FixtureChatRepository repo) {
  final c = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  // Keep the list provider alive across dependency changes (mirrors a mounted rail widget).
  c.listen(conversationListProvider, (_, _) {});
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('build loads the first page (activity order, recency desc)', () async {
    final c = _container(FixtureChatRepository(conversations: [
      _c('cv_a', 'A', hour: 9),
      _c('cv_b', 'B', hour: 11),
    ]));
    final s = await c.read(conversationListProvider.future);
    expect(s.rows.map((r) => r.id), ['cv_b', 'cv_a']);
    expect(s.hasMore, false);
  });

  test('loadMore appends the next keyset page (no dup/miss)', () async {
    final many = [for (var i = 0; i < 35; i++) _c('cv_${i.toString().padLeft(2, '0')}', 't$i', hour: i % 23)];
    final c = _container(FixtureChatRepository(conversations: many));
    final s1 = await c.read(conversationListProvider.future);
    expect(s1.rows.length, 30); // _pageSize
    expect(s1.hasMore, true);

    await c.read(conversationListProvider.notifier).loadMore();
    final s2 = c.read(conversationListProvider).value!;
    expect(s2.rows.length, 35);
    expect(s2.hasMore, false);
    expect(s2.rows.map((r) => r.id).toSet().length, 35); // every id once — no dup, no miss

    // loadMore at the end is a no-op.
    await c.read(conversationListProvider.notifier).loadMore();
    expect(c.read(conversationListProvider).value!.rows.length, 35);
  });

  test('switching sort re-pages from the top with the new order', () async {
    final c = _container(FixtureChatRepository(conversations: [
      _c('cv_a', 'Apple', hour: 9),
      _c('cv_c', 'Cherry', hour: 11),
      _c('cv_b', 'banana', hour: 8),
    ]));
    final activity = await c.read(conversationListProvider.future);
    expect(activity.rows.map((r) => r.id), ['cv_c', 'cv_a', 'cv_b']); // recency desc: 11,9,8

    c.read(conversationSortProvider.notifier).set(ConvSort.name);
    final byName = await c.read(conversationListProvider.future);
    expect(byName.rows.map((r) => r.id), ['cv_a', 'cv_b', 'cv_c']); // NOCASE A–Z: Apple, banana, Cherry
  });

  test('toggling showArchived re-pages to include archived rows', () async {
    final c = _container(FixtureChatRepository(conversations: [
      _c('cv_a', 'A', hour: 9),
      _c('cv_x', 'X', archived: true, hour: 8),
    ]));
    final active = await c.read(conversationListProvider.future);
    expect(active.rows.map((r) => r.id), ['cv_a']); // archived excluded by default

    c.read(showArchivedProvider.notifier).toggle();
    final all = await c.read(conversationListProvider.future);
    expect(all.rows.map((r) => r.id).toSet(), {'cv_a', 'cv_x'});
  });
}
