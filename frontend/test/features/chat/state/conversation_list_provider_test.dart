import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
import 'package:anselm/features/chat/data/conversation_signal.dart';
import 'package:anselm/features/chat/data/turn_signal.dart';
import 'package:anselm/features/chat/state/conversation_list_provider.dart';
import 'package:anselm/features/chat/state/title_reveals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 2 gate — the conversation list notifier: first page on build, loadMore appends the next keyset
// page (no dup/miss), and switching sort / toggling show-archived re-pages from the top (the watched
// query providers re-run build → fresh first page, which is the cursor-reset-on-switch rule).

DateTime _at(int hour) => DateTime.utc(2026, 6, 26, hour);

Conversation _c(
  String id,
  String title, {
  bool pinned = false,
  bool archived = false,
  int hour = 12,
  String workDir = '',
}) => Conversation(
  id: id,
  title: title,
  pinned: pinned,
  archived: archived,
  workDir: workDir,
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
    final c = _container(
      FixtureChatRepository(
        conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
      ),
    );
    final s = await c.read(conversationListProvider.future);
    expect(s.rows.map((r) => r.id), ['cv_b', 'cv_a']);
    expect(s.hasMore, false);
  });

  test('loadMore appends the next keyset page (no dup/miss)', () async {
    final many = [
      for (var i = 0; i < 35; i++)
        _c('cv_${i.toString().padLeft(2, '0')}', 't$i', hour: i % 23),
    ];
    final c = _container(FixtureChatRepository(conversations: many));
    final s1 = await c.read(conversationListProvider.future);
    expect(s1.rows.length, 30); // _pageSize
    expect(s1.hasMore, true);

    await c.read(conversationListProvider.notifier).loadMore();
    final s2 = c.read(conversationListProvider).value!;
    expect(s2.rows.length, 35);
    expect(s2.hasMore, false);
    expect(
      s2.rows.map((r) => r.id).toSet().length,
      35,
    ); // every id once — no dup, no miss

    // loadMore at the end is a no-op.
    await c.read(conversationListProvider.notifier).loadMore();
    expect(c.read(conversationListProvider).value!.rows.length, 35);
  });

  test('switching sort re-pages from the top with the new order', () async {
    final c = _container(
      FixtureChatRepository(
        conversations: [
          _c('cv_a', 'Apple', hour: 9),
          _c('cv_c', 'Cherry', hour: 11),
          _c('cv_b', 'banana', hour: 8),
        ],
      ),
    );
    final activity = await c.read(conversationListProvider.future);
    expect(activity.rows.map((r) => r.id), [
      'cv_c',
      'cv_a',
      'cv_b',
    ]); // recency desc: 11,9,8

    c.read(conversationSortProvider.notifier).set(ConvSort.name);
    final byName = await c.read(conversationListProvider.future);
    expect(byName.rows.map((r) => r.id), [
      'cv_a',
      'cv_b',
      'cv_c',
    ]); // NOCASE A–Z: Apple, banana, Cherry
  });

  test('toggling showArchived re-pages to include archived rows', () async {
    final c = _container(
      FixtureChatRepository(
        conversations: [
          _c('cv_a', 'A', hour: 9),
          _c('cv_x', 'X', archived: true, hour: 8),
        ],
      ),
    );
    final active = await c.read(conversationListProvider.future);
    expect(active.rows.map((r) => r.id), [
      'cv_a',
    ]); // archived excluded by default

    c.read(showArchivedProvider.notifier).toggle();
    final all = await c.read(conversationListProvider.future);
    expect(all.rows.map((r) => r.id).toSet(), {'cv_a', 'cv_x'});
  });

  test(
    'setting search re-pages from the top, filtered by title (case-insensitive)',
    () async {
      final c = _container(
        FixtureChatRepository(
          conversations: [
            _c('cv_a', 'Quarterly report', hour: 9),
            _c('cv_b', 'Random chat', hour: 11),
          ],
        ),
      );
      expect((await c.read(conversationListProvider.future)).rows.length, 2);

      // Uppercase term matches the mixed-case title — server-side ?search is case-insensitive; the watched
      // provider re-runs build → fresh filtered first page (same cursor-reset rule as a sort switch).
      c.read(conversationSearchProvider.notifier).set('REPORT');
      final hit = await c.read(conversationListProvider.future);
      expect(hit.rows.map((r) => r.id), ['cv_a']);

      // Clearing the search restores the full list.
      c.read(conversationSearchProvider.notifier).set('');
      expect((await c.read(conversationListProvider.future)).rows.length, 2);
    },
  );

  test(
    'applyUpdate replaces a row in place (rename, optimistic — no re-fetch)',
    () async {
      final c = _container(
        FixtureChatRepository(
          conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
        ),
      );
      await c.read(conversationListProvider.future);
      c
          .read(conversationListProvider.notifier)
          .applyUpdate(_c('cv_a', 'Renamed', hour: 9));
      final rows = c.read(conversationListProvider).value!.rows;
      expect(rows.length, 2);
      expect(rows.firstWhere((r) => r.id == 'cv_a').title, 'Renamed');
    },
  );

  test(
    'applyUpdate drops a row that just got archived while show-archived is off',
    () async {
      final c = _container(
        FixtureChatRepository(
          conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
        ),
      );
      await c.read(conversationListProvider.future);
      c
          .read(conversationListProvider.notifier)
          .applyUpdate(_c('cv_a', 'A', archived: true, hour: 9));
      expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
        'cv_b',
      ]);
    },
  );

  test(
    'applyUpdate keeps a just-archived row when show-archived is on (gray-dot mode)',
    () async {
      final c = _container(
        FixtureChatRepository(conversations: [_c('cv_a', 'A')]),
      );
      c.read(showArchivedProvider.notifier).set(true);
      await c.read(conversationListProvider.future);
      c
          .read(conversationListProvider.notifier)
          .applyUpdate(_c('cv_a', 'A', archived: true));
      final rows = c.read(conversationListProvider).value!.rows;
      expect(rows.single.archived, true);
    },
  );

  test(
    'a turn pulse debounces into ONE row re-read — the dots flip from the DB row',
    () async {
      final repo = FixtureChatRepository(conversations: [_c('cv_a', 'A')]);
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      expect(
        c.read(conversationListProvider).value!.rows.single.isGenerating,
        isFalse,
      );

      // The turn starts server-side; the burst (echo close + assistant open) sends TWO signals.
      // 服务端回合开始;边界簇发两条信号。
      repo.upsert(
        Conversation(
          id: 'cv_a',
          title: 'A',
          isGenerating: true,
          createdAt: _at(9),
          updatedAt: _at(9),
          lastMessageAt: _at(9),
        ),
      );
      repo.emitTurnSignal('cv_a', TurnSignalKind.turnOpen);
      repo.emitTurnSignal('cv_a', TurnSignalKind.turnOpen);
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      ); // debounce 防抖窗
      expect(
        c.read(conversationListProvider).value!.rows.single.isGenerating,
        isTrue,
      ); // blue on 蓝亮

      // Terminal: generating off, unread on (green). 终态:蓝灭绿亮。
      repo.upsert(
        Conversation(
          id: 'cv_a',
          title: 'A',
          isGenerating: false,
          hasUnread: true,
          createdAt: _at(9),
          updatedAt: _at(9),
          lastMessageAt: _at(9),
        ),
      );
      repo.emitTurnSignal('cv_a', TurnSignalKind.turnClose);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final row = c.read(conversationListProvider).value!.rows.single;
      expect(row.isGenerating, isFalse);
      expect(row.hasUnread, isTrue);
    },
  );

  test(
    'markSeenLocal squashes the green idempotently (the :seen race guard)',
    () async {
      final repo = FixtureChatRepository(
        conversations: [
          Conversation(
            id: 'cv_a',
            title: 'A',
            hasUnread: true,
            createdAt: _at(9),
            updatedAt: _at(9),
            lastMessageAt: _at(9),
          ),
        ],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      final n = c.read(conversationListProvider.notifier);
      n.markSeenLocal('cv_a');
      expect(
        c.read(conversationListProvider).value!.rows.single.hasUnread,
        isFalse,
      );
      n.markSeenLocal('cv_a'); // idempotent 幂等
      n.markSeenLocal('cv_missing'); // absent row no-op 缺行不动
      expect(
        c.read(conversationListProvider).value!.rows.single.hasUnread,
        isFalse,
      );
    },
  );

  test(
    'a pulse for a deleted conversation is silent (the lifecycle signal owns the drop)',
    () async {
      final repo = FixtureChatRepository(conversations: [_c('cv_a', 'A')]);
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      repo.emitTurnSignal(
        'cv_gone',
        TurnSignalKind.turnClose,
      ); // 404 on re-read 重读 404
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        c.read(conversationListProvider).value!.rows,
        hasLength(1),
      ); // untouched 不动
    },
  );

  test(
    'a FRESH auto-title (empty→non-empty + autoTitled) queues the typewriter reveal',
    () async {
      final c = _container(
        FixtureChatRepository(conversations: [_c('cv_a', '')]),
      );
      await c.read(conversationListProvider.future);

      final titled = Conversation(
        id: 'cv_a',
        title: '新标题',
        autoTitled: true,
        createdAt: _at(9),
        updatedAt: _at(9),
        lastMessageAt: _at(9),
      );
      c.read(conversationListProvider.notifier).applyUpdate(titled);
      expect(c.read(titleRevealsProvider), {
        'cv_a',
      }); // queued for the rail + head 入队

      c
          .read(titleRevealsProvider.notifier)
          .remove('cv_a'); // the typewriter finished 播完
      expect(c.read(titleRevealsProvider), isEmpty);
    },
  );

  test(
    'a user rename (autoTitled=false) or an already-titled row never queues a reveal',
    () async {
      final c = _container(
        FixtureChatRepository(
          conversations: [_c('cv_a', ''), _c('cv_b', '有名字')],
        ),
      );
      await c.read(conversationListProvider.future);
      final n = c.read(conversationListProvider.notifier);

      n.applyUpdate(_c('cv_a', '用户手改')); // rename response: autoTitled=false 改名
      n.applyUpdate(
        Conversation(
          id: 'cv_b',
          title: '改了',
          autoTitled: true,
          createdAt: _at(9),
          updatedAt: _at(9),
          lastMessageAt: _at(9),
        ),
      ); // had a title already 已有名
      expect(c.read(titleRevealsProvider), isEmpty);
    },
  );

  test('applyDelete removes the row and is idempotent', () async {
    final c = _container(
      FixtureChatRepository(
        conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
      ),
    );
    await c.read(conversationListProvider.future);
    final n = c.read(conversationListProvider.notifier);
    n.applyDelete('cv_a');
    expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
      'cv_b',
    ]);
    n.applyDelete('cv_a'); // already gone → no-op, no throw
    expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
      'cv_b',
    ]);
  });

  // ── live lifecycle (notifications-stream signal reconciliation) ──
  ConversationSignal sig(
    String id,
    ConversationAction a, {
    bool durable = true,
  }) => ConversationSignal(id: id, action: a, durable: durable);

  test('durable deleted signal drops the row', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    repo.emitSignal(sig('cv_a', ConversationAction.deleted));
    await pumpEventQueue();
    expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
      'cv_b',
    ]);
  });

  test('durable updated signal re-reads that row (auto-title lands)', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a', 'A', hour: 9)],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    repo.upsert(
      _c('cv_a', 'Auto Title', hour: 9),
    ); // server renamed it (auto_titled)
    repo.emitSignal(sig('cv_a', ConversationAction.updated));
    await pumpEventQueue();
    expect(
      c.read(conversationListProvider).value!.rows.single.title,
      'Auto Title',
    );
  });

  test('durable created signal fetches + prepends the new row', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_b', 'B', hour: 11)],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    repo.upsert(
      _c('cv_new', 'Fresh', hour: 23),
    ); // a thread created elsewhere, now fetchable
    repo.emitSignal(sig('cv_new', ConversationAction.created));
    await pumpEventQueue();
    expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
      'cv_new',
      'cv_b',
    ]);
  });

  test('created signal for an already-loaded id is a no-op (dedup)', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a', 'A', hour: 9)],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    repo.emitSignal(sig('cv_a', ConversationAction.created));
    await pumpEventQueue();
    expect(c.read(conversationListProvider).value!.rows.length, 1);
  });

  test('ephemeral signal (durable=false) never patches the list', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    repo.emitSignal(sig('cv_a', ConversationAction.deleted, durable: false));
    await pumpEventQueue();
    expect(c.read(conversationListProvider).value!.rows.length, 2); // untouched
  });

  test(
    'updated signal for an archived thread drops it when show-archived is off',
    () async {
      final repo = FixtureChatRepository(
        conversations: [_c('cv_a', 'A', hour: 9), _c('cv_b', 'B', hour: 11)],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      repo.upsert(
        _c('cv_a', 'A', archived: true, hour: 9),
      ); // archived from another window
      repo.emitSignal(sig('cv_a', ConversationAction.updated));
      await pumpEventQueue();
      expect(c.read(conversationListProvider).value!.rows.map((r) => r.id), [
        'cv_b',
      ]);
    },
  );

  test(
    'M9: a loadMore failure raises the retry flag (no rethrow storm); retry re-arms and succeeds',
    () async {
      // 40 rows → the first page (backend default window) leaves more behind a cursor. 首页留尾。
      final repo = FixtureChatRepository(
        conversations: [
          for (var i = 0; i < 40; i++) _c('cv_$i', 'C$i', hour: i % 24),
        ],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      final ctl = c.read(conversationListProvider.notifier);
      final first = c.read(conversationListProvider).value!;
      expect(first.hasMore, isTrue, reason: 'the tail exists 有尾可翻');

      repo.failNextListConversations = true;
      await ctl
          .loadMore(); // must NOT throw into the void (the old storm) 绝不向虚空抛
      var s = c.read(conversationListProvider).value!;
      expect(
        s.loadMoreFailed,
        isTrue,
        reason: 'failure raises the manual-retry flag 失败置旗',
      );
      expect(s.hasMore, isTrue);
      expect(s.loadingMore, isFalse);

      await ctl
          .loadMore(); // the manual retry: clears the flag and pages on 手动重试:清旗续翻
      s = c.read(conversationListProvider).value!;
      expect(s.loadMoreFailed, isFalse);
      expect(
        s.rows.length,
        greaterThan(first.rows.length),
        reason: 'the next page landed 下一页落地',
      );
    },
  );

  // ── WD1.5 · the four sections, as STATE 四段(状态层) ──

  test(
    'build resolves four sections: Pinned (any residency) · groups · Recents (unmounted only)',
    () async {
      final c = _container(
        FixtureChatRepository(
          conversations: [
            _c('cv_pin', 'pinned in alpha', pinned: true, workDir: '/w/alpha'),
            _c('cv_a1', 'alpha one', workDir: '/w/alpha', hour: 11),
            _c('cv_b1', 'beta one', workDir: '/w/beta', hour: 10),
            _c('cv_home', 'no folder', hour: 9),
          ],
        ),
      );
      final s = await c.read(conversationListProvider.future);
      // Pinned holds every pinned thread whatever its residency; Recents holds ONLY the unmounted ones.
      // 置顶段收所有置顶线程、无论驻地;「最近」只收未挂的。
      expect(s.pinned.rows.map((r) => r.id), ['cv_pin']);
      expect(s.recents.rows.map((r) => r.id), ['cv_home']);
      // The group heads come from the projection, most-recently-active first — NOT from the loaded rows.
      expect(s.groups.map((g) => g.workDir), ['/w/alpha', '/w/beta']);
      expect(
        s.groups.first.activeCount,
        1,
      ); // the pinned member is NOT counted here
      // No group's rows are fetched by build: a folded folder costs nothing, and its first page rides the
      // rail's own tail sentinel. build 不取任何组的行:收起的文件夹零成本,首页走 rail 自己的尾哨兵。
      expect(s.groupAxes, isEmpty);
    },
  );

  test('a group axis pages on its own key, and only when asked', () async {
    final c = _container(
      FixtureChatRepository(
        conversations: [
          for (var i = 0; i < 35; i++)
            _c('cv_a$i', 'alpha $i', workDir: '/w/alpha', hour: 12),
          _c('cv_home', 'no folder'),
        ],
      ),
    );
    await c.read(conversationListProvider.future);
    final n = c.read(conversationListProvider.notifier);

    await n.loadMoreAxis(workDirAxisKey('/w/alpha'));
    var s = c.read(conversationListProvider).value!;
    expect(s.groupAxes['/w/alpha']!.rows.length, 30); // _pageSize
    expect(s.groupAxes['/w/alpha']!.hasMore, isTrue);
    // Recents was untouched by the group's paging — the axes are genuinely separate queries.
    // 「最近」没被组的翻页碰到——各轴是真正分开的查询。
    expect(s.recents.rows.map((r) => r.id), ['cv_home']);

    await n.loadMoreAxis(workDirAxisKey('/w/alpha'));
    s = c.read(conversationListProvider).value!;
    expect(s.groupAxes['/w/alpha']!.rows.length, 35);
    expect(s.groupAxes['/w/alpha']!.hasMore, isFalse);
    expect(
      s.groupAxes['/w/alpha']!.rows.map((r) => r.id).toSet().length,
      35,
    ); // no dup, no miss
  });

  test(
    'pinning MOVES a row from its group to Pinned — never duplicates it',
    () async {
      final repo = FixtureChatRepository(
        conversations: [_c('cv_a1', 'alpha one', workDir: '/w/alpha')],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      final n = c.read(conversationListProvider.notifier);
      await n.loadMoreAxis(workDirAxisKey('/w/alpha'));
      expect(
        c
            .read(conversationListProvider)
            .value!
            .groupAxes['/w/alpha']!
            .rows
            .length,
        1,
      );

      n.applyUpdate(await repo.setPinned('cv_a1', true));
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      ); // the coalesced projection re-read
      final s = c.read(conversationListProvider).value!;
      expect(s.pinned.rows.map((r) => r.id), ['cv_a1']);
      expect(s.groupAxes['/w/alpha']?.rows ?? const [], isEmpty);
      // Its group had only that one unpinned thread, so the group is gone from the projection too.
      // 那个组只有那一条未置顶线程,故它也从投影里消失了。
      expect(s.groups, isEmpty);
      // And it appears exactly once across the whole rail. 而它在整个 rail 上恰好出现一次。
      expect(s.allRows.where((r) => r.id == 'cv_a1').length, 1);
    },
  );

  test('leaving a residency moves the row back to Recents', () async {
    final repo = FixtureChatRepository(
      conversations: [_c('cv_a1', 'alpha one', workDir: '/w/alpha')],
    );
    final c = _container(repo);
    await c.read(conversationListProvider.future);
    final n = c.read(conversationListProvider.notifier);

    n.applyUpdate(await repo.setWorkDir('cv_a1', ''));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final s = c.read(conversationListProvider).value!;
    expect(s.recents.rows.map((r) => r.id), ['cv_a1']);
    expect(s.groups, isEmpty);
  });

  test(
    'an in-place update keeps the row where it is — a dot flip must not reorder the rail',
    () async {
      final repo = FixtureChatRepository(
        conversations: [
          _c('cv_a', 'A', hour: 11),
          _c('cv_b', 'B', hour: 10),
          _c('cv_c', 'C', hour: 9),
        ],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      final n = c.read(conversationListProvider.notifier);

      final middle = c.read(conversationListProvider).value!.rows[1];
      n.applyUpdate(middle.copyWith(isGenerating: true));
      final s = c.read(conversationListProvider).value!;
      expect(s.rows.map((r) => r.id), ['cv_a', 'cv_b', 'cv_c']);
      expect(s.rows[1].isGenerating, isTrue);
    },
  );

  test(
    'a group bulk action drops that group axis and re-asks the projection — one read, not N echoes',
    () async {
      final repo = FixtureChatRepository(
        conversations: [
          _c('cv_a1', 'alpha one', workDir: '/w/alpha'),
          _c('cv_a2', 'alpha two', workDir: '/w/alpha'),
          _c('cv_home', 'no folder'),
        ],
      );
      final c = _container(repo);
      await c.read(conversationListProvider.future);
      final n = c.read(conversationListProvider.notifier);
      await n.loadMoreAxis(workDirAxisKey('/w/alpha'));
      expect(c.read(conversationListProvider).value!.groupAxes, isNotEmpty);

      expect(await repo.deleteWorkDir('/w/alpha'), 2);
      await n.applyWorkDirGroupChanged('/w/alpha');
      final s = c.read(conversationListProvider).value!;
      expect(s.groups, isEmpty);
      expect(s.groupAxes, isEmpty);
      expect(s.recents.rows.map((r) => r.id), ['cv_home']);
      // ONE group request, never a loop of per-row deletes. **一次**组请求、绝不是逐行删除的循环。
      expect(repo.deletedWorkDirs, ['/w/alpha']);
      expect(repo.deletedIds, isEmpty);
    },
  );

  test(
    'SEARCHING replaces the structure: one flat list that reaches into FOLDED folders',
    () async {
      // The hole this closes: a folded folder fetches nothing, so a search that merely narrowed the four
      // sections would answer "no matches" for a thread the user had not already scrolled into view.
      // 它封的洞:收起的文件夹什么都不取,故一次只是收窄那四段的搜索会对用户尚未滚进视野的线程答「没有匹配」。
      final c = _container(
        FixtureChatRepository(
          conversations: [
            _c('cv_deep', 'quarterly report', workDir: '/w/never-opened'),
            _c('cv_pin', 'quarterly pinned', pinned: true, workDir: '/w/alpha'),
            _c('cv_home', 'quarterly homeless'),
            _c('cv_other', 'unrelated chatter'),
          ],
        ),
      );
      await c.read(conversationListProvider.future);
      c.read(conversationSearchProvider.notifier).set('quarterly');
      final s = await c.read(conversationListProvider.future);

      expect(s.searching, isTrue);
      expect(s.groups, isEmpty);
      expect(s.pinned.rows, isEmpty);
      // All three matches, including the one inside a folder whose rows were never fetched, and the pinned
      // one — the result list is residency-blind and pin-blind.
      // 三条匹配全在,包括那条住在从未取过行的文件夹里的、以及那条置顶的——结果列表对驻地盲、对置顶盲。
      expect(s.rows.map((r) => r.id).toSet(), {'cv_deep', 'cv_pin', 'cv_home'});

      // Clearing the query restores the four-section rail. 清掉查询词即恢复四段 rail。
      c.read(conversationSearchProvider.notifier).set('');
      final back = await c.read(conversationListProvider.future);
      expect(back.searching, isFalse);
      // Only ONE group comes back: /w/alpha's single thread is PINNED, and pinned threads are hoisted into
      // the Pinned section and counted in no group — so that residency has no group at all.
      // 只回来**一个**组:/w/alpha 那唯一一条线程是**置顶**的,而置顶线程被提到置顶段、不计入任何组——故那个驻地
      // 根本没有组。
      expect(back.groups.map((g) => g.workDir), ['/w/never-opened']);
      expect(back.pinned.rows.map((r) => r.id), ['cv_pin']);
      expect(back.recents.rows.map((r) => r.id).toSet(), {
        'cv_home',
        'cv_other',
      });
    },
  );
}
