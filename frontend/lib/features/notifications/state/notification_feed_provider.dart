import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/notification.dart';
import '../../../core/contract/page.dart';
import '../../../core/state/keyset_paging.dart';
import '../data/notification_providers.dart';
import '../data/notification_repository.dart';
import 'notification_feed_state.dart';
import 'unread_count_provider.dart';

/// The notification-center feed: a keyset-paginated, newest-first list of inbox rows the tray renders.
/// Live: a durable inbox-worthy tick debounce-refetches the FIRST page and merges any new rows to the
/// front (the DB list is truth — we never fabricate a row off a frame, mirroring the unread badge); a 410
/// resync re-pages the whole feed. Mark-read is optimistic (readAt stamped in place + the badge dropped)
/// then reconciled by the repo write.
///
/// 通知中心 feed:keyset 分页、最新优先的收件箱行,托盘渲染。实时:inbox-worthy durable tick 去抖重取**首页**
/// 并把新行并到最前(DB list 是真相,绝不据帧伪造行——同未读徽标);410 整 feed 重翻。mark-read 乐观
/// (就地盖 readAt + 扣徽标)再由 repo 写对账。
class NotificationFeedNotifier extends AsyncNotifier<NotificationFeedState>
    with KeysetQueryPaging<NotificationFeedState, NotificationItem> {
  late NotificationRepository _repo;
  Timer? _debounce;

  static const int _pageSize = 40;

  @override
  Future<NotificationFeedState> build() async {
    bumpGeneration();
    _repo = ref.watch(notificationRepositoryProvider);
    final debounce = ref.watch(notificationDebounceProvider);

    final sigSub = _repo.signals().listen((s) {
      if (s.durable && s.inboxCandidate) {
        _debounce?.cancel();
        _debounce = Timer(debounce, _mergeNewHead);
      }
    });
    final resyncSub = _repo.resync().listen((_) => ref.invalidateSelf());
    ref.onDispose(() {
      _debounce?.cancel();
      sigSub.cancel();
      resyncSub.cancel();
    });

    final page = await _repo.listNotifications(limit: _pageSize);
    return NotificationFeedState(rows: page.items, nextCursor: page.nextCursor, hasMore: page.hasMore);
  }

  // KeysetQueryPaging hooks. 钩子。
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(NotificationFeedState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);

  @override
  Future<Page<NotificationItem>> fetchNextPage(String cursor) =>
      _repo.listNotifications(cursor: cursor, limit: _pageSize);

  @override
  NotificationFeedState stateWithLoadingMore(NotificationFeedState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  NotificationFeedState stateWithAppended(NotificationFeedState s, Page<NotificationItem> page) => s.copyWith(
        rows: [...s.rows, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );

  /// Refetch the first page and prepend any rows not already held (a burst of ticks coalesces to one
  /// COUNT + one page). The DB list is truth; existing rows keep their (possibly locally-marked-read)
  /// state. 重取首页,前插未持有的新行(一簇 tick 合并成一次);DB list 是真相,已持有行保留本地态。
  Future<void> _mergeNewHead() async {
    final cur = state.value;
    if (cur == null) return;
    try {
      final page = await _repo.listNotifications(limit: _pageSize);
      if (!ref.mounted) return;
      final have = {for (final r in cur.rows) r.id};
      final fresh = page.items.where((r) => !have.contains(r.id)).toList(growable: false);
      if (fresh.isEmpty) return;
      state = AsyncData(cur.copyWith(rows: [...fresh, ...cur.rows]));
    } catch (_) {
      // Transient read error — the next tick reconciles. 瞬时读错,下次 tick 对账。
    }
  }

  /// Mark one row read: optimistically stamp readAt + drop the badge, then persist (mark-read has no SSE
  /// echo, so the initiator updates its own state). 标一条已读:乐观盖 readAt + 扣徽标,再持久化。
  Future<void> markRead(String id) async {
    _patchRead((r) => r.id == id);
    ref.read(unreadCountProvider.notifier).markedOneRead();
    try {
      await _repo.markRead(id);
    } catch (_) {
      // The row stays optimistically read; a resync/refetch reconciles if the write truly failed. 乐观保留。
    }
  }

  /// Mark every row within [window] read (the tray passes a time-group's window; default = whole ledger).
  /// Optimistically stamps readAt on the in-window rows. The badge: for the WHOLE ledger the post-count is a
  /// known constant (0) so it zeros optimistically; for a WINDOW the ledger may still hold unread rows
  /// OUTSIDE it (and beyond the loaded page), so the count is NOT known — it refetches the authoritative
  /// COUNT (N0), never optimistically zeroing a badge that shouldn't reach 0.
  /// 标窗口内行已读(托盘传时间组窗口,默认整本账):乐观盖 readAt。徽标:整本账后计数=0(乐观归零);窗口外可能仍有
  /// 未读(且超出已载页),计数非已知常量→**重取权威 COUNT**(N0)、绝不把不该归零的徽标归零。
  Future<void> markAllRead({MarkWindow window = MarkWindow.all}) async {
    _patchRead((r) => window.contains(r.createdAt));
    if (window.isAll) ref.read(unreadCountProvider.notifier).markedAllRead();
    try {
      await _repo.markAllRead(window: window);
    } catch (_) {}
    if (!window.isAll) await ref.read(unreadCountProvider.notifier).refresh();
  }

  /// Mark every row within [window] UNREAD — the mirror of [markAllRead]. Optimistically clears readAt on the
  /// loaded in-window rows, then REFETCHES the authoritative unread-count (N0): the post-state count is NOT a
  /// known constant — the ledger's total may exceed the loaded window (and a window leaves rows outside it
  /// read), so the badge can only be reconciled by re-reading the authoritative COUNT, never fabricated.
  /// 标窗口内行未读——markAllRead 的镜像:乐观清窗口内本地行 readAt,再**重取权威 unread-count**(N0)——未读数非已知常量,只能重读对账。
  Future<void> markAllUnread({MarkWindow window = MarkWindow.all}) async {
    _patchUnread((r) => window.contains(r.createdAt));
    try {
      await _repo.markAllUnread(window: window);
    } catch (_) {}
    await ref.read(unreadCountProvider.notifier).refresh();
  }

  void _patchRead(bool Function(NotificationItem) match) {
    final cur = state.value;
    if (cur == null) return;
    final stamp = DateTime.now();
    final rows = [
      for (final r in cur.rows) (r.isUnread && match(r)) ? r.copyWith(readAt: stamp) : r,
    ];
    state = AsyncData(cur.copyWith(rows: rows));
  }

  void _patchUnread(bool Function(NotificationItem) match) {
    final cur = state.value;
    if (cur == null) return;
    final rows = [
      for (final r in cur.rows) (!r.isUnread && match(r)) ? r.copyWith(readAt: null) : r,
    ];
    state = AsyncData(cur.copyWith(rows: rows));
  }
}

/// The notification feed. keepAlive (app-lifetime — the tray may open/close often; the feed stays warm).
/// 通知 feed。默认 keepAlive(托盘频繁开合、feed 常驻)。
final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedNotifier, NotificationFeedState>(NotificationFeedNotifier.new);
