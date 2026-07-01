import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/page.dart';

/// Shared keyset "fetch the next page and append" for a rail list whose `build()` re-runs on a QUERY switch
/// (search / sort / filter). It holds the generation counter that build bumps; [loadMore] captures it before
/// its await and DROPS the returned page if build re-ran meanwhile — else a stale query's page appends onto
/// the new query's list. This state-machine (the epoch guard + the loadingMore flag) is subtle and was
/// copied verbatim across the entity + conversation rails; centralising it keeps the two provably identical.
///
/// [S] = the freezed list state, [R] = the row type. Mix into an `AsyncNotifier<S>`, call [bumpGeneration]
/// at the TOP of build(), and implement the four thin hooks over the state (no polymorphic copyWith needed).
///
/// 共享 keyset「取下一页并追加」——用于 build() 会随查询切换(搜索/排序/过滤)重跑的 rail 列表。持 build 自增的
/// 世代计数;loadMore 在 await 前捕获,若期间 build 重跑则丢弃返回页(否则旧查询页追加进新列表)。这套状态机
/// (epoch 守卫 + loadingMore 标志)微妙且曾在实体/对话两 rail 逐字重抄,收敛于此使两者可证同构。
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
