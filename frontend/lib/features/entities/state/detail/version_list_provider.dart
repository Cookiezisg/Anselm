import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/keyset_paging.dart';
import '../../data/entity_format.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_providers.dart';
import '../../data/entity_repository.dart';
import '../selected_entity.dart';
import 'entity_detail.dart';
import 'entity_detail_provider.dart';
import 'version_list_state.dart';

/// The versions tab (family over [EntityRef]). Pages the kind's append-only version history into
/// kind-erased [VersionRow]s (so the diff widget is kind-agnostic), flags the active version against the
/// detail's `activeVersionId`, and tracks the selected row for the diff. Same paging discipline as the
/// rail list (loadMore keeps rows on error; re-read state after await; auto-retry off). The detail
/// provider invalidates this on edit so a new active version reconciles. 版本 tab(按 EntityRef family)。
class VersionListNotifier extends AsyncNotifier<VersionListState>
    with KeysetScopedPaging<VersionListState, VersionRow> {
  VersionListNotifier(this.entityRef);

  final EntityRef entityRef;
  late EntityRepository _repo;
  static const int _pageSize = 20;

  @override
  Future<VersionListState> build() async {
    _repo = ref.watch(entityRepositoryProvider);
    final page = await _fetch(null);
    return VersionListState(versions: page.rows, nextCursor: page.next, hasMore: page.more);
  }

  // KeysetScopedPaging hooks — the kind-erased version fetch + this state's cursor/append shape. 分页钩子。
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(VersionListState s) =>
      (hasMore: s.hasMore, loadingMore: s.loadingMore, nextCursor: s.nextCursor);

  @override
  Future<({List<VersionRow> rows, String? next, bool more})> fetchNextPage(String cursor) => _fetch(cursor);

  @override
  VersionListState stateWithLoadingMore(VersionListState s, bool loading) => s.copyWith(loadingMore: loading);

  @override
  VersionListState stateWithAppended(VersionListState s, List<VersionRow> rows, String? next, bool more) =>
      s.copyWith(versions: [...s.versions, ...rows], nextCursor: next, hasMore: more, loadingMore: false);

  /// `POST :revert` — move the entity's active pointer to [version], then reconcile detail + the
  /// active flags IN PLACE (no self-invalidation → the user's selected row is preserved, not snapped
  /// back to newest). Re-entry guarded + pending-flagged via [VersionListState.activatingVersion];
  /// throws on failure (caller toasts) after clearing the flag. 移 active 指针 → 就地重算 active 标记
  /// (不 invalidateSelf,选区不回弹到最新);防重入 + pending 标记;失败清标记后上抛(调用方 toast)。
  Future<void> setActive(int version) async {
    final cur = state.value;
    if (cur == null || cur.activatingVersion != null) return; // re-entry guard 防重入(含双击)
    state = AsyncData(cur.copyWith(activatingVersion: version));
    try {
      await _repo.revertVersion(entityRef.kind, entityRef.id, version);
      ref.invalidate(entityDetailProvider(entityRef)); // header badge / hero reconcile from truth
      final now = state.value;
      if (now == null) return;
      // Re-derive active flags on the loaded rows — no refetch, so selectedIndex + paging survive.
      // 就地重算 active 标记,不重取,选区与已翻页面保住。
      state = AsyncData(now.copyWith(
        versions: [for (final r in now.versions) r.copyWith(active: r.version == version)],
        activatingVersion: null,
      ));
    } catch (_) {
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(activatingVersion: null));
      rethrow;
    }
  }

  /// Pick the version to show on the diff's `after` side (compared against the next-older loaded row).
  /// 选 diff 的 after 版本(与下一更旧版本比)。
  void select(int index) {
    final cur = state.value;
    if (cur == null || index < 0 || index >= cur.versions.length) return;
    state = AsyncData(cur.copyWith(selectedIndex: index));
  }

  Future<({List<VersionRow> rows, String? next, bool more})> _fetch(String? cursor) async {
    final activeId = ref.read(entityDetailProvider(entityRef)).value?.activeVersionId ?? '';
    switch (entityRef.kind) {
      case EntityKind.function:
        final p = await _repo.listFunctionVersions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (
          rows: [
            for (var i = 0; i < p.items.length; i++)
              VersionRow(
                  version: p.items[i].version,
                  active: p.items[i].id == activeId,
                  createdAt: p.items[i].createdAt,
                  src: p.items[i].code,
                  lang: 'py',
                  changeReason: p.items[i].changeReason,
                  // Newest-first page: the next-older neighbour is i+1 (a page-boundary row simply
                  // gets no chips — acceptable degrade). 页内相邻即上一版;跨页边界行无签,可接受。
                  summary: i + 1 < p.items.length
                      ? functionVersionSummary(p.items[i], p.items[i + 1])
                      : const []),
          ],
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.handler:
        final p = await _repo.listHandlerVersions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (
          rows: p.items
              .map((v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: handlerSourceOf(v),
                  lang: 'py',
                  changeReason: v.changeReason))
              .toList(),
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.agent:
        final p = await _repo.listAgentVersions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (
          rows: p.items
              .map((v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: v.prompt,
                  lang: 'md',
                  changeReason: v.changeReason))
              .toList(),
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.workflow:
        final p = await _repo.listWorkflowVersions(entityRef.id, cursor: cursor, limit: _pageSize);
        return (
          rows: p.items
              .map((v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: v.graph,
                  lang: 'json',
                  changeReason: v.changeReason))
              .toList(),
          next: p.nextCursor,
          more: p.hasMore,
        );
    }
  }
}

/// autoDispose: a sub-resource of the detail (only relevant while viewing the entity) — released on leave.
/// autoDispose:详情的子资源(仅查看时相关),离开即释放。
final versionListProvider =
    AsyncNotifierProvider.autoDispose.family<VersionListNotifier, VersionListState, EntityRef>(
  VersionListNotifier.new,
  retry: (_, _) => null,
);
