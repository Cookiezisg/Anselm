import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../data/entity_kind.dart';
import '../data/entity_labels.dart';
import '../state/entity_list_provider.dart';
import '../state/rail_model.dart';
import '../state/rail_sort.dart';
import '../state/selected_entity.dart';
import 'entity_rail_model.dart';

/// The left-island entity navigator. Watches [railModelProvider] (the 4 kinds' live list states) +
/// [selectedEntityProvider], resolves ONE of four screens — loading skeleton / error / empty / the
/// virtualized [AnSidebarList] of kind sections — and wires selection back to the URL. The rail's search
/// box drives the server-side `?search` ([entitySearchProvider], debounced), and each kind section's tail
/// drives [EntityListNotifier.loadMore] (keyset infinite scroll). All data flows through the repository
/// seam, so the gallery/tests drive every state with a fixture.
///
/// 左岛实体导航。watch railModel + selected,解出四态之一(骨架/错/空/虚拟化列表),选择写回 URL。搜索框驱动服务端
/// ?search(entitySearchProvider,防抖),每个 kind 段尾驱动 loadMore(keyset 无限下滑)。全数据过 repository 缝。
class EntityRail extends ConsumerStatefulWidget {
  const EntityRail({super.key});

  @override
  ConsumerState<EntityRail> createState() => _EntityRailState();
}

class _EntityRailState extends ConsumerState<EntityRail> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // Debounce keystrokes before hitting the server-side ?search (the provider re-pages from the top on
  // change; firing per key would storm the backend). 逐键防抖再打服务端 ?search(每键一请求会打爆后端)。
  void _onFilter(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(entitySearchProvider.notifier).set(v);
    });
  }

  // A kind section's tail fires with that kind's pageKey → page THAT kind's list (each kind is its own
  // keyset axis). 段尾携该 kind 的 pageKey → 翻该 kind 的列表(每 kind 独立 keyset 轴)。
  void _onLoadMore(String pageKey) {
    // pageKey is a kind.name set by the rail model; an unknown key means nothing to page (don't silently
    // fall back to some default kind's list). pageKey 是 rail 模型给的 kind.name;未知键=无可翻,不静默兜底翻别的。
    final kind = EntityKind.values.where((k) => k.name == pageKey).firstOrNull;
    if (kind == null) return;
    ref.read(entityListProvider(kind).notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(railModelProvider);
    final selected = ref.watch(selectedEntityProvider);
    final sort = ref.watch(railSortProvider);
    final showCount = ref.watch(railShowCountProvider);
    final t = context.t;

    final anyData = groups.any((g) => g.state.hasValue);
    final anyLoading = groups.any((g) => g.state.isLoading);
    final allError = groups.every((g) => g.state.hasError);

    // Loading: nothing resolved yet. A shaped skeleton reads faster than a spinner; deferred so a fast
    // first load never flashes it. 首载骨架(延迟防闪)。
    if (!anyData && anyLoading) return const AnDeferredLoading(child: _RailSkeleton());

    // Error: every kind failed and there is nothing to show — offer a retry that refetches all. 全错可重试。
    if (!anyData && allError) {
      return AnState(
        kind: AnStateKind.error,
        title: t.entities.errorTitle,
        hint: t.entities.errorHint,
        action: AnButton(label: t.entities.retry, onPressed: _retryAll),
      );
    }

    // Empty: loaded, but zero entities across all kinds. 加载完但空。
    final total = groups.fold<int>(0, (sum, g) => sum + g.count);
    if (total == 0) {
      return AnState(kind: AnStateKind.empty, title: t.entities.emptyTitle, hint: t.entities.emptyHint);
    }

    final model = buildRailModel(
      groups,
      RailLabels(kindLabel: (k) => k.typeLabel(t), newLabel: t.entities.kNew, filter: t.entities.filter),
      sort,
      showCount: showCount,
    );

    return AnSidebarList(
      model: model,
      selectedId: selected?.id,
      showNew: false, // entity creation is a later phase; the rail is read+select only in 4.1
      menuEntries: _menu(t, sort, showCount),
      // Navigate to set selection — the route is the source of truth (STEP 6). 导航即设选区(路由为真相)。
      onSelect: (id) {
        final kind = kindForId(groups, id);
        if (kind != null) context.go(entityLocation(kind, id));
      },
      onFilterChanged: _onFilter,
      onLoadMore: _onLoadMore,
      onRetryLoad: _onLoadMore, // retry = just page again 重试即再翻
    );
  }

  /// The filter-row sliders menu — a single-select Sort section (recently active / created / name,
  /// client-side over the loaded rows) + a Display section (show counts). 排序单选 + 显示开关。
  List<AnMenuEntry> _menu(Translations t, RailSort sort, bool showCount) {
    void pick(RailSort s) => ref.read(railSortProvider.notifier).set(s);
    return [
      AnMenuSection(t.entities.sortLabel),
      AnMenuItem(label: t.entities.sortRecent, checked: sort == RailSort.recent, onTap: () => pick(RailSort.recent)),
      AnMenuItem(label: t.entities.sortCreated, checked: sort == RailSort.created, onTap: () => pick(RailSort.created)),
      AnMenuItem(label: t.entities.sortName, checked: sort == RailSort.name, onTap: () => pick(RailSort.name)),
      AnMenuSection(t.entities.displayLabel),
      AnMenuItem(
        label: t.entities.showCount,
        checked: showCount,
        keepOpen: true,
        onTap: () => ref.read(railShowCountProvider.notifier).toggle(),
      ),
    ];
  }

  void _retryAll() {
    for (final kind in EntityKind.values) {
      ref.invalidate(entityListProvider(kind));
    }
  }

}

/// The first-load placeholder — a few bone rows under the chrome zone. 首载占位:数行骨架。
class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
          SizedBox(height: AnSpace.s8),
          AnSkeleton.row(),
        ],
      ),
    );
  }
}
