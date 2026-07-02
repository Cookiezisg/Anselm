import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/contract/page.dart';
import '../../../core/state/bool_pref.dart';
import '../../../core/state/keyset_paging.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import '../data/conversation_signal.dart';
import 'conversation_list_state.dart';
import 'title_reveals.dart';

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
final showArchivedProvider =
    NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(false));

/// Whether the rail shows the per-section count (置顶 ··· 1) — the ⚙ "show counts" toggle, default ON.
/// rail 是否显分节计数(置顶···1)——⚙「显示分组计数」开关,默认开。
final showGroupCountProvider =
    NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(true));

/// Whether each row shows its relative-time meta (10 分钟前) — the ⚙ "show time" toggle, default ON.
/// rail 每行是否显相对时间(10 分钟前)——⚙「显示时间」开关,默认开。
final showTimeProvider = NotifierProvider<BoolPrefNotifier, bool>(() => BoolPrefNotifier(true));

/// The conversation rail search query — a transient view state in its own provider so the list notifier
/// can `watch` it and re-page from the top whenever it changes. Server-side `?search`: a keyset cursor
/// minted under one query is meaningless under another, so switching MUST reset pagination — `build`
/// re-running gives that for free, exactly like sort/archived. `set` trims + no-ops on no change;
/// keystroke debouncing lives at the rail's search-box input edge, so this provider updates immediately
/// and stays trivially testable.
///
/// 对话列表搜索词——瞬时视图态,独立 provider,使 list notifier watch 它、变即从顶重翻。服务端 `?search`:一种查询下
/// 铸的游标在另一种下无意义,切换必须重置分页——build 重跑天然给到,与 sort/archived 一致。`set` trim + 无变化 no-op;
/// 逐键防抖在 rail 搜索框输入边,故此 provider 立即更新、保持易测。
class ConversationSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) {
    final q = query.trim();
    if (q != state) state = q;
  }
}

final conversationSearchProvider =
    NotifierProvider<ConversationSearchController, String>(ConversationSearchController.new);

