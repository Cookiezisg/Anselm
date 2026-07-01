import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/page.dart';

/// Shared keyset "fetch the next page and append" for an `AsyncNotifier<S>` list. Two variants by how they
/// decide a returned page is STALE and must be dropped — this is the only real difference, so they stay two
/// small explicit mixins rather than one parameterised (and harder-to-read) one:
///
///  - [KeysetQueryPaging] — the list's build() re-runs on a QUERY switch (search / sort / filter) WITHOUT
///    disposing the notifier, so `ref.mounted` stays true over a stale page. It guards with a GENERATION
///    counter that build bumps; a page whose captured gen != the current one is dropped (and its error
///    swallowed — a newer query is already in flight). Used by the entity + conversation rails.
///  - [KeysetScopedPaging] — a detail-scoped autoDispose list (no query axis) whose only hazard is writing
///    after the user left the entity. It guards with `ref.mounted` and, on an error mid-teardown, rethrows
///    WITHOUT touching disposed state. Used by the version + log detail tabs.
///
/// Both hoist the identical guard-clause + loadingMore state-machine + error-keeps-rows behaviour off the
/// notifier via a few thin hooks over its own freezed state (no polymorphic copyWith needed).
///
/// 共享 keyset「取下一页并追加」。两变体只差「如何判定返回页作废」:QueryPaging 用世代计数(build 随查询切换
/// 自增、notifier 不释放故 ref.mounted 仍真);ScopedPaging 用 ref.mounted(详情 autoDispose、无查询轴)。
/// 因只此一处差异、且各自更易读,故并列两个小 mixin、不合成一个带策略参数的。
mixin KeysetQueryPaging<S, R> on AsyncNotifier<S> {
  int _generation = 0;

  /// Call at the top of build() — a query switch re-runs build, invalidating any in-flight [loadMore].
  /// 在 build() 顶部调用——查询切换重跑 build,令在途 loadMore 作废。
  void bumpGeneration() => _generation++;

  // Thin hooks over the notifier's own freezed state (trivial getters / copyWith):
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(S state);
  Future<Page<R>> fetchNextPage(String cursor);
  S stateWithLoadingMore(S state, bool loading);
  S stateWithAppended(S state, Page<R> page);

  /// Fetch the next keyset page and append. No-op while loading, at the end, or before first load; drops the
  /// page if a query switch re-ran build during the await. 取下一 keyset 页并追加;加载中/已到底/首载前 no-op。
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null) return;
    final c = pageCursor(cur);
    if (!c.hasMore || c.loadingMore || c.nextCursor == null) return;
    final gen = _generation; // a query switch re-runs build + bumps _generation mid-await
    state = AsyncData(stateWithLoadingMore(cur, true));
    try {
      final page = await fetchNextPage(c.nextCursor!);
      if (gen != _generation) return; // build re-ran during the await — stale query's page, drop it
      state = AsyncData(stateWithAppended(state.value ?? cur, page));
    } catch (_) {
      // Keep the rows we have, drop the spinner, surface the error (a tail-error affordance is a later
      // slice). 保留已得行、撤 spinner、错误上抛(尾部错误提示后续片)。
      if (gen != _generation) return;
      state = AsyncData(stateWithLoadingMore(state.value ?? cur, false));
      rethrow;
    }
  }
}

mixin KeysetScopedPaging<S, R> on AsyncNotifier<S> {
  // Thin hooks over the notifier's own freezed state. The fetch returns a bare (rows, next, more) chunk so a
  // notifier whose fetch also carries build-only extras (e.g. an aggregate) can drop them here.
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(S state);
  Future<({List<R> rows, String? next, bool more})> fetchNextPage(String cursor);
  S stateWithLoadingMore(S state, bool loading);
  S stateWithAppended(S state, List<R> rows, String? next, bool more);

  /// Fetch the next keyset page and append. No-op while loading, at the end, or before first load; on leave
  /// mid-page (autoDispose) it doesn't write disposed state. 取下一 keyset 页并追加;离开途中不写已释放 state。
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null) return;
    final c = pageCursor(cur);
    if (!c.hasMore || c.loadingMore || c.nextCursor == null) return;
    state = AsyncData(stateWithLoadingMore(cur, true));
    try {
      final page = await fetchNextPage(c.nextCursor!);
      if (!ref.mounted) return; // autoDispose: left the entity mid-page 已离开实体则不写
      state = AsyncData(stateWithAppended(state.value ?? cur, page.rows, page.next, page.more));
    } catch (_) {
      if (!ref.mounted) rethrow; // disposed → don't touch state, just propagate
      state = AsyncData(stateWithLoadingMore(state.value ?? cur, false));
      rethrow;
    }
  }
}
