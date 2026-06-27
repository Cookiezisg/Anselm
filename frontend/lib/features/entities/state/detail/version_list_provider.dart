import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class VersionListNotifier extends AsyncNotifier<VersionListState> {
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

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore || cur.nextCursor == null) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _fetch(cur.nextCursor);
      if (!ref.mounted) return; // autoDispose: left the entity mid-page 已离开实体则不写
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(
        versions: [...now.versions, ...page.rows],
        nextCursor: page.next,
        hasMore: page.more,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) rethrow; // disposed → don't touch state, just propagate
      final now = state.value ?? cur;
      state = AsyncData(now.copyWith(loadingMore: false));
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
          rows: p.items
              .map((v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: v.code,
                  lang: 'py',
                  changeReason: v.changeReason))
              .toList(),
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
