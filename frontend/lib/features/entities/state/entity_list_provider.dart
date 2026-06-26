import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class EntityListNotifier extends AsyncNotifier<EntityListState> {
  EntityListNotifier(this.kind);

  final EntityKind kind;
  late EntityRepository _repo;

  // Server applies a default page cap anyway; we request an explicit window so loadMore is exercised.
  // 服务端本就有默认页上限;此处显式请求一窗,使 loadMore 真正生效。
  static const int _pageSize = 20;

  @override
  Future<EntityListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final sub = _repo.lifecycleSignals(kind).listen(_onSignal);
    ref.onDispose(sub.cancel);
    final page = await _repo.listEntities(kind, limit: _pageSize);
    return EntityListState(rows: page.items, nextCursor: page.nextCursor, hasMore: page.hasMore);
  }

  /// Fetch the next keyset page and append. No-op while loading, at the end, or before first load.
  /// 取下一 keyset 页并追加;加载中/已到底/首载前为 no-op。
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore || cur.nextCursor == null) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _repo.listEntities(kind, cursor: cur.nextCursor, limit: _pageSize);
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(
        rows: [...now.rows, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep the rows we have, drop the spinner, surface the error to the caller (a tail-error
      // indicator in the rail is a STEP 3/5 concern). 保留已得行、撤 spinner、错误上抛(尾部错误提示后续步)。
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(loadingMore: false));
      rethrow;
    }
  }

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
        if (now != null && !now.rows.any((r) => r.id == s.id)) _setRows([row, ...now.rows]);
      case EntityAction.edited:
      case EntityAction.updated:
      case EntityAction.unknown:
        if (!cur.rows.any((r) => r.id == s.id)) return; // not on loaded pages → ignore
        final row = await _row(s.id);
        if (row == null) return;
        final now = state.value;
        if (now != null) {
          _setRows([for (final r in now.rows) if (r.id == s.id) row else r]);
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

/// Per-kind rail list (family over [EntityKind]). 每 kind 的 rail 列表(按 EntityKind family)。
final entityListProvider =
    AsyncNotifierProvider.family<EntityListNotifier, EntityListState, EntityKind>(
  EntityListNotifier.new,
);
