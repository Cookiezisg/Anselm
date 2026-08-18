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
/// drop by id; edited/updated → refetch that one row + replace; lifecycle signals also refresh the
/// exact filtered total from the same endpoint metadata, so badges do not drift behind the DB. A signal
/// for an id not on the loaded pages is ignored for rows (a later refetch/loadMore reconciles it), but
/// its count is still refreshed. Re-reads `state` after every await so concurrent signals don't clobber
/// each other.
///
/// 单 kind 的 rail 列表——build 取首页,loadMore 追加,SSE 订阅就地 patch 耐久列表。E2:仅 durable
/// 信号改列表(DB 行是真相),ephemeral 永不。created→取新行前插 / deleted→按 id 删 / edited·updated→
/// 重取该行替换;生命周期信号同时从同一端点元数据刷新精确过滤总数,徽标不落后于 DB。未在已载页的
/// id 行投影仍忽略(后续重翻/翻页收敛),但计数照样刷新。每次 await 后重读 state 防并发互踩。
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
    // The same stream's 410: signals in the gap are gone for good, so re-page rather than keep a list
    // that quietly stopped tracking creates/renames/deletes (WRK-083 L7). 同流 410:缺口里的信号永远没了,
    // 故重翻整列,而不是留着一个悄悄不再跟踪增删改名的列表。
    final resyncSub = _repo.lifecycleResync().listen(
      (_) => ref.invalidateSelf(),
    );
    ref.onDispose(resyncSub.cancel);
    if (kind == EntityKind.trigger) {
      // Trigger `listening` is read-derived from active workflow bindings. A workflow lifecycle
      // change therefore invalidates the trigger rail even though no trigger row was edited.
      // trigger 的 listening 从 active workflow 绑定读时派生；workflow 生命周期变化虽未编辑 trigger 行，仍须刷新 rail。
      final workflowLife = _repo.lifecycleSignals(EntityKind.workflow).listen((
        s,
      ) {
        if (s.durable) ref.invalidateSelf();
      });
      ref.onDispose(workflowLife.cancel);
    }
    final page = await _repo.listEntities(
      kind,
      limit: _pageSize,
      search: _search.isEmpty ? null : _search,
    );
    return EntityListState(
      rows: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      totalCount: page.total ?? (page.hasMore ? null : page.items.length),
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
        totalCount:
            page.total ??
            (page.hasMore ? s.totalCount : s.rows.length + page.items.length),
      );

  Future<void> _onSignal(EntitySignal s) async {
    if (!s.durable) return; // ephemeral never touches the durable list
    final cur = state.value;
    if (cur == null) return;
    switch (s.action) {
      case EntityAction.deleted:
        _setRows(cur.rows.where((r) => r.id != s.id).toList());
        await _refreshTotalCount();
      case EntityAction.created:
        if (cur.rows.any((r) => r.id == s.id)) return; // dedup
        final row = await _row(s.id);
        final now = state.value;
        if (row != null && now != null && !now.rows.any((r) => r.id == s.id)) {
          _setRows([row, ...now.rows]);
        }
        await _refreshTotalCount();
      case EntityAction.edited:
      case EntityAction.updated:
      case EntityAction.unknown:
        if (!cur.rows.any((r) => r.id == s.id)) {
          await _refreshTotalCount();
          return; // not on loaded pages → ignore the row, but not its count
        }
        final row = await _row(s.id);
        if (row == null) {
          _setRows(cur.rows.where((r) => r.id != s.id).toList());
          await _refreshTotalCount();
          return;
        }
        final now = state.value;
        if (now != null) {
          final matchesSearch =
              _search.isEmpty ||
              row.name.toLowerCase().contains(_search.toLowerCase());
          _setRows([
            for (final r in now.rows)
              if (r.id == s.id && matchesSearch) row else if (r.id != s.id) r,
          ]);
        }
        await _refreshTotalCount();
    }
  }

  void _setRows(List<EntityRow> rows) {
    final base = state.value;
    if (base != null) state = AsyncData(base.copyWith(rows: rows));
  }

  Future<void> _refreshTotalCount() async {
    final search = _search;
    try {
      final page = await _repo.listEntities(
        kind,
        limit: 1,
        search: search.isEmpty ? null : search,
      );
      final total = page.total;
      if (total == null || search != _search) return;
      final base = state.value;
      if (base != null) state = AsyncData(base.copyWith(totalCount: total));
    } catch (_) {
      // A realtime count refresh is best effort; retain the last known exact value on transport error.
    }
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
