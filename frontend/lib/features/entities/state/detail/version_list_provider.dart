import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/model/code_diff.dart';
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
    return VersionListState(
      versions: page.rows,
      nextCursor: page.next,
      hasMore: page.more,
      // The NEWEST version opens with the tab: «what changed last» is the question the tab exists to
      // answer, and an all-collapsed first paint would answer nothing (首屏自我解释). Every other row
      // is the reader's own click. 最新版本随 tab 打开(本 tab 存在的意义就是回答「最近改了什么」,全收起
      // 的首屏什么也没回答);其余行归读者自己点。
      expanded: page.rows.isEmpty ? const <int>{} : {page.rows.first.version},
    );
  }

  // KeysetScopedPaging hooks — the kind-erased version fetch + this state's cursor/append shape. 分页钩子。
  @override
  ({bool hasMore, bool loadingMore, String? nextCursor}) pageCursor(
    VersionListState s,
  ) => (
    hasMore: s.hasMore,
    loadingMore: s.loadingMore,
    nextCursor: s.nextCursor,
  );

  @override
  Future<({List<VersionRow> rows, String? next, bool more})> fetchNextPage(
    String cursor,
  ) => _fetch(cursor);

  @override
  VersionListState stateWithLoadingMore(VersionListState s, bool loading) =>
      s.copyWith(loadingMore: loading);

  @override
  VersionListState stateWithAppended(
    VersionListState s,
    List<VersionRow> rows,
    String? next,
    bool more,
  ) => s.copyWith(
    versions: [...s.versions, ...rows],
    nextCursor: next,
    hasMore: more,
    loadingMore: false,
  );

  /// `POST :revert` — move the entity's active pointer to [version], then reconcile detail + the
  /// active flags IN PLACE (no self-invalidation → the reader's open cards stay open, and the list is
  /// not snapped back to a fresh page). Re-entry guarded + pending-flagged via
  /// [VersionListState.activatingVersion]; throws on failure (caller toasts) after clearing the flag.
  /// 移 active 指针 → 就地重算 active 标记(不 invalidateSelf,已展开的卡不被合上、列表不回弹);防重入 +
  /// pending 标记;失败清标记后上抛(调用方 toast)。
  Future<void> setActive(int version) async {
    final cur = state.value;
    if (cur == null || cur.activatingVersion != null) {
      return; // re-entry guard 防重入(含双击)
    }
    state = AsyncData(cur.copyWith(activatingVersion: version));
    try {
      await _repo.revertVersion(entityRef.kind, entityRef.id, version);
      ref.invalidate(
        entityDetailProvider(entityRef),
      ); // header badge / hero reconcile from truth
      final now = state.value;
      if (now == null) return;
      // Re-derive active flags on the loaded rows — no refetch, so the open sets + paging survive.
      // 就地重算 active 标记,不重取,开合集与已翻页面保住。
      state = AsyncData(
        now.copyWith(
          versions: [
            for (final r in now.versions)
              r.copyWith(active: r.version == version),
          ],
          activatingVersion: null,
        ),
      );
    } catch (_) {
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(activatingVersion: null));
      rethrow;
    }
  }

  /// Flip one version's diff card open/closed — the accordion's ONE user path (the row body and its ⋯
  /// menu both call it). 翻转一行的 diff 卡(行身与 ⋯ 菜单同走此一条)。
  void toggleExpanded(int version) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      cur.copyWith(
        expanded: cur.expanded.contains(version)
            ? ({...cur.expanded}..remove(version))
            : {...cur.expanded, version},
      ),
    );
  }

  /// Show the WHOLE text of [version] instead of the changed hunks (idempotent). Opening the full text
  /// implies opening the card — the menu entrance must never leave a mode set on a closed row.
  /// 显整份文本(幂等);展开全部即隐含展开该卡——菜单入口绝不给收起的行留下一个看不见的模式。
  void setFullSource(int version, bool full) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      cur.copyWith(
        fullSource: full
            ? {...cur.fullSource, version}
            : ({...cur.fullSource}..remove(version)),
        expanded: full ? {...cur.expanded, version} : cur.expanded,
      ),
    );
  }

  // Line counts per row, computed ONCE per fetched page (never in build — the LCS is real work and a
  // rebuild-time count would re-run it on every accordion toggle). Each row counts against the next
  // OLDER loaded row, exactly the pair the row's diff card renders, so the row's «+N −N» and the card's
  // bar can never disagree. A page-boundary row gets no counts (same degrade as `summary`), and the
  // earliest version legitimately has none. Identical sources skip the diff outright.
  // 逐行行计数,按页只算一次(绝不放 build:LCS 是真开销,放 build 则每次手风琴 toggle 都重跑)。每行与
  // 「下一更旧的已载入行」比——正是该行 diff 卡渲的那一对,故行上计数与卡内 bar 不可能对不上。页边界行无计数
  // (与 summary 同降级),最早版本本就没有。源相同则直接跳过 diff。
  List<VersionRow> _withDiffCounts(List<VersionRow> rows) => [
    for (var i = 0; i < rows.length; i++)
      if (i + 1 >= rows.length)
        rows[i]
      else if (rows[i].src == rows[i + 1].src)
        rows[i].copyWith(added: 0, removed: 0)
      else
        _counted(rows[i], rows[i + 1].src),
  ];

  VersionRow _counted(VersionRow row, String older) {
    var added = 0;
    var removed = 0;
    for (final line in lineDiff(older, row.src)) {
      if (line.op == DiffOp.add) {
        added++;
      } else if (line.op == DiffOp.del) {
        removed++;
      }
    }
    return row.copyWith(added: added, removed: removed);
  }

  Future<({List<VersionRow> rows, String? next, bool more})> _fetch(
    String? cursor,
  ) async {
    final page = await _fetchRaw(cursor);
    return (rows: _withDiffCounts(page.rows), next: page.next, more: page.more);
  }

  Future<({List<VersionRow> rows, String? next, bool more})> _fetchRaw(
    String? cursor,
  ) async {
    final activeId =
        ref.read(entityDetailProvider(entityRef)).value?.activeVersionId ?? '';
    switch (entityRef.kind) {
      case EntityKind.control:
        final p = await _repo.listControlVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
        return (
          rows: [
            for (final v in p.items)
              VersionRow(
                version: v.version,
                active: v.id == activeId,
                createdAt: v.createdAt,
                src: controlVersionSource(v),
                lang: 'json',
                changeReason: v.changeReason,
              ),
          ],
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.approval:
        final p = await _repo.listApprovalVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
        return (
          rows: [
            for (final v in p.items)
              VersionRow(
                version: v.version,
                active: v.id == activeId,
                createdAt: v.createdAt,
                src: approvalVersionSource(v),
                lang: 'json',
                changeReason: v.changeReason,
              ),
          ],
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.trigger:
        return (rows: const <VersionRow>[], next: null, more: false);
      case EntityKind.function:
        final p = await _repo.listFunctionVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
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
                    : const [],
              ),
          ],
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.handler:
        final p = await _repo.listHandlerVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
        return (
          rows: p.items
              .map(
                (v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: handlerSourceOf(v),
                  lang: 'py',
                  changeReason: v.changeReason,
                ),
              )
              .toList(),
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.agent:
        final p = await _repo.listAgentVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
        return (
          rows: p.items
              .map(
                (v) => VersionRow(
                  version: v.version,
                  active: v.id == activeId,
                  createdAt: v.createdAt,
                  src: v.prompt,
                  lang: 'md',
                  changeReason: v.changeReason,
                ),
              )
              .toList(),
          next: p.nextCursor,
          more: p.hasMore,
        );
      case EntityKind.workflow:
        final p = await _repo.listWorkflowVersions(
          entityRef.id,
          cursor: cursor,
          limit: _pageSize,
        );
        return (
          rows: [
            for (var i = 0; i < p.items.length; i++)
              VersionRow(
                version: p.items[i].version,
                active: p.items[i].id == activeId,
                createdAt: p.items[i].createdAt,
                // Pretty-printed: the wire blob is compact one-line JSON, which would LCS-diff as
                // a single opaque line. 美化后 diff 才有行可比(线缆 blob 是单行紧凑 JSON)。
                src: prettyJsonSource(p.items[i].graph),
                lang: 'json',
                changeReason: p.items[i].changeReason,
                // Graph-structural chips vs the next-older loaded row (same page-boundary degrade
                // as function). 图结构小签,页边界行无签(同 function)。
                summary: i + 1 < p.items.length
                    ? workflowVersionSummary(p.items[i], p.items[i + 1])
                    : const [],
              ),
          ],
          next: p.nextCursor,
          more: p.hasMore,
        );
    }
  }
}

/// autoDispose: a sub-resource of the detail (only relevant while viewing the entity) — released on leave.
/// autoDispose:详情的子资源(仅查看时相关),离开即释放。
final versionListProvider = AsyncNotifierProvider.autoDispose
    .family<VersionListNotifier, VersionListState, EntityRef>(
      VersionListNotifier.new,
      retry: (_, _) => null,
    );