/// The conversation rail list — first page on build, [loadMore] appends the next keyset page. It
/// `watch`es the sort + show-archived providers, so changing either re-runs build → a fresh first page
/// from the top (the cursor-reset-on-sort-switch rule, free). Realtime list mutation (the SSE merge)
/// lands in the live-wiring slice; this slice is pagination + query params only. Auto-retry is disabled
/// so a failed load surfaces the rail's explicit retry instead of oscillating back into a spinner.
///
/// 对话 rail 列表——build 取首页,loadMore 追加下一 keyset 页。它 watch sort + 显示归档 provider,故改任一即重跑
/// build → 从顶取新首页(切换排序自动重置游标)。实时列表 patch(SSE 合并)在 live-wiring 片落;本片只分页 + 查询参。
/// 关自动重试(失败交给 rail 的重试钮,否则闪回 spinner)。
class ConversationListNotifier extends AsyncNotifier<ConversationListState>
    with KeysetQueryPaging<ConversationListState, Conversation> {
  late ChatRepository _repo;
  ConvSort _sort = ConvSort.activity;
  ConvArchive _archive = ConvArchive.active;
  String _search = '';

  // The server caps pages anyway; we request an explicit window so loadMore is exercised.
  // 服务端本就有页上限;此处显式请求一窗,使 loadMore 真正生效。
  static const int _pageSize = 30;

  @override
  Future<ConversationListState> build() async {
    bumpGeneration();
    _repo = ref.watch(chatRepositoryProvider);
    _sort = ref.watch(conversationSortProvider);
    _archive = ref.watch(showArchivedProvider) ? ConvArchive.all : ConvArchive.active;
    _search = ref.watch(conversationSearchProvider);
    // Live lifecycle: the notifications stream reconciles the list for changes this client didn't originate
    // (auto-title after the first message, or another window's create/rename/archive/pin/delete). Re-run on
    // a query switch cancels + re-subscribes (onDispose). 实时生命周期:notifications 流据非自身发起的变更重排。
    final sub = _repo.lifecycleSignals().listen(_onSignal);
    ref.onDispose(sub.cancel);
    final page = await _repo.listConversations(
        limit: _pageSize, sort: _sort, archive: _archive, search: _search.isEmpty ? null : _search);
    return ConversationListState(
        rows: page.items, nextCursor: page.nextCursor, hasMore: page.hasMore);
  }

  // KeysetQueryPaging hooks — the sort/archived/search-scoped fetch + this state's cursor/append shape. 钩子。
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(ConversationListState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);

  @override
  Future<Page<Conversation>> fetchNextPage(String cursor) => _repo.listConversations(
      cursor: cursor, limit: _pageSize, sort: _sort, archive: _archive,
      search: _search.isEmpty ? null : _search);

  @override
  ConversationListState stateWithLoadingMore(ConversationListState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  ConversationListState stateWithAppended(ConversationListState s, Page<Conversation> page) => s.copyWith(
        rows: [...s.rows, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );

  /// Fold an authoritative updated conversation (a PATCH response) into the loaded list: replace the row
  /// in place, or DROP it when it just got archived while the rail isn't showing archived (it leaves the
  /// active list). Pin/unpin needs no move here — the rail model re-buckets by `pinned` on rebuild. This
  /// is the initiator's own path (it has the response); idempotent so a later SSE echo of the same change
  /// (notifications carry no echo suppression) re-applies safely.
  ///
  /// 把权威更新(PATCH 响应)折进列表:就地替换;若刚归档且 rail 不显归档则移出(离开活跃列表)。置顶/取消无需在此搬动
  /// (model 重建时按 pinned 重分组)。这是发起端自己的路径(已有响应);幂等(SSE 回声无抑制,重放安全)。
  void applyUpdate(Conversation c) {
    final cur = state.value;
    if (cur == null) return;
    final rows = [...cur.rows];
    final i = rows.indexWhere((r) => r.id == c.id);
    // A FRESH auto-title (empty→non-empty + autoTitled; a user rename never matches — the renamed row
    // already had a title and rename responses carry autoTitled=false) → queue the one-shot typewriter
    // for the rail row + head. 新自动命名(空→非空 + autoTitled;改名不命中)→ 入打字机队列(rail+头同播)。
    if (i >= 0 && rows[i].title.trim().isEmpty && c.title.trim().isNotEmpty && c.autoTitled) {
      ref.read(titleRevealsProvider.notifier).add(c.id);
    }
    final showArchived = ref.read(showArchivedProvider);
    if (c.archived && !showArchived) {
      if (i < 0) return; // already absent → idempotent no-op 已不在,幂等
      rows.removeAt(i);
    } else if (i >= 0) {
      rows[i] = c;
    } else {
      return; // not in the loaded window (e.g. unarchived into view) — a fresh page brings it 不在已载窗,留给重翻
    }
    state = AsyncData(cur.copyWith(rows: rows));
  }

  /// Drop a (soft-)deleted conversation from the list. Idempotent. 移除已删行;幂等。
  void applyDelete(String id) {
    final cur = state.value;
    if (cur == null || !cur.rows.any((r) => r.id == id)) return;
    state = AsyncData(cur.copyWith(rows: cur.rows.where((r) => r.id != id).toList(growable: false)));
  }

  // Reconcile one lifecycle signal into the loaded list. Only durable frames patch (DB-row-is-truth);
  // deleted drops, created inserts, everything else re-reads that one row. Re-reads `state` after each
  // await (a query switch may have re-paged meanwhile). 据一条生命周期信号重排;仅 durable 生效。
  Future<void> _onSignal(ConversationSignal s) async {
    if (!s.durable || state.value == null) return;
    switch (s.action) {
      case ConversationAction.deleted:
        applyDelete(s.id);
      case ConversationAction.created:
        await _insert(s.id);
      case ConversationAction.updated:
        final c = await _fetch(s.id);
        if (c != null) applyUpdate(c); // replace in place / drop if archived-and-hidden / re-bucket
      case ConversationAction.unknown:
        return;
    }
  }

  // A created thread this client didn't originate (another window, or an AI-edit :iterate) → fetch it and
  // prepend, if visible under the current archive scope and not already loaded. Under activity/created sort
  // a new thread belongs at the top; under name sort it's approximate until the next full page (self-heals).
  // 非自身发起的新对话→取回前插(当前归档范围可见、且未在窗内)。activity/created 新对话本就在顶;name 排序近似、下页自愈。
  Future<void> _insert(String id) async {
    final cur = state.value;
    if (cur == null || cur.rows.any((r) => r.id == id)) return; // dedup
    final c = await _fetch(id);
    if (c == null || (c.archived && _archive == ConvArchive.active)) return; // gone, or not in this scope
    final now = state.value;
    if (now == null || now.rows.any((r) => r.id == id)) return; // re-check after the await
    state = AsyncData(now.copyWith(rows: [c, ...now.rows]));
  }

  Future<Conversation?> _fetch(String id) async {
    try {
      return await _repo.getConversation(id);
    } catch (_) {
      return null; // vanished between signal and fetch — let the list be
    }
  }
}

final conversationListProvider =
    AsyncNotifierProvider<ConversationListNotifier, ConversationListState>(
  ConversationListNotifier.new,
  retry: (_, _) => null,
);
