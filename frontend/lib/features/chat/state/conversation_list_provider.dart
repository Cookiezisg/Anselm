import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import 'conversation_list_state.dart';

/// The conversation list sort — a transient view preference (activity / created / name), held in its
/// own provider so the list notifier can `watch` it and re-page from the top whenever it changes (a
/// keyset cursor is meaningless across sorts, so switching MUST reset pagination — `build` re-running
/// gives that for free). Drives the rail's ⚙ sort menu.
///
/// 对话列表排序——瞬时视图偏好(activity/created/name),独立 provider,使 list notifier 可 watch 它、变即从顶重翻
/// (跨 sort 游标无意义,切换必须重置分页——build 重跑天然给到)。驱动 rail 的 ⚙ 排序菜单。
class ConversationSortController extends Notifier<ConvSort> {
  @override
  ConvSort build() => ConvSort.activity;

  void set(ConvSort sort) {
    if (sort != state) state = sort;
  }
}

final conversationSortProvider =
    NotifierProvider<ConversationSortController, ConvSort>(ConversationSortController.new);

/// Whether the rail shows archived threads too — the ⚙ "show archived" toggle. false → active-only
/// (ConvArchive.active); true → active + archived together (ConvArchive.all, archived rows carrying
/// archived=true for the gray dot). Watched by the list notifier (toggling re-pages from the top).
///
/// rail 是否也显归档——⚙「显示已归档」开关。false → 仅活跃;true → 活跃+归档同列(归档行带 archived=true 供灰点)。
/// 被 list notifier watch(切换即从顶重翻)。
class ShowArchivedController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) {
    if (value != state) state = value;
  }
}

final showArchivedProvider =
    NotifierProvider<ShowArchivedController, bool>(ShowArchivedController.new);

/// The conversation rail list — first page on build, [loadMore] appends the next keyset page. It
/// `watch`es the sort + show-archived providers, so changing either re-runs build → a fresh first page
/// from the top (the cursor-reset-on-sort-switch rule, free). Realtime list mutation (the SSE merge)
/// lands in the live-wiring slice; this slice is pagination + query params only. Auto-retry is disabled
/// so a failed load surfaces the rail's explicit retry instead of oscillating back into a spinner.
///
/// 对话 rail 列表——build 取首页,loadMore 追加下一 keyset 页。它 watch sort + 显示归档 provider,故改任一即重跑
/// build → 从顶取新首页(切换排序自动重置游标)。实时列表 patch(SSE 合并)在 live-wiring 片落;本片只分页 + 查询参。
/// 关自动重试(失败交给 rail 的重试钮,否则闪回 spinner)。
class ConversationListNotifier extends AsyncNotifier<ConversationListState> {
  late ChatRepository _repo;
  ConvSort _sort = ConvSort.activity;
  ConvArchive _archive = ConvArchive.active;

  // The server caps pages anyway; we request an explicit window so loadMore is exercised.
  // 服务端本就有页上限;此处显式请求一窗,使 loadMore 真正生效。
  static const int _pageSize = 30;

  @override
  Future<ConversationListState> build() async {
    _repo = ref.watch(chatRepositoryProvider);
    _sort = ref.watch(conversationSortProvider);
    _archive = ref.watch(showArchivedProvider) ? ConvArchive.all : ConvArchive.active;
    final page = await _repo.listConversations(limit: _pageSize, sort: _sort, archive: _archive);
    return ConversationListState(
        rows: page.items, nextCursor: page.nextCursor, hasMore: page.hasMore);
  }

  /// Fetch the next keyset page and append. No-op while loading, at the end, or before first load.
  /// 取下一 keyset 页并追加;加载中/已到底/首载前为 no-op。
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore || cur.nextCursor == null) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _repo.listConversations(
          cursor: cur.nextCursor, limit: _pageSize, sort: _sort, archive: _archive);
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(
        rows: [...now.rows, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep the rows we have, drop the spinner, surface the error (a tail-error affordance is a later
      // slice). 保留已得行、撤 spinner、错误上抛(尾部错误提示后续片)。
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

final conversationListProvider =
    AsyncNotifierProvider<ConversationListNotifier, ConversationListState>(
  ConversationListNotifier.new,
  retry: (_, _) => null,
);
