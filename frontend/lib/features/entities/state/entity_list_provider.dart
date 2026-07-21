import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/page.dart';
import '../../../core/state/keyset_paging.dart';
import '../data/entity_kind.dart';
import '../data/entity_providers.dart';
import '../data/entity_repository.dart';
import '../data/entity_row.dart';
import '../data/entity_signal.dart';
import 'entity_list_state.dart';

/// One kind's rail list — first page on build, [loadMore] appends, and a live SSE subscription patches
/// the durable list in place. The realtime contract (E2): only `durable` (seq>0) signals mutate the
/// list (DB-row-is-truth); ephemeral frames never do. Created → fetch the new row + prepend; deleted →
/// drop by id; edited/updated → refetch that one row + replace; a signal for an id not on the loaded
/// pages is ignored (a later refetch/loadMore reconciles it). Re-reads `state` after every await so
/// concurrent signals don't clobber each other.
///
/// 单 kind 的 rail 列表——build 取首页,loadMore 追加,SSE 订阅就地 patch 耐久列表。E2:仅 durable
/// 信号改列表(DB 行是真相),ephemeral 永不。created→取新行前插 / deleted→按 id 删 / edited·updated→
/// 重取该行替换;不在已载页的 id 忽略。每次 await 后重读 state 防并发互踩。
class EntityListNotifier extends AsyncNotifier<EntityListState>
    with KeysetQueryPaging<EntityListState, EntityRow> {
  EntityListNotifier(this.kind);

  final EntityKind kind;
  late EntityRepository _repo;
  String _search = '';

  // Server applies a default page cap anyway; we request an explicit window so loadMore is exercised.
  // 服务端本就有默认页上限;此处显式请求一窗,使 loadMore 真正生效。
  static const int _pageSize = 20;

  @override
  Future<EntityListState> build() async {
    bumpGeneration();
    _repo = ref.watch(entityRepositoryProvider);
    _search = ref.watch(entitySearchProvider);
    final sub = _repo.lifecycleSignals(kind).listen(_onSignal);
    ref.onDispose(sub.cancel);
    final page = await _repo.listEntities(
      kind,
      limit: _pageSize,
      search: _search.isEmpty ? null : _search,
    );
    return EntityListState(
      rows: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  // KeysetQueryPaging hooks — the per-kind fetch + this state's cursor/append shape. 分页 mixin 钩子。
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(
    EntityListState s,
  ) => (
    hasMore: s.hasMore,
    loadingMore: s.loadingMore,
    nextCursor: s.nextCursor,
  );

  @override
  Future<Page<EntityRow>> fetchNextPage(String cursor) => _repo.listEntities(
    kind,
    cursor: cursor,
    limit: _pageSize,
    search: _search.isEmpty ? null : _search,
  );

  @override
  EntityListState stateWithLoadingMore(EntityListState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  EntityListState stateWithAppended(EntityListState s, Page<EntityRow> page) =>
      s.copyWith(
        rows: [...s.rows, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      );

  Future<void> _onSignal(EntitySignal s) async {
    if (!s.durable) return; // ephemeral never touches the durable list
    final cur = state.value;
    if (cur == null) return;
    switch (s.action) {
      case EntityAction.deleted:
        _setRows(cur.rows.where((r) => r.id != s.id).toList());
      case EntityAction.created:
        if (cur.rows.any((r) => r.id == s.id)) return; // dedup
        final row = await _row(s.id);
        if (row == null) return;
        final now = state.value;
        if (now != null && !now.rows.any((r) => r.id == s.id)) {
          _setRows([row, ...now.rows]);
        }
      case EntityAction.edited:
      case EntityAction.updated:
      case EntityAction.unknown:
        if (!cur.rows.any((r) => r.id == s.id)) {
          return; // not on loaded pages → ignore
        }
        final row = await _row(s.id);
        if (row == null) return;
        final now = state.value;
        if (now != null) {
          _setRows([
            for (final r in now.rows)
              if (r.id == s.id) row else r,
          ]);
        }
    }
  }

  void _setRows(List<EntityRow> rows) {
    final base = state.value;
    if (base != null) state = AsyncData(base.copyWith(rows: rows));
  }

  Future<EntityRow?> _row(String id) async {
    try {
      return await _repo.getEntityRow(kind, id);
    } catch (_) {
      return null; // entity vanished between signal and fetch — let the list be
    }
  }
}

/// The rail's search query — a rail-level (not per-kind) transient view state; every kind's list notifier
/// watches it and re-pages from the top when it changes (server-side `?search`, same cursor-reset rule as
/// a sort switch). One search box filters all 4 kind sections. `set` trims + no-ops on no change; keystroke
/// debouncing lives at the search-box input edge, so this provider updates immediately and stays testable.
///
/// rail 搜索词——rail 级(非 per-kind)瞬时视图态;每个 kind 的 list notifier watch 它、变即从顶重翻(服务端 `?search`,
/// 与切 sort 同样的游标重置)。一个搜索框过滤全部 4 kind 段。`set` trim + 无变化 no-op;逐键防抖在搜索框输入边、保持易测。
class EntitySearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) {
    final q = query.trim();
    if (q != state) state = q;
  }
}

final entitySearchProvider = NotifierProvider<EntitySearchController, String>(
  EntitySearchController.new,
);

/// Per-kind rail list (family over [EntityKind]). Auto-retry is disabled — recovery is the rail's
/// explicit retry button (Riverpod's default exponential auto-retry would otherwise oscillate the
/// failed list back into a loading spinner, hiding the error state). 每 kind 的 rail 列表;关自动重试
/// (恢复交给 rail 的重试钮,否则默认指数重试会把错误态闪回 loading)。
final entityListProvider =
    AsyncNotifierProvider.family<
      EntityListNotifier,
      EntityListState,
      EntityKind
    >(EntityListNotifier.new, retry: (_, _) => null);
